#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-homechat:ci-smoke}"
CONTAINER_NAME="${CONTAINER_NAME:-homechat-ci-smoke}"

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup

CI_SECRET_KEY_BASE="$(printf '0%.0s' {1..128})"
CI_API_TOKEN_PEPPER="ci-smoke-api-token-pepper"

DOCKER_BUILDKIT=1 docker build -t "$IMAGE_TAG" .

docker run -d \
  --name "$CONTAINER_NAME" \
  -p 127.0.0.1::80 \
  -e RAILS_ENV=production \
  -e RAILS_LOG_TO_STDOUT=1 \
  -e RAILS_SERVE_STATIC_FILES=true \
  -e RAILS_ALLOW_INSECURE_HTTP=true \
  -e SECRET_KEY_BASE="$CI_SECRET_KEY_BASE" \
  -e API_TOKEN_PEPPER="$CI_API_TOKEN_PEPPER" \
  -e AR_ENCRYPTION_PRIMARY_KEY=00000000000000000000000000000000 \
  -e AR_ENCRYPTION_DETERMINISTIC_KEY=11111111111111111111111111111111 \
  -e AR_ENCRYPTION_KEY_DERIVATION_SALT=22222222222222222222222222222222 \
  -e DISCOVERY_MODE=cloud \
  -e SOLID_QUEUE_IN_PUMA=false \
  "$IMAGE_TAG"

host_port=""
for attempt in {1..60}; do
  host_port="$(docker port "$CONTAINER_NAME" 80/tcp | sed -E 's/^.*:([0-9]+)$/\1/' | tail -1)"
  if [[ -n "$host_port" ]] && curl -fsS "http://127.0.0.1:${host_port}/up" >/dev/null; then
    echo "PASS: production container responded on /up via port ${host_port}"
    curl -fsS -o /dev/null "http://127.0.0.1:${host_port}/signin"
    echo "PASS: production container responded on /signin"
    exit 0
  fi

  if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    echo "Container exited before becoming healthy" >&2
    docker logs "$CONTAINER_NAME" >&2 || true
    exit 1
  fi

  sleep 2
done

echo "Container did not become ready" >&2
docker logs "$CONTAINER_NAME" >&2 || true
exit 1
