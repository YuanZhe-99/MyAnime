package com.yuanzhe.my_anime

import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.common.internal.GenAiUtils
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerationConfig
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.ModelConfig
import com.google.mlkit.genai.prompt.ModelPreference
import com.google.mlkit.genai.prompt.ModelReleaseStage
import com.google.mlkit.genai.prompt.SystemInstruction
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateContentRequest
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.util.concurrent.ExecutionException

/**
 * The bridge to Android AICore, on the method channel
 * `com.yuanzhe.my_anime/genai`.
 *
 * One ML Kit GenAI client lives behind it: the Prompt API's [GenerativeModel],
 * which runs Gemini Nano on the device through the AICore system service. It is
 * ported from MyNihongo!!!!!'s `GenAiChannel`, which has run on real hardware;
 * the proofreading half is left out because nothing here needs it.
 *
 * Policy — whether the feature is on, what the prompt says, how the answer is
 * parsed — lives on the Dart side, where it is testable without a device. This
 * class is a pipe. Nothing here has been run on a device yet; see
 * `doc/en-us/on-device-ai.md` for the device checklist.
 */
class GenAiChannel(private val activity: MainActivity) : MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    /** The one request allowed to be in flight; a second is refused as busy. */
    private var inFlight: Job? = null

    /** The Prompt API client for [promptVariant], built by the first probe. */
    private var model: GenerativeModel? = null

    /** Which variant [model] asks AICore for; null until one is found. */
    private var promptVariant: Variant? = null

    /** The variants AICore refused, in the order they were tried. */
    private var refusedVariants: List<String> = emptyList()

    /** The variants AICore served, in the order they were tried. */
    private var servedVariants: List<String> = emptyList()

    /** The size preference the last probe ran with; null before any probe. */
    private var probedPreferFast: Boolean? = null

    /**
     * Purpose: Attach the channel to a Flutter engine.
     * Inputs: `flutterEngine` — the engine the activity attached.
     * Returns: None.
     * Side effects: Registers this object as the channel handler.
     * Notes: No AICore client is created here. Constructing one on a device
     * without AICore is what fails, and it has to fail inside a call that can
     * answer `unavailable`, not during engine setup. The Dart side never calls
     * the channel while the user's switch is off.
     */
    fun attach(flutterEngine: FlutterEngine) {
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    /**
     * Purpose: Release the model and stop any request in flight.
     * Inputs: None.
     * Returns: None.
     * Side effects: Closes the AICore client and cancels the scope.
     * Notes: Called from `MainActivity.onDestroy`. A model left open holds an
     * AICore session, which is a shared device resource.
     */
    fun detach() {
        scope.cancel()
        closePrompt()
        refusedVariants = emptyList()
        servedVariants = emptyList()
        probedPreferFast = null
    }

    /**
     * Purpose: Route one method call.
     * Inputs: `call`, `result`.
     * Returns: None.
     * Side effects: May run a model on the device.
     * Notes: Every failure is a `result.error` carrying one of the codes the
     * Dart `GenAiFailure` enum knows, never an exception across the channel.
     * `choose` is not handled here: on Android the Dart backend implements it
     * as `generate` plus a line parser.
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> run(result) {
                status(
                    call.argument<Boolean>("preferFast") ?: false,
                    call.argument<Boolean>("force") ?: false,
                )
            }
            "info" -> run(result) { info() }
            "download" -> run(result) { download() }
            "prewarm" -> run(result) {
                runCatching { promptModel().warmup() }
                null
            }
            "generate" -> run(result) {
                generate(
                    call.argument<String>("instructions").orEmpty(),
                    call.argument<String>("prompt").orEmpty(),
                    call.argument<Int>("maxOutputTokens") ?: 256,
                    (call.argument<Double>("temperature") ?: 0.0).toFloat(),
                    call.argument<Int>("topK") ?: 1,
                )
            }
            "cancel" -> {
                inFlight?.cancel()
                inFlight = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Purpose: Run one suspending body as the channel's single in-flight job.
     * Inputs: `result`, and the `body` producing the value to send back.
     * Returns: None.
     * Side effects: Starts a coroutine; replies on the channel exactly once.
     * Notes: Internal helper used within this file only. AICore serves one
     * inference at a time per app, so a second concurrent request is refused
     * here as `busy` rather than failing inside ML Kit.
     */
    private fun run(result: MethodChannel.Result, body: suspend () -> Any?) {
        if (inFlight?.isActive == true) {
            result.error("busy", "Another request is already running", null)
            return
        }
        inFlight = scope.launch {
            try {
                result.success(body())
            } catch (e: CancellationException) {
                result.error("cancelled", "The request was cancelled", null)
            } catch (e: Throwable) {
                // The exception only — never the prompt, which carries the
                // user's library.
                Log.w(TAG, "GenAI call failed: ${e.javaClass.simpleName}", e)
                result.error(codeFor(e), e.message, null)
            }
        }
    }

    /**
     * Purpose: Report whether the Prompt API can be used, downloaded, or not.
     * Inputs: `preferFast` — ask for the smaller model first; `force` —
     * re-probe rather than trust a variant that is already serving.
     * Returns: A map of `status` (`available`, `downloadable`, `downloading`,
     * `unavailable`, `unknown` or `unreachable`), the raw `code`, the `variant`
     * that answered, every variant that `served` and `refused`, and the
     * model's `baseModelName` and `tokenLimit` when it is ready; plus a
     * `detail` line when there is something to explain.
     * Side effects: Queries AICore, and may build and close model clients.
     * Notes: Internal helper used within this file only. Asked before every
     * use: the system can remove a model between two requests.
     */
    private suspend fun status(preferFast: Boolean, force: Boolean): Map<String, Any?> {
        val probe = probePrompt(preferFast, force)
        probe.error?.let { return unreachable(it) }
        val name = nameFor(probe.code)
        val ready = name == "available"
        Log.i(TAG, "status = ${probe.code} ($name) via ${probe.variant?.label}")
        return mapOf(
            "status" to name,
            "code" to probe.code,
            "variant" to probe.variant?.label,
            "served" to servedVariants.joinToString(", ").ifEmpty { null },
            "refused" to refusedVariants.joinToString(", ").ifEmpty { null },
            "baseModelName" to
                if (ready) runCatching { model?.getBaseModelName() }.getOrNull() else null,
            "tokenLimit" to
                if (ready) runCatching { model?.getTokenLimit() }.getOrNull() else null,
            "detail" to if (name == "unavailable" || name == "unknown") {
                detail(probe.code)
            } else {
                null
            },
        )
    }

    /**
     * Purpose: Name a `FeatureStatus` value.
     * Inputs: `code`.
     * Returns: `String`.
     * Side effects: None.
     * Notes: Internal helper used within this file only. An unrecognised value
     * is `unknown` rather than `unavailable`, so a future status is never read
     * as a refusal.
     */
    private fun nameFor(code: Int): String = when (code) {
        FeatureStatus.AVAILABLE -> "available"
        FeatureStatus.DOWNLOADABLE -> "downloadable"
        FeatureStatus.DOWNLOADING -> "downloading"
        FeatureStatus.UNAVAILABLE -> "unavailable"
        else -> "unknown"
    }

    /**
     * Purpose: Build the diagnostic line shown under a refusal.
     * Inputs: `code`.
     * Returns: `String`.
     * Side effects: None.
     * Notes: Internal helper used within this file only. Names every variant
     * that was tried.
     */
    private fun detail(code: Int): String {
        val refused = refusedVariants
        return if (refused.isEmpty()) {
            "FeatureStatus=$code"
        } else {
            "FeatureStatus=$code · refused: ${refused.joinToString(", ")}"
        }
    }

    /**
     * Purpose: Answer a status request that could not be asked at all.
     * Inputs: the `error` that was thrown.
     * Returns: The reply map.
     * Side effects: Logs.
     * Notes: Internal helper used within this file only. "AICore answered
     * UNAVAILABLE" and "AICore could not be asked" are different facts with
     * different fixes, so they get different statuses.
     */
    private fun unreachable(error: Throwable): Map<String, Any?> {
        val cause = if (error is ExecutionException) error.cause ?: error else error
        Log.w(TAG, "status failed", cause)
        return mapOf(
            "status" to "unreachable",
            "code" to -1,
            "detail" to "${cause.javaClass.simpleName}: ${cause.message}",
        )
    }

    /**
     * Purpose: Describe the AICore installation this device actually has.
     * Inputs: None.
     * Returns: A map with `installed`, `versionName`, `sdk`, `device` and
     * `compatible`.
     * Side effects: Queries the package manager and ML Kit.
     * Notes: Internal helper used within this file only. Reading the package
     * needs the manifest's `<queries>` entry on API 30 and up. `compatible`
     * comes from ML Kit's internal `GenAiUtils`, so it is guarded and optional.
     */
    private fun info(): Map<String, Any?> {
        val device = "${Build.MANUFACTURER} ${Build.MODEL}"
        val compatible = runCatching { GenAiUtils.isAiCoreCompatible(activity) }.getOrNull()
        return try {
            val info = activity.packageManager.getPackageInfo(AICORE_PACKAGE, 0)
            mapOf(
                "platform" to "android",
                "installed" to true,
                "versionName" to info.versionName,
                "sdk" to Build.VERSION.SDK_INT,
                "device" to device,
                "compatible" to compatible,
            )
        } catch (e: PackageManager.NameNotFoundException) {
            mapOf(
                "platform" to "android",
                "installed" to false,
                "sdk" to Build.VERSION.SDK_INT,
                "device" to device,
                "compatible" to compatible,
            )
        }
    }

    /**
     * Purpose: Ask AICore to fetch the model.
     * Inputs: None.
     * Returns: `Boolean` — true when the download completed.
     * Side effects: AICore downloads a model over the network; progress is
     * pushed back to Dart as `downloadProgress`.
     * Notes: Internal helper used within this file only. **The app downloads
     * nothing itself** — it asks the AICore system service to, and only from
     * the Download button in Settings.
     */
    private suspend fun download(): Boolean {
        var failure: Throwable? = null
        promptModel().download().collect { status ->
            when (status) {
                is DownloadStatus.DownloadStarted ->
                    reportProgress(0L, status.bytesToDownload)
                is DownloadStatus.DownloadProgress ->
                    reportProgress(status.totalBytesDownloaded, -1L)
                is DownloadStatus.DownloadFailed -> failure = status.e
                else -> Unit
            }
        }
        failure?.let { throw it }
        return true
    }

    /**
     * Purpose: Generate one answer from instructions and a prompt.
     * Inputs: `instructions`, `prompt`, `maxOutputTokens`, `temperature`,
     * `topK`.
     * Returns: `String` — the first candidate's text, or empty.
     * Side effects: Runs Gemini Nano on the device.
     * Notes: Internal helper used within this file only. The instructions go
     * in as a system instruction where the model reports support for one, and
     * are prepended to the prompt otherwise. Non-streaming, one candidate.
     */
    private suspend fun generate(
        instructions: String,
        prompt: String,
        maxOutputTokens: Int,
        temperature: Float,
        topK: Int,
    ): String {
        val model = promptModel()
        val system = instructions.isNotBlank() &&
            runCatching { model.isSystemPromptAvailable() }.getOrDefault(false)
        val configure: com.google.mlkit.genai.prompt.GenerateContentRequest.Builder.() -> Unit = {
            this.temperature = temperature
            this.topK = topK
            this.candidateCount = 1
            this.maxOutputTokens = maxOutputTokens
        }
        val request = if (system) {
            generateContentRequest(SystemInstruction(instructions), TextPart(prompt), configure)
        } else {
            val text = if (instructions.isBlank()) prompt else "$instructions\n\n$prompt"
            generateContentRequest(TextPart(text), configure)
        }
        val response = model.generateContent(request)
        return response.candidates.firstOrNull()?.text.orEmpty()
    }

    /**
     * Purpose: Get the Prompt API client for the variant this device serves.
     * Inputs: None.
     * Returns: `GenerativeModel`.
     * Side effects: Probes AICore on first use.
     * Notes: Internal helper used within this file only. Throws rather than
     * handing back a client for a variant nothing will serve.
     */
    private suspend fun promptModel(): GenerativeModel {
        model?.let { return it }
        probePrompt(probedPreferFast ?: false, force = false)
        return model ?: throw IllegalStateException(
            "the Prompt API is not available on this device " +
                "(refused: ${refusedVariants.joinToString(", ").ifEmpty { "none" }})",
        )
    }

    /**
     * Purpose: Find every Prompt API model variant this device serves, and
     * choose one.
     * Inputs: `preferFast` — try the smaller model first at each release
     * stage; `force` — re-probe even when a variant is already serving.
     * Returns: [Probe] — the status of the variant that was chosen, or the
     * error when none of them could be asked.
     * Side effects: Builds AICore clients, keeps at most one, closes the rest.
     * Notes: Internal helper used within this file only.
     * `Generation.getClient()` without a configuration asks for exactly one
     * variant, and devices serve different ones — MyNihongo measured a Pixel 10
     * serving only stable/full and a Galaxy Z Fold8 only stable/fast — so all
     * four combinations are probed and the first that serves is kept. Every
     * variant is probed, not only up to the first success, because whether the
     * user has a size choice is itself reported.
     */
    private suspend fun probePrompt(preferFast: Boolean, force: Boolean): Probe {
        val chosen = promptVariant
        val current = model
        if (!force && chosen != null && current != null && probedPreferFast == preferFast) {
            val code = runCatching { current.checkStatus() }.getOrNull()
            if (code != null && code != FeatureStatus.UNAVAILABLE) {
                return Probe(code, chosen, null)
            }
        }
        closePrompt()

        val refused = ArrayList<String>()
        val served = ArrayList<String>()
        var refusal: Int? = null
        var lastError: Throwable? = null
        var winner: Variant? = null
        var winnerCode = -1
        for (variant in if (preferFast) VARIANTS_FAST_FIRST else VARIANTS) {
            val client = try {
                Generation.getClient(
                    GenerationConfig.Builder().apply {
                        modelConfig = ModelConfig.builder().apply {
                            releaseStage = variant.stage
                            preference = variant.preference
                        }.build()
                    }.build(),
                )
            } catch (e: Throwable) {
                Log.w(TAG, "getClient(${variant.label}) failed", e)
                lastError = e
                refused.add("${variant.label} (${e.javaClass.simpleName})")
                continue
            }
            val code = try {
                client.checkStatus()
            } catch (e: Throwable) {
                Log.w(TAG, "checkStatus(${variant.label}) failed", e)
                lastError = e
                refused.add("${variant.label} (${e.javaClass.simpleName})")
                runCatching { client.close() }
                continue
            }
            if (code == FeatureStatus.UNAVAILABLE) {
                Log.i(TAG, "checkStatus(${variant.label}) = UNAVAILABLE")
                refusal = code
                refused.add(variant.label)
                runCatching { client.close() }
                continue
            }
            Log.i(TAG, "${variant.label} serves, FeatureStatus=$code")
            served.add(variant.label)
            if (winner == null) {
                winner = variant
                winnerCode = code
                model = client
            } else {
                runCatching { client.close() }
            }
        }
        refusedVariants = refused
        servedVariants = served
        probedPreferFast = preferFast
        if (winner != null) {
            promptVariant = winner
            return Probe(winnerCode, winner, null)
        }
        return if (refusal != null) {
            Probe(refusal, null, null)
        } else {
            Probe(-1, null, lastError ?: IllegalStateException("no variants configured"))
        }
    }

    /**
     * Purpose: Drop the Prompt API client and everything known about it.
     * Inputs: None.
     * Returns: None.
     * Side effects: Closes the client.
     * Notes: Internal helper used within this file only.
     */
    private fun closePrompt() {
        runCatching { model?.close() }
        model = null
        promptVariant = null
    }

    /** One Prompt API model variant, and the name it is reported under. */
    private class Variant(val stage: Int, val preference: Int, val label: String)

    /** What one round of probing found: a status, or the reason there is none. */
    private class Probe(val code: Int, val variant: Variant?, val error: Throwable?)

    /**
     * Purpose: Tell Dart how far the model download has got.
     * Inputs: `bytes` downloaded so far, `total` or -1 when unknown.
     * Returns: None.
     * Side effects: Sends a method call to Dart.
     * Notes: Internal helper used within this file only. Advisory, so it is
     * sent without a result callback.
     */
    private fun reportProgress(bytes: Long, total: Long) {
        channel.invokeMethod("downloadProgress", mapOf("bytes" to bytes, "total" to total))
    }

    /**
     * Purpose: Turn a thrown error into one of the codes Dart knows.
     * Inputs: `error`.
     * Returns: `String`.
     * Side effects: None.
     * Notes: Internal helper used within this file only. Uses the library's
     * own `errorCode`, confirmed against the 1.0.0-beta4 AAR with `javap`
     * (`BACKGROUND_USE_BLOCKED = 30`, `PER_APP_BATTERY_USE_QUOTA_EXCEEDED =
     * 27`). Anything unrecognised is `failed`.
     */
    private fun codeFor(error: Throwable): String {
        val cause = if (error is ExecutionException) error.cause ?: error else error
        if (cause is GenAiException) {
            when (cause.errorCode) {
                GenAiException.ErrorCode.NOT_AVAILABLE,
                GenAiException.ErrorCode.NOT_SUPPORTED,
                GenAiException.ErrorCode.AICORE_INCOMPATIBLE,
                GenAiException.ErrorCode.NEEDS_SYSTEM_UPDATE,
                -> return "unavailable"
                GenAiException.ErrorCode.REQUEST_TOO_LARGE -> return "tooLong"
                GenAiException.ErrorCode.BUSY -> return "busy"
                GenAiException.ErrorCode.CANCELLED -> return "cancelled"
                GenAiException.ErrorCode.BACKGROUND_USE_BLOCKED -> return "background"
                GenAiException.ErrorCode.PER_APP_BATTERY_USE_QUOTA_EXCEEDED -> return "quota"
            }
        }
        if (cause is IllegalStateException &&
            cause.message.orEmpty().contains("not available")
        ) {
            return "unavailable"
        }
        return "failed"
    }

    companion object {
        /** The channel name, matched by `MethodChannelGenAiBackend` in Dart. */
        const val CHANNEL = "com.yuanzhe.my_anime/genai"

        /** The log tag. */
        private const val TAG = "MyAnimeGenAi"

        /** The AICore system service, whose version decides what is served. */
        private const val AICORE_PACKAGE = "com.google.android.aicore"

        /**
         * The Prompt API model variants, in the order they are tried: the
         * full-size model first at each release stage, preview only after
         * both stable sizes refused.
         */
        private val VARIANTS = listOf(
            Variant(ModelReleaseStage.STABLE, ModelPreference.FULL, "stable/full"),
            Variant(ModelReleaseStage.STABLE, ModelPreference.FAST, "stable/fast"),
            Variant(ModelReleaseStage.PREVIEW, ModelPreference.FULL, "preview/full"),
            Variant(ModelReleaseStage.PREVIEW, ModelPreference.FAST, "preview/fast"),
        )

        /** The same variants, smaller model first at each stage. */
        private val VARIANTS_FAST_FIRST = listOf(
            Variant(ModelReleaseStage.STABLE, ModelPreference.FAST, "stable/fast"),
            Variant(ModelReleaseStage.STABLE, ModelPreference.FULL, "stable/full"),
            Variant(ModelReleaseStage.PREVIEW, ModelPreference.FAST, "preview/fast"),
            Variant(ModelReleaseStage.PREVIEW, ModelPreference.FULL, "preview/full"),
        )
    }
}
