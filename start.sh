#!/bin/sh

# 项目根目录：优先使用 WORK_DIR，否则为脚本所在目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
WORK_DIR="${WORK_DIR:-$SCRIPT_DIR}"
cd "$WORK_DIR" || exit 1

# 使用系统 python3 -m gunicorn，避免 PATH 中无 gunicorn 时失败（不使用虚拟环境）
# 通过 openvpn-webui.wsgi 或 gunicorn_config 识别本项目的 gunicorn 主进程，避免误杀其它 gunicorn
get_gunicorn_pid() {
  ps -ef | grep gunicorn | grep -E 'openvpn-webui\.wsgi|gunicorn_config' | grep -v grep | awk '{print $2}' | head -1
}

web_start() {
  pid=$(get_gunicorn_pid)
  if [ -n "$pid" ]; then
    echo "gunicorn already running (pid $pid)"
    return
  fi
  python3 -m gunicorn openvpn-webui.wsgi -c gunicorn_config.py >> run.log 2>&1 &
  sleep 2
  pid=$(get_gunicorn_pid)
  if [ -n "$pid" ]; then
    echo "gunicorn started successfully (pid $pid)"
  else
    echo "gunicorn failed to start, check run.log"
    exit 1
  fi
}

web_stop() {
  pid=$(get_gunicorn_pid)
  if [ -z "$pid" ]; then
    echo "gunicorn not running"
    return
  fi
  kill "$pid" 2>/dev/null
  echo "gunicorn stopped (pid $pid)"
}

web_status() {
  pid=$(get_gunicorn_pid)
  if [ -n "$pid" ]; then
    echo "gunicorn is running (pid $pid)"
  else
    echo "gunicorn is not running"
  fi
}

case "${1:-}" in
  start)
    web_start
    ;;
  stop)
    web_stop
    ;;
  status)
    web_status
    ;;
  restart)
    web_stop
    sleep 2
    web_start
    ;;
  *)
    echo "Usage: $0 {start|stop|status|restart}"
    exit 1
    ;;
esac
