#!/bin/sh
set -eu

cd "$(dirname "$0")"
swift build --triple arm64-apple-macosx13.0 -c release --build-path .build/arm64
swift build --triple x86_64-apple-macosx13.0 -c release --build-path .build/x86_64
arm64_bin=$(swift build --show-bin-path --triple arm64-apple-macosx13.0 -c release --build-path .build/arm64)
x86_64_bin=$(swift build --show-bin-path --triple x86_64-apple-macosx13.0 -c release --build-path .build/x86_64)

app="build/AwakeLoop.app"
mkdir -p "$app/Contents/MacOS"
lipo -create \
	"$arm64_bin/AwakeLoop" \
	"$x86_64_bin/AwakeLoop" \
	-output "$app/Contents/MacOS/AwakeLoop"
cp Info.plist "$app/Contents/Info.plist"
printf 'Built %s\n' "$app"