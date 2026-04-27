#!/bin/sh
# Entrypoint for the Flutter web / nginx container.
#
# Substitutes ${BACKEND_URL} in the nginx config template before nginx starts.
# The single-quoted '$BACKEND_URL' argument tells envsubst to ONLY replace that
# variable, leaving nginx's own $host, $uri, $remote_addr, etc. untouched.
#
# BACKEND_URL is the URL of the backend Dart server.
#   - Docker Desktop:  http://backend:8080  (set via docker-compose environment)
#   - Render:          https://fs-hub-backend.onrender.com  (set via Render Dashboard)
#
# Defaults to http://localhost:8080 if not set (safe fallback for local dev).

BACKEND_URL="${BACKEND_URL:-http://localhost:8080}"
export BACKEND_URL

echo "[entrypoint] Configuring nginx proxy to: $BACKEND_URL"
envsubst '$BACKEND_URL' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

exec nginx -g 'daemon off;'
