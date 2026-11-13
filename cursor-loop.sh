#!/bin/sh
set -eu

usage() {
	cat <<'EOF'
用法：sh cursor-loop.sh [選項]

選項：
  -i, --interval SECONDS   移動間隔秒數，範圍 1 到 86400，預設 300
  -d, --distance POINTS    游標位移點數，範圍 1 到 1000，預設 30
  -h, --help               顯示此說明

範例：
  sh cursor-loop.sh
  sh cursor-loop.sh --interval 60 --distance 20
  sh cursor-loop.sh --interval=60 --distance=20
EOF
}

interval=300
distance=30

while [ "$#" -gt 0 ]; do
	case "$1" in
		-h|--help)
			usage
			exit 0
			;;
		-i|--interval)
			if [ "$#" -lt 2 ]; then
				printf '缺少 --interval 的秒數。\n' >&2
				usage >&2
				exit 2
			fi
			interval=$2
			shift 2
			;;
		--interval=*)
			interval=${1#*=}
			shift
			;;
		-d|--distance)
			if [ "$#" -lt 2 ]; then
				printf '缺少 --distance 的點數。\n' >&2
				usage >&2
				exit 2
			fi
			distance=$2
			shift 2
			;;
		--distance=*)
			distance=${1#*=}
			shift
			;;
		*)
			printf '未知參數：%s\n' "$1" >&2
			usage >&2
			exit 2
			;;
	esac
done

case "$interval" in
	''|*[!0-9]*) printf '間隔必須是整數秒。\n' >&2; exit 2 ;;
esac
case "$distance" in
	''|*[!0-9]*) printf '位移必須是整數點數。\n' >&2; exit 2 ;;
esac
if [ "$interval" -lt 1 ] || [ "$interval" -gt 86400 ]; then
	printf '間隔範圍是 1 到 86400 秒。\n' >&2
	exit 2
fi
if [ "$distance" -lt 1 ] || [ "$distance" -gt 1000 ]; then
	printf '位移範圍是 1 到 1000 點。\n' >&2
	exit 2
fi

exec caffeinate -dimsu osascript -l JavaScript - "$interval" "$distance" <<'JXA'
ObjC.import("CoreGraphics");
ObjC.import("Foundation");

function run(argv) {
	var interval = Number(argv[0]);
	var distance = Number(argv[1]);

	console.log("游標循環已啟動；按 Ctrl+C 停止。");

	while (true) {
		var event = $.CGEventCreate(null);
		if (!event) {
			throw new Error("無法讀取游標位置");
		}

		var start = $.CGEventGetLocation(event);
		var destination = $.CGPointMake(start.x + distance, start.y);
		var moveResult = Number($.CGWarpMouseCursorPosition(destination));
		if (moveResult !== 0) {
			throw new Error("游標移動失敗，錯誤碼：" + moveResult);
		}

		$.NSThread.sleepForTimeInterval(0.5);
		$.CGWarpMouseCursorPosition(start);
		$.NSThread.sleepForTimeInterval(interval);
	}
}
JXA