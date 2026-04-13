#!/usr/bin/env bash
set -euo pipefail

COCO_PKG="${1:?Usage: $0 COCO_PKG IMG_TAG [REGISTRY]}"
IMG_TAG="${2:?Usage: $0 COCO_PKG IMG_TAG [REGISTRY]}"
REGISTRY="${3:-${REGISTRY:-ghcr.io}}"

cosign sign --yes --key keys/sign/cosign.key "${REGISTRY}/${COCO_PKG}:${IMG_TAG}"
