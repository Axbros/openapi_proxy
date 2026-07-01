#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

IMAGE_NAME="${IMAGE_NAME:-openai_proxy}"
GIT_REMOTE="${GIT_REMOTE:-origin}"
GIT_BRANCH="${GIT_BRANCH:-main}"

echo "==> Pulling latest code from ${GIT_REMOTE}/${GIT_BRANCH}"
git fetch "${GIT_REMOTE}"
git checkout "${GIT_BRANCH}"
git pull --ff-only "${GIT_REMOTE}" "${GIT_BRANCH}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
TAGGED_IMAGE="${IMAGE_NAME}:${TIMESTAMP}"
LATEST_IMAGE="${IMAGE_NAME}:latest"

echo "==> Building image ${TAGGED_IMAGE}"
docker build -t "${TAGGED_IMAGE}" -t "${LATEST_IMAGE}" .

echo "==> Done: ${TAGGED_IMAGE}"
