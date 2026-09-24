#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

case "$(uname -s):$(uname -m)" in
    Linux:x86_64) platform=linux; arch=amd64; extension=so ;;
    Linux:aarch64|Linux:arm64) platform=linux; arch=arm64; extension=so ;;
    Darwin:x86_64) platform=macos; arch=amd64; extension=dylib ;;
    Darwin:arm64) platform=macos; arch=arm64; extension=dylib ;;
    *) echo "Unsupported parser binary target: $(uname -s)/$(uname -m)" >&2; exit 1 ;;
esac

name="tree-sitter-plato-$platform-$arch.$extension"
mkdir -p dist build
trap 'rm -f build/check-artifact' EXIT

if [ "$platform" = macos ]; then
    "${CC:-cc}" -std=c11 -O2 -fPIC -dynamiclib -Isrc src/parser.c -o "dist/$name"
    "${CC:-cc}" -std=c11 -Isrc scripts/check_artifact.c -o build/check-artifact
else
    "${CC:-cc}" -std=c11 -O2 -fPIC -shared -Isrc src/parser.c -o "dist/$name"
    "${CC:-cc}" -std=c11 -Isrc scripts/check_artifact.c -ldl -o build/check-artifact
fi

build/check-artifact "dist/$name"

(
    cd dist
    if [ "$platform" = macos ]; then
        shasum -a 256 "$name" > SHA256SUMS
        shasum -a 256 -c SHA256SUMS
    else
        sha256sum "$name" > SHA256SUMS
        sha256sum -c SHA256SUMS
    fi
)
