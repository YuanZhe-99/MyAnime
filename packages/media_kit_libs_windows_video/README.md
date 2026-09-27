# Windows media library compatibility patch

Vendored from media_kit_libs_windows_video 1.0.11 (MIT, LICENSE retained).
Only the Windows CMake ARM64 guard is changed. Upstream pins x86_64 libmpv/ANGLE.
ARM64 builds register the upstream no-op plugin without bundling these binaries;
media_kit_video compiles its existing MEDIA_KIT_LIBS_NOT_FOUND stub. The Dart
player detects the process ABI and uses the embedded Anime1 player on ARM64.
Windows x64 retains upstream downloads and checksums unchanged. Remove this local
override when upstream distributes verified ARM64 media binaries.