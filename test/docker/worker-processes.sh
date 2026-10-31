#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT_DIR}/docker/rootfs/etc/s6-overlay/s6-rc.d/prepare/42-worker-processes.sh"
SOURCE_CONFIG="${ROOT_DIR}/docker/rootfs/etc/nginx/nginx.conf"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

run_script() {
	local mounted="$1"
	(
		is_mounted() {
			[ "$mounted" = "true" ]
		}
		log_info() {
			:
		}
		log_fatal() {
			echo "$1" >&2
			exit 1
		}
		. "$SCRIPT"
	)
}

cp "$SOURCE_CONFIG" "${TEST_DIR}/detected.conf"
NGINX_CONFIG_FILE="${TEST_DIR}/detected.conf" run_script false
grep -Fxq "worker_processes $(nproc);" "${TEST_DIR}/detected.conf"

cp "$SOURCE_CONFIG" "${TEST_DIR}/override.conf"
NGINX_CONFIG_FILE="${TEST_DIR}/override.conf" NGINX_WORKER_PROCESSES=3 run_script false
grep -Fxq "worker_processes 3;" "${TEST_DIR}/override.conf"

cp "$SOURCE_CONFIG" "${TEST_DIR}/auto.conf"
NGINX_CONFIG_FILE="${TEST_DIR}/auto.conf" NGINX_WORKER_PROCESSES=auto run_script false
grep -Fxq "worker_processes auto;" "${TEST_DIR}/auto.conf"

cp "$SOURCE_CONFIG" "${TEST_DIR}/invalid.conf"
if NGINX_CONFIG_FILE="${TEST_DIR}/invalid.conf" NGINX_WORKER_PROCESSES=0 run_script false; then
	echo "Expected an invalid worker override to fail" >&2
	exit 1
fi
grep -Fxq "worker_processes auto;" "${TEST_DIR}/invalid.conf"

cp "$SOURCE_CONFIG" "${TEST_DIR}/mounted.conf"
NGINX_CONFIG_FILE="${TEST_DIR}/mounted.conf" NGINX_WORKER_PROCESSES=3 run_script true
grep -Fxq "worker_processes auto;" "${TEST_DIR}/mounted.conf"
