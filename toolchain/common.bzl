load("@bazel_skylib//lib:paths.bzl", "paths")

BZLMOD_ENABLED = "@@" in str(Label("//:unused"))

def _print_repo_name_impl(ctx):
    repo_name = ctx.label.repository
    print("Repository name:", repo_name)

print_repo_name = rule(
    implementation = _print_repo_name_impl,
)

def generate_build_file(rctx):
    build_contents = """
load("@toolchains_openwrt//toolchain:common.bzl", "print_repo_name")
package(default_visibility = ["//visibility:public"])

print_repo_name(
    name = "print_repo_name_target",
)
"""
    rctx.file("BUILD", build_contents)

def is_absolute_path(path):
    return path and path[0] == "/" and (len(path) == 1 or path[1] != "/")

def canonical_dir_path(path):
    if not path.endswith("/"):
        return path + "/"
    return path

def pkg_path_from_label(label):
    if label.workspace_root:
        return label.workspace_root + "/" + label.package
    else:
        return label.package

def os(rctx):
    name = rctx.os.name
    if name == "linux":
        return "linux"
    elif name == "mac os x":
        return "darwin"
    elif name.startswith("windows"):
        return "windows"
    fail("Unsupported OS: " + name)

def arch(rctx):
    arch = rctx.os.arch
    if arch == "arm64":
        return "aarch64"
    if arch == "amd64":
        return "x86_64"
    return arch

def join(path1, path2):
    if path1:
        return paths.join(path1, path2.lstrip("/"))
    else:
        return path2

def os_bzl(os):
    return {"darwin": "osx", "linux": "linux"}[os]

def label_to_string(l):
    if l == None or len(str(l)) == 0:
        return ""
    return "\"{}\",".format(str(l))

def list_to_string(ls):
    if ls == None:
        return "None"
    return "[{}]".format(", ".join(["\"{}\"".format(d) for d in ls]))

def dict_to_string(d):
    if d == None:
        return "None"
    parts = []
    for key, value in d.items():
        parts.append("\"{}\": {}".format(key, value))
    return "{%s}" % ", ".join(parts)

def is_cxx_search_path(path):
    if "/c++/" in path:
        return True
    else:
        return False

def is_cross_compiling(rctx):
    if rctx.os.arch == rctx.attr.target_arch or (rctx.os.arch == "amd64" and rctx.attr.target_arch == "x86_64"):
        return False
    return True

def is_host_search_path(item):
    if item == "/usr/include" or item == "/usr/include/x86_64-linux-gnu" or item == "/usr/local/include" or item == "/usr/local/include/x86_64-linux-gnu":
        return True
    return False

def is_hermetic_or_exists(rctx, path, sysroot_path):
    path = path.replace("%sysroot%", sysroot_path).replace("//", "/")
    if not path.startswith("/"):
        return True
    return rctx.path(path).exists

def download(rctx):
    urls = [rctx.attr.url]
    res = rctx.download_and_extract(
        urls,
        sha256 = rctx.attr.sha256sum,
        stripPrefix = rctx.attr.strip_prefix,
    )
    if rctx.attr.sha256sum != res.sha256:
        fail("need sha256sum:{}, but get:{}".format(rctx.attr.sha256sum, res.sha256))
    print(res.sha256)
    return rctx.attr
