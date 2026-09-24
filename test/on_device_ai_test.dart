import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/ai/services/genai_backend.dart';
import 'package:my_anime/features/ai/services/on_device_ai_service.dart';
import 'package:my_anime/features/ai/services/output_validation.dart';

/// A backend that records every call and answers from fields.
class FakeBackend implements GenAiBackend {
  final calls = <String>[];
  GenAiStatusReport status = const GenAiStatusReport(GenAiStatus.available);
  final generateReplies = <Object>[];
  Completer<String>? hold;

  @override
  Future<GenAiStatusReport> statusReport({
    bool force = false,
    bool preferFast = false,
  }) async {
    calls.add('status');
    return status;
  }

  @override
  Future<GenAiCoreInfo?> coreInfo({String? localeTag}) async {
    calls.add('info');
    return const GenAiCoreInfo(platform: 'android', installed: true);
  }

  @override
  Future<bool> download({
    void Function(int bytes, int total)? onProgress,
  }) async {
    calls.add('download');
    onProgress?.call(10, 100);
    status = const GenAiStatusReport(GenAiStatus.available);
    return true;
  }

  @override
  Future<String> generate({
    required String instructions,
    required String prompt,
    int maxOutputTokens = 256,
    double temperature = 0,
    int topK = 1,
  }) async {
    calls.add('generate:$prompt');
    if (hold != null) return hold!.future;
    final next = generateReplies.isEmpty ? 'ok' : generateReplies.removeAt(0);
    if (next is GenAiException) throw next;
    return next as String;
  }

  @override
  Future<List<String>> choose({
    required String instructions,
    required String prompt,
    required List<String> options,
    int maxItems = 3,
  }) async {
    calls.add('choose:$prompt');
    return [options.first];
  }

  @override
  Future<void> prewarm() async => calls.add('prewarm');

  @override
  Future<void> cancel() async => calls.add('cancel');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnDeviceAiService', () {
    late FakeBackend backend;
    late DateTime now;
    late OnDeviceAiService service;

    setUp(() {
      backend = FakeBackend();
      now = DateTime(2026, 9, 24, 12);
      service = OnDeviceAiService(backend: backend, now: () => now);
    });

    test('with the switch off the backend is never called', () async {
      await service.refreshStatus();
      await service.prewarm();
      expect(await service.download(), isFalse);
      await expectLater(
        service.generate(instructions: 'i', prompt: 'p'),
        throwsA(
          isA<GenAiException>().having(
            (e) => e.failure,
            'failure',
            GenAiFailure.unavailable,
          ),
        ),
      );
      await expectLater(
        service.choose(instructions: 'i', prompt: 'p', options: ['a']),
        throwsA(isA<GenAiException>()),
      );
      expect(backend.calls, isEmpty);
    });

    test('turning it on asks for status once, forced', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await service.setEnabled(true);
      expect(backend.calls, ['status', 'info']);
      expect(service.canGenerate, isTrue);
    });

    test('status is re-checked before every request', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await service.setEnabled(true);
      backend.calls.clear();
      expect(await service.generate(instructions: 'i', prompt: 'a'), 'ok');
      expect(backend.calls, ['status', 'generate:a']);
      backend.status = const GenAiStatusReport(GenAiStatus.downloadable);
      await expectLater(
        service.generate(instructions: 'i', prompt: 'b'),
        throwsA(isA<GenAiException>()),
      );
      expect(backend.calls.last, 'status');
    });

    test('interactive requests jump ahead of background ones', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await service.setEnabled(true);
      backend.calls.clear();
      final order = <String>[];
      final futures = [
        service
            .generate(
              instructions: 'i',
              prompt: 'bg1',
              priority: AiPriority.background,
            )
            .then(order.add),
        service
            .generate(
              instructions: 'i',
              prompt: 'bg2',
              priority: AiPriority.background,
            )
            .then(order.add),
        service.generate(instructions: 'i', prompt: 'fg').then(order.add),
      ];
      backend.generateReplies.addAll(['r1', 'r2', 'r3']);
      await Future.wait(futures);
      final generated = [
        for (final c in backend.calls)
          if (c.startsWith('generate:')) c.substring(9),
      ];
      expect(generated, ['fg', 'bg1', 'bg2']);
    });

    test('nothing runs while the app is in the background', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await service.setEnabled(true);
      backend.calls.clear();
      service.handleLifecycle(AppLifecycleState.paused);
      var done = false;
      final f = service
          .generate(
            instructions: 'i',
            prompt: 'x',
            priority: AiPriority.background,
          )
          .then((_) => done = true);
      await pumpEventQueue();
      expect(done, isFalse);
      expect(backend.calls, isEmpty);
      service.handleLifecycle(AppLifecycleState.resumed);
      await f;
      expect(done, isTrue);
    });

    test('a background refusal waits for the next resume', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await service.setEnabled(true);
      backend.generateReplies.add(
        const GenAiException(GenAiFailure.background),
      );
      await expectLater(
        service.generate(instructions: 'i', prompt: 'x'),
        throwsA(isA<GenAiException>()),
      );
      backend.calls.clear();
      var done = false;
      final f = service
          .generate(instructions: 'i', prompt: 'y')
          .then((_) => done = true);
      await pumpEventQueue();
      expect(done, isFalse);
      service.handleLifecycle(AppLifecycleState.resumed);
      await f;
      expect(done, isTrue);
    });

    test(
      'busy backs off background work, doubling up to five minutes',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await service.setEnabled(true);
        backend.generateReplies.add(const GenAiException(GenAiFailure.busy));
        await expectLater(
          service.generate(
            instructions: 'i',
            prompt: 'x',
            priority: AiPriority.background,
          ),
          throwsA(isA<GenAiException>()),
        );
        expect(service.pausedUntil, now.add(OnDeviceAiService.initialBackoff));

        // A background job queued during the backoff does not run yet...
        backend.calls.clear();
        var done = false;
        unawaited(
          service
              .generate(
                instructions: 'i',
                prompt: 'y',
                priority: AiPriority.background,
              )
              .then((_) => done = true),
        );
        await pumpEventQueue();
        expect(done, isFalse);
        expect(backend.calls, isEmpty);
        // ...but an interactive one still does.
        expect(await service.generate(instructions: 'i', prompt: 'z'), 'ok');
        await service.cancelBackground();
      },
    );

    test('quota stops background work for the rest of the day', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await service.setEnabled(true);
      backend.generateReplies.add(const GenAiException(GenAiFailure.quota));
      await expectLater(
        service.generate(
          instructions: 'i',
          prompt: 'x',
          priority: AiPriority.background,
        ),
        throwsA(isA<GenAiException>()),
      );
      expect(service.quotaReachedToday, isTrue);
      await expectLater(
        service.generate(
          instructions: 'i',
          prompt: 'y',
          priority: AiPriority.background,
        ),
        throwsA(
          isA<GenAiException>().having(
            (e) => e.failure,
            'failure',
            GenAiFailure.quota,
          ),
        ),
      );
      now = now.add(const Duration(days: 1));
      expect(service.quotaReachedToday, isFalse);
    });

    test('a request that never answers times out', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      fakeAsync((async) {
        service.setEnabled(true);
        async.flushMicrotasks();
        backend.hold = Completer<String>();
        Object? error;
        service.generate(instructions: 'i', prompt: 'x').catchError((Object e) {
          error = e;
          return '';
        });
        async.elapse(OnDeviceAiService.timeout + const Duration(seconds: 1));
        expect(
          error,
          isA<GenAiException>().having(
            (e) => e.failure,
            'failure',
            GenAiFailure.timeout,
          ),
        );
      });
    });

    test('switching off fails queued work and cancels', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await service.setEnabled(true);
      service.handleLifecycle(AppLifecycleState.paused);
      final f = service.generate(instructions: 'i', prompt: 'x');
      final failed = expectLater(f, throwsA(isA<GenAiException>()));
      await service.setEnabled(false);
      await failed;
      expect(service.report.status, GenAiStatus.unsupported);
    });

    test('Windows never touches the backend even when enabled', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await service.setEnabled(true);
      expect(backend.calls, isEmpty);
      expect(service.report.status, GenAiStatus.unsupported);
    });

    test('download reports progress and re-reads the status', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      backend.status = const GenAiStatusReport(GenAiStatus.downloadable);
      await service.setEnabled(true);
      expect(service.canGenerate, isFalse);
      expect(await service.download(), isTrue);
      expect(service.canGenerate, isTrue);
      expect(backend.calls, contains('download'));
    });
  });

  group('MethodChannelGenAiBackend', () {
    const channel = MethodChannel(MethodChannelGenAiBackend.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('maps every status reply shape', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      Object? reply;
      messenger.setMockMethodCallHandler(channel, (call) async => reply);
      final backend = MethodChannelGenAiBackend();
      Future<GenAiStatus> statusFor(Object? r) async {
        reply = r;
        return (await backend.statusReport()).status;
      }

      expect(await statusFor({'status': 'available'}), GenAiStatus.available);
      expect(
        await statusFor({'status': 'downloadable'}),
        GenAiStatus.downloadable,
      );
      expect(await statusFor({'status': 'notEnabled'}), GenAiStatus.notEnabled);
      expect(await statusFor({'status': 'unsupported'}), GenAiStatus.unsupported);
      expect(await statusFor({'status': 'someday'}), GenAiStatus.unknown);
      expect(await statusFor({'status': 3}), GenAiStatus.unavailable);
      expect(await statusFor({}), GenAiStatus.unavailable);
      expect(await statusFor(null), GenAiStatus.unavailable);

      reply = {
        'status': 'available',
        'code': 3,
        'variant': 'stable/fast',
        'served': 'stable/full, stable/fast',
        'tokenLimit': 4000,
      };
      final report = await backend.statusReport();
      expect(report.code, 3);
      expect(report.variant, 'stable/fast');
      expect(report.hasSizeChoice, isTrue);
      expect(report.tokenLimit, 4000);
    });

    test('a platform error is unreachable, not unavailable', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'boom', message: 'x'),
      );
      final report = await MethodChannelGenAiBackend().statusReport();
      expect(report.status, GenAiStatus.unreachable);
      expect(report.detail, 'boom: x');
    });

    test('an unregistered channel on iOS is unreachable', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final report = await MethodChannelGenAiBackend().statusReport();
      expect(report.status, GenAiStatus.unreachable);
      expect(report.detail, 'channel not registered');
    });

    test('unsupported platforms never call the channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      var called = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        called = true;
        return null;
      });
      final backend = MethodChannelGenAiBackend();
      expect((await backend.statusReport()).status, GenAiStatus.unsupported);
      expect(await backend.coreInfo(), isNull);
      expect(called, isFalse);
    });

    test('error codes map to failures', () {
      expect(
        MethodChannelGenAiBackend.failureForCode('background'),
        GenAiFailure.background,
      );
      expect(
        MethodChannelGenAiBackend.failureForCode('quota'),
        GenAiFailure.quota,
      );
      expect(
        MethodChannelGenAiBackend.failureForCode('guardrail'),
        GenAiFailure.guardrail,
      );
      expect(
        MethodChannelGenAiBackend.failureForCode('unsupportedLanguage'),
        GenAiFailure.unsupportedLanguage,
      );
      expect(
        MethodChannelGenAiBackend.failureForCode('whatever'),
        GenAiFailure.failed,
      );
    });

    test('Android choose is generate plus the line parser', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final methods = <String>[];
      Object? reply = 'romance, school';
      messenger.setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        return reply;
      });
      final backend = MethodChannelGenAiBackend();
      final ids = await backend.choose(
        instructions: 'i',
        prompt: 'p',
        options: const ['romance', 'school', 'comedy'],
      );
      expect(ids, ['romance', 'school']);
      expect(methods, ['generate']);
      reply = 'I think it is a love story.';
      await expectLater(
        backend.choose(
          instructions: 'i',
          prompt: 'p',
          options: const ['romance'],
        ),
        throwsA(isA<GenAiException>()),
      );
    });

    test('Apple choose is native', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'choose');
        return ['comedy', 42];
      });
      final ids = await MethodChannelGenAiBackend().choose(
        instructions: 'i',
        prompt: 'p',
        options: const ['comedy'],
      );
      expect(ids, ['comedy']);
    });
  });

  group('output validation', () {
    const options = ['romance', 'school', 'slice_of_life', 'comedy'];

    test('reads lists, lines, labels and Markdown', () {
      expect(parseChoiceReply('romance, school', options).ids, [
        'romance',
        'school',
      ]);
      expect(parseChoiceReply('- Romance\n- Slice of life', options).ids, [
        'romance',
        'slice_of_life',
      ]);
      expect(parseChoiceReply('Anime 1: comedy、school', options).ids, [
        'comedy',
        'school',
      ]);
      expect(parseChoiceReply('```\n**romance**\n```', options).ids, [
        'romance',
      ]);
    });

    test('drops unknown ids, duplicates and anything past the cap', () {
      final p = parseChoiceReply(
        'romance, horror, romance, school, comedy, slice_of_life',
        options,
      );
      expect(p.ids, ['romance', 'school', 'comedy']);
    });

    test('NONE is a valid empty answer; prose is invalid', () {
      final none = parseChoiceReply('NONE', options);
      expect(none.valid, isTrue);
      expect(none.none, isTrue);
      expect(none.ids, isEmpty);
      expect(parseChoiceReply('It is about love.', options).valid, isFalse);
      expect(parseChoiceReply('', options).valid, isFalse);
    });

    test('script checks follow the UI language', () {
      expect(matchesScript('和你喜欢的《孤独摇滚》同一工作室', 'zh'), isTrue);
      expect(matchesScript('Same studio as Bocchi', 'zh'), isFalse);
      expect(matchesScript('高評価した作品と同じスタジオです', 'ja'), isTrue);
      expect(matchesScript('和你喜欢的作品同一工作室', 'ja'), isFalse);
      expect(matchesScript('Same studio as 孤独摇滚', 'en'), isTrue);
      expect(matchesScript('同一工作室', 'en'), isFalse);
    });

    test('cleanSentence drops over-long output', () {
      expect(cleanSentence('**Great** pick.\n'), 'Great pick.');
      expect(cleanSentence('x' * 141), isNull);
      expect(cleanSentence('  '), isNull);
    });
  });
}
