"""# rules_kubectl

Bazel rules for a hermetic `kubectl`.

- `@kubectl//:kubectl` runs the host platform's binary from the directory
  `bazel run` was invoked in.
- `@rules_kubectl//kubectl:toolchain_type` is the toolchain type rules consume to run
  `kubectl` in an action.
- `@rules_kubectl//kubectl:current_toolchain` exposes the resolved binary to
  `genrule` and friends as the `KUBECTL` (execpath) and `KUBECTL_RLOCATIONPATH`
  (rlocationpath) make variables.
"""

load("//kubectl/private:toolchain.bzl", _kubectl_toolchain = "kubectl_toolchain")

kubectl_toolchain = _kubectl_toolchain
