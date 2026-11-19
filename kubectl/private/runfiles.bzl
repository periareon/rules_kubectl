"""Runfiles helpers"""

def rlocationpath(file, workspace_name):
    """Return the runfiles path of `file`, as `$(rlocationpath)` would.

    Args:
        file (File): The file to locate.
        workspace_name (str): `ctx.workspace_name`.

    Returns:
        str: The path to pass to a runfiles library's `Rlocation`.
    """
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]
    return "{}/{}".format(workspace_name, file.short_path)
