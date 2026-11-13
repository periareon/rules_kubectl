"""kubectl toolchain rules"""

def _rlocationpath(file, workspace_name):
    """Return the runfiles path of `file`, as `$(rlocationpath)` would."""
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]
    return "{}/{}".format(workspace_name, file.short_path)

def _kubectl_toolchain_impl(ctx):
    binary = ctx.file.kubectl

    template_variables = platform_common.TemplateVariableInfo({
        "KUBECTL": binary.path,
        "KUBECTL_RLOCATIONPATH": _rlocationpath(binary, ctx.workspace_name),
    })

    default_info = DefaultInfo(
        files = depset([binary]),
        runfiles = ctx.runfiles(files = [binary]),
    )

    toolchain_info = platform_common.ToolchainInfo(
        default_info = default_info,
        kubectl = binary,
        template_variables = template_variables,
        version = ctx.attr.version,
    )

    return [default_info, toolchain_info, template_variables]

kubectl_toolchain = rule(
    implementation = _kubectl_toolchain_impl,
    doc = """\
A kubectl toolchain.

Rules consume it through `@rules_kubectl//kubectl:toolchain_type`:

```python
def _impl(ctx):
    toolchain = ctx.toolchains["@rules_kubectl//kubectl:toolchain_type"]
    ctx.actions.run(
        executable = toolchain.kubectl,
        ...
    )
```

The `ToolchainInfo` carries `kubectl` (the binary `File`) and `version` (a \
string, possibly empty).

`@rules_kubectl//kubectl:current_toolchain` exposes the binary through two make \
variables: `KUBECTL` is its execpath, for use in actions, and \
`KUBECTL_RLOCATIONPATH` is its rlocationpath, for looking it up in runfiles.

```python
genrule(
    name = "pods",
    outs = ["pods.txt"],
    cmd = "$(KUBECTL) version --client > $@",
    toolchains = ["@rules_kubectl//kubectl:current_toolchain"],
)

sh_test(
    name = "pods_test",
    srcs = ["pods_test.sh"],
    data = ["@rules_kubectl//kubectl:current_toolchain"],
    env = {"KUBECTL": "$(KUBECTL_RLOCATIONPATH)"},
    toolchains = ["@rules_kubectl//kubectl:current_toolchain"],
)
```
""",
    attrs = {
        "kubectl": attr.label(
            doc = "A kubectl binary.",
            allow_single_file = True,
            mandatory = True,
            cfg = "exec",
        ),
        "version": attr.string(
            doc = "The version of `kubectl`, without a leading `v`. Informational.",
        ),
    },
)

def _kubectl_toolchain_alias_impl(ctx):
    toolchain_info = ctx.toolchains[Label("//kubectl:toolchain_type")]
    return [
        toolchain_info,
        toolchain_info.default_info,
        toolchain_info.template_variables,
    ]

kubectl_toolchain_alias = rule(
    implementation = _kubectl_toolchain_alias_impl,
    doc = """\
Exposes a concrete toolchain which is the result of Bazel resolving the
kubectl toolchain for the execution or target platform.
Workaround for https://github.com/bazelbuild/bazel/issues/14009
""",
    toolchains = [str(Label("//kubectl:toolchain_type"))],
)
