#!/usr/bin/env bash
# Checks the `bazel run` behaviour of the @kubectl//:kubectl launcher.
#
# `kubectl kustomize .` only succeeds when run from inside a directory with
# a kustomization, which makes it a good probe for the working directory.
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

kubectl="$(rlocation "${KUBECTL}")"
export HOME="${TEST_TMPDIR}/home"
export KUBECONFIG=
mkdir -p "${HOME}"

kustomization="${TEST_TMPDIR}/kustomization"
mkdir -p "${kustomization}"
cat > "${kustomization}/kustomization.yaml" <<'YAML'
resources:
  - configmap.yaml
YAML
cat > "${kustomization}/configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: launcher-test
YAML

elsewhere="${TEST_TMPDIR}/elsewhere"
mkdir -p "${elsewhere}"

echo "--- BUILD_WORKING_DIRECTORY moves kubectl to the user's directory"
output="$(cd "${elsewhere}" && BUILD_WORKING_DIRECTORY="${kustomization}" "${kubectl}" kustomize .)"
grep -q "name: launcher-test" <<<"${output}"

echo "--- without BUILD_WORKING_DIRECTORY the working directory is untouched"
output="$(cd "${kustomization}" && BUILD_WORKING_DIRECTORY= "${kubectl}" kustomize .)"
grep -q "name: launcher-test" <<<"${output}"

echo "--- a missing BUILD_WORKING_DIRECTORY is an error"
if (cd "${kustomization}" && BUILD_WORKING_DIRECTORY="${TEST_TMPDIR}/does-not-exist" "${kubectl}" kustomize . 2>/dev/null); then
  echo "Expected the launcher to fail" >&2
  exit 1
fi

echo "--- the exit status of kubectl is forwarded"
if (cd "${elsewhere}" && BUILD_WORKING_DIRECTORY="${elsewhere}" "${kubectl}" kustomize . 2>/dev/null); then
  echo "Expected kustomize to fail in a directory without a kustomization" >&2
  exit 1
fi
