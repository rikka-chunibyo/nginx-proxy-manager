#!/command/with-contenv bash
# shellcheck shell=bash

set -e

NGINX_CONFIG_FILE="${NGINX_CONFIG_FILE:-/etc/nginx/nginx.conf}"

if is_mounted "$NGINX_CONFIG_FILE"; then
	log_info "Nginx worker processes: unchanged (${NGINX_CONFIG_FILE} is mounted)"
	return
fi

WORKER_PROCESSES="${NGINX_WORKER_PROCESSES:-}"
WORKER_SOURCE="NGINX_WORKER_PROCESSES"

if [ -z "$WORKER_PROCESSES" ]; then
	WORKER_PROCESSES="$(nproc 2>/dev/null || true)"
	WORKER_SOURCE="available CPUs"
fi

if [ "$WORKER_PROCESSES" != "auto" ] && ! [[ "$WORKER_PROCESSES" =~ ^[1-9][0-9]*$ ]]; then
	log_fatal "NGINX_WORKER_PROCESSES must be 'auto' or a positive integer; got '${WORKER_PROCESSES:-empty}'."
fi

WORKER_DIRECTIVE='^[[:space:]]*worker_processes[[:space:]]+[^;]+;'
if [ "$(grep -Ec "$WORKER_DIRECTIVE" "$NGINX_CONFIG_FILE")" -ne 1 ]; then
	log_fatal "Expected exactly one worker_processes directive in ${NGINX_CONFIG_FILE}."
fi

sed -Ei "s/${WORKER_DIRECTIVE}/worker_processes ${WORKER_PROCESSES};/" "$NGINX_CONFIG_FILE"
log_info "Nginx worker processes: ${WORKER_PROCESSES} (${WORKER_SOURCE})"
