"""kubectl_binary"""

load("@rules_go//go:def.bzl", "go_binary")
load(":runfiles.bzl", "rlocationpath")

_LAUNCHER_IMPORTPATH = "github.com/periareon/rules_kubectl/kubectl/private/launcher"

_RLOCATIONPATH = "$(rlocationpath "

# Bazel expansions that produce paths relative to a working directory the
# launcher does not use. Reject them so they fail at analysis time rather
# than as a confusing `kubectl` error.
_UNSUPPORTED_EXPANSIONS = [
    "$(execpath ",
    "$(execpaths ",
    "$(location ",
    "$(locations ",
    "$(rlocationpaths ",
    "$(rootpath ",
    "$(rootpaths ",
]

def _literal(value, text):
    for expansion in _UNSUPPORTED_EXPANSIONS:
        if expansion in text:
            fail("`{}` is not supported in `{}`. Use `$(rlocationpath <label>)` to reference files.".format(
                expansion.strip(),
                value,
            ))
    return struct(text = text)

def _segments(ctx, value):
    """Split `value` into literal text and `$(rlocationpath <label>)` references.

    The launcher turns each reference into an absolute path through runfiles at
    run time, so arguments keep working after it changes directory.
    """
    segments = []
    rest = value
    for _ in range(len(value) + 1):
        start = rest.find(_RLOCATIONPATH)
        if start < 0:
            break
        end = rest.find(")", start)
        if end < 0:
            fail("Unterminated `$(rlocationpath` in `{}`".format(value))
        if start > 0:
            segments.append(_literal(value, rest[:start]))
        segments.append(struct(
            runfile = ctx.expand_location(rest[start:end + 1], ctx.attr.data),
        ))
        rest = rest[end + 1:]
    if rest:
        segments.append(_literal(value, rest))
    return segments

def _kubectl_binary_config_impl(ctx):
    if ctx.attr.kubectl:
        kubectl = ctx.file.kubectl
    else:
        toolchain = ctx.toolchains[Label("//kubectl:toolchain_type")]
        if toolchain == None:
            fail("No kubectl toolchain is registered for {}. Set `kubectl` to use a specific binary.".format(ctx.label))
        kubectl = toolchain.kubectl

    config = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.write(config, json.encode_indent(struct(
        kubectl = rlocationpath(kubectl, ctx.workspace_name),
        args = [_segments(ctx, arg) for arg in ctx.attr.arguments],
        env = {key: _segments(ctx, value) for key, value in ctx.attr.environment.items()},
    )))

    runfiles = ctx.runfiles(files = [config, kubectl] + ctx.files.data).merge_all([
        data[DefaultInfo].default_runfiles
        for data in ctx.attr.data
    ])

    return [DefaultInfo(
        files = depset([config]),
        runfiles = runfiles,
    )]

_kubectl_binary_config = rule(
    implementation = _kubectl_binary_config_impl,
    doc = "Writes the launcher configuration for a `kubectl_binary`.",
    attrs = {
        "arguments": attr.string_list(
            doc = "Arguments to pass to `kubectl`.",
        ),
        "data": attr.label_list(
            doc = "Files available to `kubectl` at run time.",
            allow_files = True,
        ),
        "environment": attr.string_dict(
            doc = "Environment variables to set for `kubectl`.",
        ),
        "kubectl": attr.label(
            doc = "A kubectl binary. Defaults to the resolved toolchain's.",
            allow_single_file = True,
        ),
    },
    toolchains = [config_common.toolchain_type(Label("//kubectl:toolchain_type"), mandatory = False)],
)

def kubectl_binary(name, args = [], data = [], env = {}, kubectl = None, **kwargs):
    """An executable that runs `kubectl` with a fixed set of arguments.

    The target is meant for `bazel run`. Anything passed after `--` is appended \
    to `args`, and `kubectl` starts in the directory `bazel run` was invoked \
    from, so relative paths on the command line resolve the way they would for \
    a locally installed `kubectl`.

    Files Bazel knows about are referenced with `$(rlocationpath <label>)` in \
    `args` and `env`. The launcher resolves them through runfiles at run time, \
    which means the executable also works when another binary or test runs it.

    ```python
    load("@rules_kubectl//kubectl:defs.bzl", "kubectl_binary")

    kubectl_binary(
        name = "apply",
        args = [
            "apply",
            "--filename=$(rlocationpath :manifests)",
        ],
        data = [":manifests"],
    )

    kubectl_binary(
        name = "staging_pods",
        args = ["get", "pods"],
        data = ["staging.kubeconfig"],
        env = {"KUBECONFIG": "$(rlocationpath staging.kubeconfig)"},
    )
    ```

    ```bash
    bazel run //deploy:apply -- --namespace my-namespace
    ```

    Nothing about clusters, contexts or namespaces is decided here; that is \
    left to the arguments and the environment.

    Args:
        name (str): The name of the target.
        args (list): Arguments for `kubectl`. `$(rlocationpath <label>)` \
            references files from `data`.
        data (list): Files `kubectl` may read at run time.
        env (dict): Environment variables set for `kubectl`, overriding \
            inherited values. `$(rlocationpath <label>)` references files \
            from `data`.
        kubectl (Label): A specific kubectl binary. By default the binary of \
            the resolved toolchain is used.
        **kwargs (dict): Additional keyword arguments for the underlying \
            `go_binary`, such as `visibility`.
    """
    config = name + ".config"

    common = {
        key: kwargs[key]
        for key in ("compatible_with", "tags", "target_compatible_with", "testonly")
        if key in kwargs
    }

    _kubectl_binary_config(
        name = config,
        arguments = args,
        data = data,
        environment = env,
        kubectl = kubectl,
        visibility = ["//visibility:private"],
        **common
    )

    go_binary(
        name = name,
        embed = [Label("//kubectl/private/launcher")],
        data = [config],
        x_defs = {
            _LAUNCHER_IMPORTPATH + ".configRlocationpath": "$(rlocationpath :{})".format(config),
        },
        **kwargs
    )
