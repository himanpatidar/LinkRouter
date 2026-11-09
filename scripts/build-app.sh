#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
configuration="${1:-release}"
zsh scripts/swift.sh build -c "$configuration"
bin_dir="$(zsh scripts/swift.sh build -c "$configuration" --show-bin-path)"
app_dir="$PWD/build/LinkRouter.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/LinkRouter" "$app_dir/Contents/MacOS/LinkRouter"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
swift scripts/make-icon.swift "$app_dir/Contents/Resources"
codesign --force --sign - "$app_dir"
printf 'Built %s\n' "$app_dir"
