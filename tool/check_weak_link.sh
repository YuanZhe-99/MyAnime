#!/usr/bin/env bash
# Fail unless every Mach-O binary in an app bundle that links Apple's
# FoundationModels framework links it weakly (LC_LOAD_WEAK_DYLIB).
#
# An app that strong-links FoundationModels will not launch on iOS 18 or
# macOS 15 and earlier, where the framework does not exist. The
# on_device_ai_apple plugin declares the framework weak and guards every use
# with @available(iOS 26.0, macOS 26.0, *); this script checks that the built
# binaries agree. It also fails when nothing links the framework at all, which
# would mean the plugin never made it into the build.
#
# Usage: tool/check_weak_link.sh <path/to/App.app>
# The path may contain spaces or `!` (the macOS bundle is "MyAnime!!!!!.app"),
# so always quote it. See doc/en-us/ci-cd.md and doc/en-us/on-device-ai.md.
set -euo pipefail

app="${1:?usage: tool/check_weak_link.sh <path/to/App.app>}"
if [ ! -d "$app" ]; then
  echo "error: no app bundle at $app" >&2
  exit 1
fi

found=0
strong=0
while IFS= read -r -d '' f; do
  file "$f" | grep -q 'Mach-O' || continue
  # The load command's `cmd` line is two lines above its `name` line.
  hits=$(otool -l "$f" | grep -B2 'FoundationModels.framework' || true)
  [ -n "$hits" ] || continue
  found=1
  if echo "$hits" | grep -q 'cmd LC_LOAD_DYLIB'; then
    echo "STRONG: $f links FoundationModels with LC_LOAD_DYLIB" >&2
    strong=1
  else
    echo "weak:   $f"
  fi
done < <(find "$app" -type f -print0)

if [ "$found" -eq 0 ]; then
  echo "error: no binary in $app links FoundationModels; is the on_device_ai_apple plugin registered?" >&2
  exit 1
fi
if [ "$strong" -ne 0 ]; then
  exit 1
fi
echo "OK: FoundationModels is weakly linked everywhere in $app"
