#!/bin/sh
set -eu

if [ -z "${BACKEND_URL:-}" ]; then
  echo "BACKEND_URL is required (for example https://languagebackend-production.up.railway.app)" >&2
  exit 1
fi

BACKEND_URL=$(printf '%s' "$BACKEND_URL" | sed 's#/$##')
BACKEND_HOST=$(printf '%s' "$BACKEND_URL" | sed -E 's#^https?://##' | cut -d/ -f1)
export BACKEND_URL BACKEND_HOST

envsubst '${BACKEND_URL} ${BACKEND_HOST}' \
  < /etc/nginx/templates/default.conf.template \
  > /etc/nginx/conf.d/default.conf

exec "$@"
