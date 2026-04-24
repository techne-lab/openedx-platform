#!/usr/bin/env bash
# docker/provision.sh
#
# One-time provisioning script run as part of `make create`.
# Runs Django migrations for both LMS and CMS, and creates a default
# superuser account for development.

set -euo pipefail

COMPOSE_CMD="${COMPOSE_CMD:-docker compose}"

echo "==> Running LMS migrations…"
$COMPOSE_CMD run --rm \
    -e DJANGO_SETTINGS_MODULE=lms.envs.devstack \
    lms \
    python manage.py lms migrate --database default --traceback --pythonpath=.

echo "==> Running LMS CSMH migrations…"
$COMPOSE_CMD run --rm \
    -e DJANGO_SETTINGS_MODULE=lms.envs.devstack \
    lms \
    python manage.py lms migrate --database student_module_history --traceback --pythonpath=.

echo "==> Running CMS migrations…"
$COMPOSE_CMD run --rm \
    -e DJANGO_SETTINGS_MODULE=cms.envs.devstack \
    cms \
    python manage.py cms migrate --database default --noinput --traceback --pythonpath=.

echo "==> Creating default superuser (user: edx / password: edx)…"
$COMPOSE_CMD run --rm \
    -e DJANGO_SETTINGS_MODULE=lms.envs.devstack \
    lms \
    python manage.py lms shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='edx').exists():
    User.objects.create_superuser('edx', 'edx@example.com', 'edx')
    print('Superuser created: edx / edx')
else:
    print('Superuser already exists.')
"

echo "==> Provisioning complete."
echo "    LMS:    http://localhost:18000"
echo "    Studio: http://localhost:18010"
echo "    Login:  edx / edx"
