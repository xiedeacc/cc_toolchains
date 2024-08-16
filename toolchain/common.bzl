load("@bazel_skylib//lib:paths.bzl", "paths")

BZLMOD_ENABLED = "@@" in str(Label("//:unused"))

def is_absolute_path(path):
    return path and path[0] == "/" and (len(path) == 1 or path[1] != "/")

def canonical_dir_path(path):
    if not path.endswith("/"):
        return path + "/"
    return path

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
    if rctx.os.name == rctx.attr.target_os and (rctx.os.arch == rctx.attr.target_arch or (rctx.os.arch == "amd64" and rctx.attr.target_arch == "x86_64")):
        return False
    return True

def is_system_include_directory(rctx, item, triple):
    triple_search_path = "usr/include/{}".format(triple)
    if rctx.attr.target_os == "osx" and "System/Library/Frameworks" in item:
        return True
    if "usr/include" in item or triple_search_path in item:
        return True

    return False

def exists(rctx, path):
    if not path.startswith("/"):
        return False
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
    return rctx.attr
