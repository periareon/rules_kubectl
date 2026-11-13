"""kubectl launcher rule"""

load("@rules_go//go:def.bzl", "go_binary")

_LAUNCHER_IMPORTPATH = "github.com/periareon/rules_kubectl/kubectl/private/launcher"

def kubectl_launcher(name, toolchain, **kwargs):
    """Wrap a `kubectl` toolchain's binary for `bazel run`.

    The executable produced changes to `BUILD_WORKING_DIRECTORY` (the directory
    `bazel run` was invoked from) before starting `kubectl`, so relative paths in
    arguments such as `-f ./deploy.yaml` resolve the way they would for a locally
    installed `kubectl`. Arguments, environment and exit status pass through
    unchanged.

    The launcher finds `kubectl` through runfiles: the rlocationpath exposed by
    the toolchain's `KUBECTL_RLOCATIONPATH` make variable is linked into the
    binary, so it also works when another binary or test executes it directly.

    Args:
        name (str): The name of the target.
        toolchain (Label): A `kubectl_toolchain`, or
            `@rules_kubectl//kubectl:current_toolchain` for the resolved one.
        **kwargs (dict): Additional keyword arguments for `go_binary`.
    """
    go_binary(
        name = name,
        embed = [Label("//kubectl/private/launcher")],
        data = [toolchain],
        toolchains = [toolchain],
        x_defs = {
            _LAUNCHER_IMPORTPATH + ".kubectlRlocationpath": "$(KUBECTL_RLOCATIONPATH)",
        },
        **kwargs
    )
