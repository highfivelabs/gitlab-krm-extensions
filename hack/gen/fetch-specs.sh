#!/usr/bin/env bash
# Copyright 2026 High Five Labs
# SPDX-License-Identifier: Apache-2.0
# Download the vendor's OpenAPI specs at the commits vendor.yaml pins.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p specs
[ -s specs/gitlab.yaml ] || curl -fsSL -o specs/gitlab.yaml "https://gitlab.com/gitlab-org/gitlab/-/raw/35ad75ae9e9a16a5bebda796afdf0679ba6ace40/doc/api/openapi/openapi_v3.yaml"
