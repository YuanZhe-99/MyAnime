# packages/flutter_inappwebview_macos

MIT-licensed 1.2.0-beta.3 runtime snapshot, with the macOS availability repair
from upstream PR #2870. See [platform notes](../../platform-notes.md) and the
package README for provenance and replacement criteria. Unchanged third-party
declarations retain upstream documentation and are outside the `lib/` totals.

## Changed declarations

| Declaration | Purpose |
|---|---|
| `WebAuthenticationPresentationContextProvider.presentationAnchor` | Return the key window under a macOS 10.15-available protocol conformance. |
| `WebAuthenticationSession.init` | Retain the provider while assigning it to the native session's weak property. |
| `WebAuthenticationSession.dispose` | Release the retained provider with the session. |
