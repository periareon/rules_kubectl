# rules_kubectl

Bazel rules for a hermetic [`kubectl`](https://kubernetes.io/docs/reference/kubectl/).

The module does two things and nothing else:

- it fetches `kubectl` for the host and exposes it as `@kubectl//:kubectl`
  for `bazel run`, and
- it defines `@rules_kubectl//kubectl:toolchain_type` so that any rule set needing
  `kubectl` in an action can share one binary instead of fetching its own.

There are no `kubectl_apply` style rules here. Opinions about kubeconfigs,
contexts and namespaces belong in the rule sets built on top of the toolchain.

## Setup

```python
bazel_dep(name = "rules_kubectl", version = "0.1.0")

kubectl = use_extension("@rules_kubectl//kubectl:extensions.bzl", "kubectl")
kubectl.toolchain()
use_repo(kubectl, "kubectl")
```

`rules_kubectl` registers the toolchains itself, so no `register_toolchains`
call is needed.

The `bazel run` launcher in front of `kubectl` is a small Go program that finds
the binary through runfiles, so `rules_go` and a Go SDK are fetched the first
time it is built.

## Running kubectl

```bash
bazel run @kubectl -- get pods --namespace my-namespace
bazel run @kubectl -- apply -f ./deploy/configmap.yaml
bazel run @kubectl -- kustomize ./deploy/overlays/dev
```

`bazel run` passes your environment through, so `KUBECONFIG`, `~/.kube/config`
and the usual `--context` / `--namespace` flags behave exactly as they do for
a locally installed `kubectl`. The `@kubectl//:kubectl` target also starts
`kubectl` from the directory you ran `bazel` in rather than from the runfiles
tree, which is why the relative paths above work.

## Pinning a version

`rules_kubectl` ships checksums for a single default version. Clusters more
than one minor version away from it should pin a matching release:

```python
kubectl.toolchain(version = "1.36.5")
```

Checksums for versions the module does not know about are looked up from the
upstream `.sha256` files while the extension is evaluated. On Bazel 8.5 and
newer the digests are then stored as facts in `MODULE.bazel.lock`, so the
lookup happens once per version and airgapped builds keep working from the
lockfile. Older Bazel versions repeat the lookup whenever the extension is
re-evaluated.

Several versions can live side by side by giving each tag its own repository
name. Only the first `toolchain` tag in the root module decides which version
the registered toolchains serve:

```python
kubectl.toolchain()
kubectl.toolchain(name = "kubectl_legacy", version = "1.35.6")
use_repo(kubectl, "kubectl", "kubectl_legacy")
```

## Use in a genrule

The resolved toolchain exposes the binary through two make variables:
`KUBECTL` is its execpath, for use in actions, and `KUBECTL_RLOCATIONPATH` is
its rlocationpath, for looking it up in runfiles.

```python
genrule(
    name = "kubectl_version",
    outs = ["kubectl_version.json"],
    cmd = "$(KUBECTL) version --client --output json > $@",
    toolchains = ["@rules_kubectl//kubectl:current_toolchain"],
)

sh_test(
    name = "kubectl_version_test",
    srcs = ["kubectl_version_test.sh"],
    data = ["@rules_kubectl//kubectl:current_toolchain"],
    env = {"KUBECTL": "$(KUBECTL_RLOCATIONPATH)"},
    toolchains = ["@rules_kubectl//kubectl:current_toolchain"],
)
```

## For rule authors

Depend on the toolchain type and read the binary from the resolved
`ToolchainInfo`:

```python
def _impl(ctx):
    toolchain = ctx.toolchains["@rules_kubectl//kubectl:toolchain_type"]
    ctx.actions.run(
        executable = toolchain.kubectl,
        ...
    )

my_rule = rule(
    implementation = _impl,
    toolchains = ["@rules_kubectl//kubectl:toolchain_type"],
)
```

`ToolchainInfo` carries `kubectl` (the binary `File`) and `version` (the
version string, without a leading `v`).

## Updating the default version

```bash
bazel run //tools:fetch_checksums -- 1.38.0
```

prints the table entry for `kubectl/private/versions.bzl`. Add it, update
`DEFAULT_VERSION`, and remove the previous entry.
