#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
# Some CLT distributions ship an obsolete private PackageDescription interface
# alongside a newer public interface and library. Keep the workaround local.
manifest_api="$(xcrun --show-toolchain-path 2>/dev/null || true)/usr/lib/swift/pm/ManifestAPI"
if [[ ! -d "$manifest_api" ]]; then
    swift_path="$(xcrun --find swift)"
    manifest_api="${swift_path:h:h}/lib/swift/pm/ManifestAPI"
fi
public_api="$manifest_api/PackageDescription.swiftmodule/arm64-apple-macos.swiftinterface"
private_api="$manifest_api/PackageDescription.swiftmodule/arm64-apple-macos.private.swiftinterface"
if [[ -f "$public_api" && -f "$private_api" ]] && /usr/bin/grep -q 'public enum SwiftLanguageMode' "$public_api" && /usr/bin/grep -q 'public enum SwiftVersion' "$private_api"; then
    local_api="$project_dir/.build/toolchain/ManifestAPI"
    mkdir -p "$local_api/PackageDescription.swiftmodule"
    cp "$manifest_api/libPackageDescription.dylib" "$local_api/"
    cp "$manifest_api"/PackageDescription.swiftmodule/*.swiftinterface "$local_api/PackageDescription.swiftmodule/"
    # Copying only public interfaces avoids loading the stale private interface.
    # No system files or global caches are modified.
    for arch in arm64 x86_64; do
        if [[ -f "$local_api/PackageDescription.swiftmodule/$arch-apple-macos.swiftinterface" ]]; then
            cp "$local_api/PackageDescription.swiftmodule/$arch-apple-macos.swiftinterface" "$local_api/PackageDescription.swiftmodule/$arch-apple-macos.private.swiftinterface"
        fi
    done
    export SWIFTPM_CUSTOM_LIBS_DIR="$project_dir/.build/toolchain"
fi
testing_frameworks="$(xcode-select -p)/Library/Developer/Frameworks"
if [[ "${1:-}" == "test" && -d "$testing_frameworks/Testing.framework" && ! -d "$testing_frameworks/XCTest.framework" ]]; then
    shift
    exec swift test --disable-xctest -Xswiftc -F -Xswiftc "$testing_frameworks" -Xlinker -F -Xlinker "$testing_frameworks" -Xlinker -rpath -Xlinker "$testing_frameworks" -Xlinker -rpath -Xlinker "${testing_frameworks:h}/usr/lib" "$@"
fi
exec swift "$@"
