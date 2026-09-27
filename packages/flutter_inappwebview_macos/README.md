# macOS WebView compatibility patch

Vendored from the MIT-licensed pub.dev `flutter_inappwebview_macos` 1.2.0-beta.3
release (archive SHA-256
`545148cb5c46475ce669ab21621e9f2ad66e05f8e80b2cf49d4018879ab52393`).
Only the runtime sources, manifests, build configuration, changelog and license
are included; example projects are omitted.

`WebAuthenticationSession.swift` applies upstream PR
[#2870](https://github.com/pichillilorenzo/flutter_inappwebview/pull/2870), commit
`8db1d528a2dc467112ec5e1a5233172f3dd828b4`: move the presentation-context protocol
conformance into a macOS 10.15-available provider, retain it while the session is
alive, and release it on disposal. This repairs the Xcode 26.6 availability error.

The Git revision itself omits six Swift files present in the published archive,
so use the complete published runtime rather than depending on that Git tree.
The application adds structured comments only to the changed declarations;
other vendored declarations retain upstream documentation.

Remove this path override once an official release includes the fix, then verify
macOS release compilation, FoundationModels weak linking, and WebView playback.
