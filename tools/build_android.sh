#!/usr/bin/env bash
set -euo pipefail
: "${GODOT:?Set GODOT to the Godot 4.5.1 executable}"
: "${ANDROID_SDK_ROOT:?Set ANDROID_SDK_ROOT to the configured SDK directory}"
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
mkdir -p artifacts
python3 tools/check_native.py
"$GODOT" --headless --path game --editor --import > artifacts/android-import.log 2>&1
apk="$repo_dir/artifacts/Barista-0.1.0-tech-preview.apk"
"$GODOT" --headless --path game --export-debug Android "$apk" > artifacts/android-export.log 2>&1
python3 tools/check_apk.py "$apk" --sdk-root "$ANDROID_SDK_ROOT" | tee artifacts/android-verification.log
