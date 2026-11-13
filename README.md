# rules_kubectl

Bazel rules for a hermetic [`kubectl`](https://kubernetes.io/docs/reference/kubectl/).

The module fetches `kubectl` for the host, exposes it as `@kubectl//:kubectl`
for `bazel run`, and defines `@rules_kubectl//kubectl:toolchain_type` so rule
sets that need `kubectl` in an action can share one binary.

## Setup

```python
bazel_dep(name = "rules_kubectl", version = "0.1.0")

kubectl = use_extension("@rules_kubectl//kubectl:extensions.bzl", "kubectl")
kubectl.toolchain()
use_repo(kubectl, "kubectl")
```

```bash
bazel run @kubectl -- get pods
```

## Documentation

Version pinning, genrule usage, the toolchain API for rule authors, and the
rule/extension reference live at https://periareon.github.io/rules_kubectl.
