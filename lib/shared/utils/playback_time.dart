/// Purpose: Format a playback position as a clock.
/// Inputs: `d` — the position; negative values read as zero.
/// Returns: `String` — `m:ss` under an hour, `h:mm:ss` from an hour up.
/// Side effects: None.
/// Notes: Shared by the player controls and the episode list's resume text.
String formatPlaybackClock(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}
