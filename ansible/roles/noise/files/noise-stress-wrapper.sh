#!/usr/bin/env bash
# 불규칙 부하 생성기. systemd unit ExecStart 에서 호출.
# usage: noise-stress-wrapper.sh <profile>
# profile: cpu_light | cpu_heavy | mem_heavy | io_heavy | mixed
#
# 매 iteration 마다 stress-ng 인자 (강도) + active duration + idle gap 을 무작위 추첨.
# 추세가 평탄선이 아니라 톱니/계단/펄스가 섞인 불규칙 패턴이 되도록 함.

set -u

PROFILE="${1:-}"
if [ -z "$PROFILE" ]; then
  echo "usage: $0 <cpu_light|cpu_heavy|mem_heavy|io_heavy|mixed>" >&2
  exit 2
fi

CHILD_PID=0

shutdown() {
  if [ "$CHILD_PID" -gt 0 ] && kill -0 "$CHILD_PID" 2>/dev/null; then
    kill -TERM "$CHILD_PID" 2>/dev/null || true
    wait "$CHILD_PID" 2>/dev/null || true
  fi
  exit 0
}
trap shutdown TERM INT

rand_int() {
  local lo=$1 hi=$2
  echo $(( lo + RANDOM % (hi - lo + 1) ))
}

ARGS=""
IDLE=0

build_args() {
  case "$PROFILE" in
    cpu_light)
      local load duration
      load=$(rand_int 10 40)
      duration=$(rand_int 60 180)
      ARGS="--cpu 1 --cpu-load ${load} --timeout ${duration}s"
      IDLE=$(rand_int 30 120)
      ;;
    cpu_heavy)
      local cpus load duration
      cpus=$(rand_int 1 2)
      load=$(rand_int 30 50)
      duration=$(rand_int 60 240)
      ARGS="--cpu ${cpus} --cpu-load ${load} --timeout ${duration}s"
      IDLE=$(rand_int 30 90)
      ;;
    mem_heavy)
      local pct duration
      pct=$(rand_int 20 45)
      duration=$(rand_int 90 240)
      ARGS="--vm 1 --vm-bytes ${pct}% --vm-keep --timeout ${duration}s"
      IDLE=$(rand_int 30 120)
      ;;
    io_heavy)
      local bytes duration
      bytes=$(rand_int 30 200)
      duration=$(rand_int 60 180)
      ARGS="--hdd 1 --hdd-bytes ${bytes}M --timeout ${duration}s"
      IDLE=$(rand_int 30 120)
      ;;
    mixed)
      local cpuload mem duration
      cpuload=$(rand_int 15 35)
      mem=$(rand_int 30 80)
      duration=$(rand_int 60 180)
      ARGS="--cpu 1 --cpu-load ${cpuload} --vm 1 --vm-bytes ${mem}M --vm-keep --io 1 --timeout ${duration}s"
      IDLE=$(rand_int 30 90)
      ;;
    *)
      echo "unknown profile: $PROFILE" >&2
      exit 2
      ;;
  esac
}

while :; do
  build_args
  echo "[noise-stress-wrapper] profile=${PROFILE} args=${ARGS} idle_next=${IDLE}s"
  # shellcheck disable=SC2086
  /usr/bin/stress-ng ${ARGS} &
  CHILD_PID=$!
  wait "$CHILD_PID"
  CHILD_PID=0
  sleep "$IDLE"
done
