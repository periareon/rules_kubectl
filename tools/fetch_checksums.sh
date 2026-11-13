#!/usr/bin/env bash
# Prints the `VERSIONS` table entry for a kubectl release, for pasting into
# `kubectl/private/versions.bzl`.
#
# Usage:
#   bazel run //tools:fetch_checksums -- <version>
set -euo pipefail

version="${1:?usage: fetch_checksums.sh <version>}"
version="${version#v}"

# Keep in sync with `PLATFORMS` in `kubectl/private/versions.bzl`.
platforms=(
  darwin-amd64
  darwin-arm64
  linux-386
  linux-amd64
  linux-arm
  linux-arm64
  linux-ppc64le
  linux-s390x
  windows-amd64
  windows-arm64
)

echo "    \"${version}\": {"
for platform in "${platforms[@]}"; do
  os="${platform%-*}"
  arch="${platform#*-}"
  ext=""
  if [[ "${os}" == "windows" ]]; then
    ext=".exe"
  fi
  url="https://dl.k8s.io/release/v${version}/bin/${os}/${arch}/kubectl${ext}.sha256"
  sha256="$(curl --fail --silent --show-error --location "${url}" | awk '{ print $1 }')"
  echo "        \"${platform}\": \"${sha256}\","
done
echo "    },"
