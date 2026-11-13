#!/bin/sh
set -eu

cd "$(dirname "$0")"
swift build --triple arm64-apple-macosx13.0 -c release --build-path .build/arm64
swift build --triple x86_64-apple-macosx13.0 -c release --build-path .build/x86_64

app="build/AwakeLoop.app"
mkdir -p "$app/Contents/MacOS"
lipo -create \
	.build/arm64/out/Products/Release/AwakeLoop \
	.build/x86_64/out/Products/Release/AwakeLoop \
	-output "$app/Contents/MacOS/AwakeLoop"
cp Info.plist "$app/Contents/Info.plist"
printf 'Built %s\n' "$app"