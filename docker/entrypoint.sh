#!/usr/bin/env bash
# Docker entrypoint for edx-platform.
#
# Usage (via CMD or docker run):
#   lms          – start the LMS with gunicorn
#   cms          – start the CMS/Studio with gunicorn
#   lms_worker   – start an LMS Celery worker
#   cms_worker   – start a CMS Celery worker
#   shell        – drop into bash
#   <anything>   – exec the given command directly

set -euo pipefail

PLATFORM_ROOT=/edx/app/edxapp/edx-platform

wait_for_service() {
    local host="$1"
    local port="$2"
    local label="${3:-$host:$port}"
    echo "Waiting for $label ..."
    until python -c "import socket; s=socket.create_connection(('$host',$port),2)" 2>/dev/null; do
        sleep 2
    done
    echo "$label is up."
}

case "${1:-lms}" in
    lms)
        wait_for_service "${MYSQL_HOST:-mysql}" "${MYSQL_PORT:-3306}" MySQL
        wait_for_service "${MONGO_HOST:-mongo}" "${MONGO_PORT:-27017}" MongoDB
        wait_for_service "${MEMCACHE_HOST:-memcached}" "${MEMCACHE_PORT:-11211}" Memcached
        exec gunicorn \
            --name lms \
            --bind "0.0.0.0:8000" \
            --workers "${LMS_WORKERS:-4}" \
            --timeout 300 \
            --max-requests 1000 \
            --pythonpath "${PLATFORM_ROOT}" \
            "lms.wsgi:application"
        ;;
    cms)
        wait_for_service "${MYSQL_HOST:-mysql}" "${MYSQL_PORT:-3306}" MySQL
        wait_for_service "${MONGO_HOST:-mongo}" "${MONGO_PORT:-27017}" MongoDB
        wait_for_service "${MEMCACHE_HOST:-memcached}" "${MEMCACHE_PORT:-11211}" Memcached
        exec gunicorn \
            --name cms \
            --bind "0.0.0.0:8010" \
            --workers "${CMS_WORKERS:-2}" \
            --timeout 300 \
            --max-requests 1000 \
            --pythonpath "${PLATFORM_ROOT}" \
            "cms.wsgi:application"
        ;;
    lms_worker)
        wait_for_service "${MYSQL_HOST:-mysql}" "${MYSQL_PORT:-3306}" MySQL
        wait_for_service "${MONGO_HOST:-mongo}" "${MONGO_PORT:-27017}" MongoDB
        cd "${PLATFORM_ROOT}"
        exec celery -A lms.celery worker \
            --loglevel="${LOG_LEVEL:-INFO}" \
            --queues="${LMS_WORKER_QUEUES:-lms.default,lms.high,lms.low}"
        ;;
    cms_worker)
        wait_for_service "${MYSQL_HOST:-mysql}" "${MYSQL_PORT:-3306}" MySQL
        wait_for_service "${MONGO_HOST:-mongo}" "${MONGO_PORT:-27017}" MongoDB
        cd "${PLATFORM_ROOT}"
        exec celery -A cms.celery worker \
            --loglevel="${LOG_LEVEL:-INFO}" \
            --queues="${CMS_WORKER_QUEUES:-cms.default,cms.high,cms.low}"
        ;;
    shell)
        exec /bin/bash
        ;;
    *)
        exec "$@"
        ;;
esac
