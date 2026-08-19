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

BUILD_ID="${RAILWAY_DEPLOYMENT_ID:-$(date +%s)}"
WEB_ROOT=/usr/share/nginx/html

for asset in flutter_bootstrap.js index.html; do
  if [ -f "$WEB_ROOT/$asset" ]; then
    sed -i "s|main.dart.js|main.dart.js?v=${BUILD_ID}|g" "$WEB_ROOT/$asset"
  fi
done

printf 'window.CANTO_API_BASE="/api";\n' > "$WEB_ROOT/config.js"

if ! grep -q 'config.js' "$WEB_ROOT/index.html"; then
  awk '
    /flutter_bootstrap.js/ && !done {
      print "  <script src=\"config.js\"></script>"
      done = 1
    }
    { print }
  ' "$WEB_ROOT/index.html" > "$WEB_ROOT/index.html.tmp"
  mv "$WEB_ROOT/index.html.tmp" "$WEB_ROOT/index.html"
fi

exec "$@"
