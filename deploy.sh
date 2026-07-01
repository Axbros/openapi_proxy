#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

IMAGE_NAME="${IMAGE_NAME:-openai_proxy}"
CONTAINER_NAME="${CONTAINER_NAME:-openai_proxy}"
HOST_PORT="${HOST_PORT:-8000}"
GIT_REMOTE="${GIT_REMOTE:-origin}"
GIT_BRANCH="${GIT_BRANCH:-main}"

if [[ ! -f .env ]]; then
  echo "Error: .env not found. Run: cp .env.example .env && edit .env"
  exit 1
fi

echo "==> Pulling latest code from ${GIT_REMOTE}/${GIT_BRANCH}"
git fetch "${GIT_REMOTE}"
git checkout "${GIT_BRANCH}"
git pull --ff-only "${GIT_REMOTE}" "${GIT_BRANCH}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
TAGGED_IMAGE="${IMAGE_NAME}:${TIMESTAMP}"
LATEST_IMAGE="${IMAGE_NAME}:latest"

echo "==> Building image ${TAGGED_IMAGE}"
docker build -t "${TAGGED_IMAGE}" -t "${LATEST_IMAGE}" .

if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "==> Stopping and removing existing container ${CONTAINER_NAME}"
  docker stop "${CONTAINER_NAME}"
  docker rm "${CONTAINER_NAME}"
fi

echo "==> Starting container ${CONTAINER_NAME} (${TAGGED_IMAGE})"
docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${HOST_PORT}:8000" \
  --env-file .env \
  --restart unless-stopped \
  "${TAGGED_IMAGE}"

echo "==> Deployed successfully"
echo "    Image:     ${TAGGED_IMAGE}"
echo "    Container: ${CONTAINER_NAME}"
echo "    URL:       http://localhost:${HOST_PORT}"
