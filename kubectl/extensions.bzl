"""# Bzlmod extension for `kubectl`"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load(
    "//kubectl/private:repositories.bzl",
    "kubectl_host_repository",
    "kubectl_toolchains_repository",
)
load(
    "//kubectl/private:versions.bzl",
    "DEFAULT_VERSION",
    "PLATFORMS",
    "VERSIONS",
    "kubectl_urls",
)

_HUB_NAME = "kubectl_toolchains"

def _binary_repo_name(version, platform):
    return "{}__{}_{}".format(_HUB_NAME, version, platform.replace("-", "_"))

def _find_modules(module_ctx):
    """Locate the root module and the `rules_kubectl` module.

    Outside of a root module (e.g. a `bazel mod` query) the root falls back to
    `rules_kubectl` itself.
    """
    root = None
    rules_module = None
    for mod in module_ctx.modules:
        if mod.is_root:
            root = mod
        if mod.name == "rules_kubectl":
            rules_module = mod
    if rules_module == None:
        fail("Unable to find the rules_kubectl module")
    if root == None:
        root = rules_module
    return root, rules_module

def _fetch_checksums(module_ctx, version):
    """Download the upstream `.sha256` files for a kubectl release.

    Args:
        module_ctx (module_ctx): The module extension context.
        version (str): The kubectl version, without a leading `v`.

    Returns:
        dict: A mapping of platform name to hex-encoded sha256 digest.
    """
    checksums = {}
    for platform in PLATFORMS:
        urls = [url + ".sha256" for url in kubectl_urls(version, platform)]
        output = "kubectl-{}-{}.sha256".format(version, platform)
        result = module_ctx.download(
            urls,
            output = output,
            allow_fail = True,
        )
        if not result.success:
            fail((
                "Failed to download the kubectl checksum for version `{}` ({}). " +
                "Is `{}` a published kubectl release? Tried: {}"
            ).format(version, platform, version, ", ".join(urls)))

        # The file holds the hex digest, optionally followed by a file name.
        content = module_ctx.read(output).strip()
        fields = [f for f in content.replace("\t", " ").replace("\n", " ").split(" ") if f]
        if not fields or len(fields[0]) != 64:
            fail("Unexpected content in kubectl checksum file {}: {}".format(urls[0], content))

        checksums[platform] = fields[0]

    return checksums

def _kubectl_impl(module_ctx):
    root_mod, rules_mod = _find_modules(module_ctx)

    tags = root_mod.tags.toolchain
    if not tags:
        tags = rules_mod.tags.toolchain

    # Checksums persisted in the lockfile by a previous evaluation (Bazel 8.5+).
    facts = getattr(module_ctx, "facts", {})
    used_facts = {}

    # The registered toolchains serve a single version: the one requested by the
    # root module's first `toolchain` tag.
    toolchain_version = tags[0].version if tags else DEFAULT_VERSION

    versions = {toolchain_version: None}
    for tag in tags:
        versions[tag.version] = None

    checksums_by_version = {}
    for version in versions:
        checksums = VERSIONS.get(version)
        if checksums == None:
            checksums = facts.get(version)
        if checksums == None:
            checksums = _fetch_checksums(module_ctx, version)

        if version not in VERSIONS:
            used_facts[version] = checksums

        checksums_by_version[version] = checksums

        for platform, sha256 in checksums.items():
            if platform not in PLATFORMS:
                continue

            # kubectl is published as a bare binary rather than an archive.
            http_file(
                name = _binary_repo_name(version, platform),
                urls = kubectl_urls(version, platform),
                sha256 = sha256,
                downloaded_file_path = "kubectl.exe" if platform.startswith("windows") else "kubectl",
                executable = True,
            )

    # --- Toolchain hub ---

    binaries = {}
    exec_compatible_with = {}
    for platform in checksums_by_version[toolchain_version]:
        if platform not in PLATFORMS:
            continue
        name = platform.replace("-", "_")
        binaries[name] = "@{}//file".format(_binary_repo_name(toolchain_version, platform))
        exec_compatible_with[name] = PLATFORMS[platform].constraints

    kubectl_toolchains_repository(
        name = _HUB_NAME,
        binaries = binaries,
        exec_compatible_with = exec_compatible_with,
        version = toolchain_version,
    )

    # --- Host repositories ---

    for tag in tags:
        kubectl_host_repository(
            name = tag.name,
            binary_repo_prefix = _binary_repo_name(tag.version, ""),
            version = tag.version,
        )

    kwargs = {"reproducible": True}

    # Bazel 8.5+ persists facts in the lockfile so later evaluations (and
    # airgapped builds) never re-download the checksum files.
    if hasattr(module_ctx, "facts"):
        kwargs["facts"] = used_facts

    return module_ctx.extension_metadata(**kwargs)

_toolchain = tag_class(
    doc = """\
Fetch `kubectl` and register toolchains for it.

Each tag creates a host repository (default `@kubectl`) exposing the host \
platform's binary as `@{name}//:kubectl`. That target runs `kubectl` from the \
directory `bazel run` was invoked in, so relative paths such as \
`-f ./deploy.yaml` resolve as they would for a locally installed `kubectl`.

```python
kubectl = use_extension("@rules_kubectl//kubectl:extensions.bzl", "kubectl")
kubectl.toolchain()
use_repo(kubectl, "kubectl")
```

```bash
bazel run @kubectl -- get pods --namespace my-namespace
bazel run @kubectl -- apply -f ./deploy/configmap.yaml
```

`rules_kubectl` registers the toolchains itself; the root module does not need \
a `register_toolchains` call. The registered toolchains serve the version \
requested by the root module's first `toolchain` tag (or the default when the \
root module has none).

### Versions

`rules_kubectl` ships checksums for a single default version. Requesting any \
other version makes the extension download the upstream `.sha256` files for \
that release while it is evaluated. On Bazel 8.5 and newer the digests are then \
stored as facts in `MODULE.bazel.lock`, so the lookup only happens once per \
version and airgapped builds work from the lockfile. Older Bazel versions repeat \
the lookup whenever the extension is re-evaluated.

```python
kubectl.toolchain(version = "1.36.5")
```

Several versions can live side by side by giving each tag its own repository \
name. Only the first tag in the root module decides which version the \
registered toolchains serve:

```python
kubectl.toolchain()
kubectl.toolchain(name = "kubectl_legacy", version = "1.35.6")
use_repo(kubectl, "kubectl", "kubectl_legacy")
```
""",
    attrs = {
        "name": attr.string(
            doc = "The name of the host repository.",
            default = "kubectl",
        ),
        "version": attr.string(
            doc = "The version of kubectl to fetch, without a leading `v`.",
            default = DEFAULT_VERSION,
        ),
    },
)

kubectl = module_extension(
    doc = "Module extension for fetching `kubectl`.",
    implementation = _kubectl_impl,
    tag_classes = {
        "toolchain": _toolchain,
    },
)
