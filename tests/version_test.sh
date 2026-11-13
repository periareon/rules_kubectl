#!/usr/bin/env bash
# Checks that kubectl reports the expected client version.
#
# When VERSION_JSON is set it names a runfile already holding the output of
# `kubectl version --client --output json` (produced by a genrule);
# otherwise KUBECTL names the binary to run.
# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

set -euo pipefail

if [[ -n "${VERSION_JSON:-}" ]]; then
  json="$(cat "$(rlocation "${VERSION_JSON}")")"
else
  kubectl="$(rlocation "${KUBECTL}")"
  # Keep the test independent of any kubeconfig on the host.
  json="$(HOME="${TEST_TMPDIR}" KUBECONFIG= "${kubectl}" version --client --output json)"
fi

if ! grep -q "\"gitVersion\": \"${EXPECTED_VERSION}\"" <<<"${json}"; then
  echo "Expected kubectl ${EXPECTED_VERSION}, got:" >&2
  echo "${json}" >&2
  exit 1
fi
