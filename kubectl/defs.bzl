"""# rules_kubectl

Bazel rules for a hermetic `kubectl`.

- `@kubectl//:kubectl` runs the host platform's binary from the directory
  `bazel run` was invoked in.
- `kubectl_binary` does the same for a fixed `kubectl` invocation, with
  Bazel-generated files wired into its arguments and environment.
- `@rules_kubectl//kubectl:toolchain_type` is the toolchain type rules consume to run
  `kubectl` in an action.
- `@rules_kubectl//kubectl:current_toolchain` exposes the resolved binary to
  `genrule` and friends as the `KUBECTL` (execpath) and `KUBECTL_RLOCATIONPATH`
  (rlocationpath) make variables.
"""

load("//kubectl/private:kubectl_binary.bzl", _kubectl_binary = "kubectl_binary")
load("//kubectl/private:toolchain.bzl", _kubectl_toolchain = "kubectl_toolchain")

kubectl_binary = _kubectl_binary
kubectl_toolchain = _kubectl_toolchain
