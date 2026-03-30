/// Build flavor configuration.
///
/// Pass `--dart-define=FLAVOR=store` for App Store / Google Play builds
/// (online search disabled). Default is `full`.
class AppFlavor {
  AppFlavor._();

  static const _flavor = String.fromEnvironment('FLAVOR', defaultValue: 'full');

  /// True when built for App Store / Google Play (no online search).
  static const isStore = _flavor == 'store';

  /// True when built as the full-featured version.
  static const isFull = !isStore;
}
