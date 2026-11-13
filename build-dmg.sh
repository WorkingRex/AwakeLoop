#!/bin/sh
set -eu

cd "$(dirname "$0")"
sh build-app.sh

staging=$(mktemp -d "${TMPDIR:-/tmp}/AwakeLoopDMG.XXXXXX")
trap 'rm -rf "$staging"' EXIT

ditto build/AwakeLoop.app "$staging/AwakeLoop.app"
ln -s /Applications "$staging/Applications"
cp INSTALL.txt "$staging/INSTALL.txt"

mkdir -p build
hdiutil create \
	-volname AwakeLoop \
	-srcfolder "$staging" \
	-ov \
	-format UDZO \
	build/AwakeLoop-Installer.dmg

printf 'Built %s\n' "build/AwakeLoop-Installer.dmg"