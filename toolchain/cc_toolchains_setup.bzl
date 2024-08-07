load(
    "//toolchain:common.bzl",
    "BZLMOD_ENABLED",
    _canonical_dir_path = "canonical_dir_path",
    _dict_to_string = "dict_to_string",
    _download = "download",
    _generate_build_file = "generate_build_file",
    _is_absolute_path = "is_absolute_path",
    _is_hermetic_or_exists = "is_hermetic_or_exists",
    _join = "join",
    _label_to_string = "label_to_string",
    _list_to_string = "list_to_string",
    _pkg_path_from_label = "pkg_path_from_label",
)

_attrs = {
    "chip_model": attr.string(mandatory = True),
    "target_arch": attr.string(mandatory = True),
    "target_os": attr.string(mandatory = True),
    "compiler": attr.string(mandatory = True),
    "url": attr.string(mandatory = True),
    "sha256sum": attr.string(mandatory = True),
    "sysroot": attr.string(mandatory = False),
    "strip_prefix": attr.string(mandatory = False, default = ""),
    "tool_names": attr.string_dict(
        mandatory = True,
        default = {
            "ar": "",
            "ld": "",
            "llvm-cov": "",
            "gcov": "",
            "cpp": "",
            "gcc": "",
            "nm": "",
            "objcopy": "",
            "objdump": "",
            "strip": "",
        },
    ),
    "extra_compiler_files": attr.label(mandatory = False),
    "libc": attr.string(mandatory = False, default = "glibc"),
    "c_builtin_include_directories": attr.string_list(mandatory = False),
    "cxx_builtin_include_directories": attr.string_list(mandatory = False),
    "compile_flags": attr.string_list(mandatory = False),
    "conly_flags": attr.string_list(mandatory = False),
    "cxx_flags": attr.string_list(mandatory = False),
    "link_flags": attr.string_list(mandatory = False),
    "archive_flags": attr.string_list(mandatory = False),
    "link_libs": attr.string_list(mandatory = False),
    "opt_compile_flags": attr.string_list(mandatory = False),
    "opt_link_flags": attr.string_list(mandatory = False),
    "dbg_compile_flags": attr.string_list(mandatory = False),
    "dbg_link_flags": attr.string_list(mandatory = False),
    "coverage_compile_flags": attr.string_list(mandatory = False),
    "coverage_link_flags": attr.string_list(mandatory = False),
    "unfiltered_compile_flags": attr.string_list(mandatory = False),
    "supports_start_end_lib": attr.bool(mandatory = False, default = True),
    "debug": attr.bool(mandatory = False, default = False),
}

# NOTICE(not finished)
def _symlink_recursive(rctx, src, dst, offset):
    for path in rctx.path(src).readdir():
        if path != path.realpath:
            continue
        if path.is_dir():
            _symlink_recursive(rctx, path, dst, offset)
        else:
            rctx.symlink(path, path.basename)

def _cc_toolchain_repo_impl(rctx):
    rctx.file(
        "BUILD.bazel",
        content = rctx.read(Label("//toolchain:cc_toolchain_repo.BUILD.tpl")),
        executable = False,
    )
    if _is_absolute_path(rctx.attr.url):
        toolchain_dir = _canonical_dir_path(rctx.attr.url) + rctx.attr.strip_prefix
        toolchain_dir.replace("//", "/")
        for path in rctx.path(toolchain_dir).readdir():
            rctx.execute(["cp", "-r", path, "."])
        return rctx.attr

    updated_attrs = _download(rctx)
    #return updated_attrs

cc_toolchain_repo = repository_rule(
    attrs = _attrs,
    local = False,
    implementation = _cc_toolchain_repo_impl,
)

def _cc_toolchain_config_impl(rctx):
    suffix = "{}_{}_{}".format(rctx.attr.chip_model, rctx.attr.target_arch, rctx.attr.compiler)
    toolchain_repo_root = ("@" if BZLMOD_ENABLED else "") + "@cc_toolchain_repo_{}//".format(suffix)
    toolchain_path_prefix = _canonical_dir_path(str(rctx.path(Label(toolchain_repo_root + ":BUILD.bazel")).dirname))

    tool_paths = {}
    for k, v in rctx.attr.tool_names.items():
        tool_paths[k] = "\"{}bin/{}\"".format(toolchain_path_prefix, v)

    extra_compiler_files = _label_to_string(rctx.attr.extra_compiler_files) if rctx.attr.extra_compiler_files else ""
    repo_all_files_label_str = _label_to_string(Label(toolchain_repo_root + ":all_files"))

    sysroot_path = ""
    if rctx.attr.sysroot:
        if _is_absolute_path(rctx.attr.sysroot):
            sysroot_path = rctx.attr.sysroot
        else:
            sysroot_path = _canonical_dir_path(str(rctx.path(Label(rctx.attr.sysroot)).dirname))

    c_builtin_include_directories = [toolchain_path_prefix + item for item in rctx.attr.c_builtin_include_directories]
    cxx_builtin_include_directories = [toolchain_path_prefix + item for item in rctx.attr.cxx_builtin_include_directories]

    if sysroot_path != "":
        sysroot_prefix = "%sysroot%"
        c_builtin_include_directories.extend([
            _join(sysroot_prefix, "/include"),
            _join(sysroot_prefix, "/usr/include"),
            _join(sysroot_prefix, "/usr/local/include"),
        ])
        cxx_builtin_include_directories.extend([
            _join(sysroot_prefix, "/include"),
            _join(sysroot_prefix, "/usr/include"),
            _join(sysroot_prefix, "/usr/local/include"),
        ])

    c_builtin_include_directories = [
        dir
        for dir in c_builtin_include_directories
        if _is_hermetic_or_exists(rctx, dir, sysroot_path)
    ]

    cxx_builtin_include_directories = [
        dir
        for dir in cxx_builtin_include_directories
        if _is_hermetic_or_exists(rctx, dir, sysroot_path)
    ]

    compile_flags = []
    conly_flags = []
    cxx_flags = []

    #compile_flags = ["-isystem " + toolchain_path_prefix + item for item in rctx.attr.cxx_builtin_include_directories]
    for item in rctx.attr.c_builtin_include_directories:
        conly_flags.append("-isystem")
        conly_flags.append(toolchain_path_prefix + item)

    for item in rctx.attr.cxx_builtin_include_directories:
        cxx_flags.append("-isystem")
        cxx_flags.append(toolchain_path_prefix + item)

    for item in rctx.attr.c_builtin_include_directories:
        cxx_flags.append("-isystem")
        cxx_flags.append(toolchain_path_prefix + item)

    link_flags = [
        "-L{}lib".format(toolchain_path_prefix),
        "-B{}bin".format(toolchain_path_prefix),
        "-no-canonical-prefixes",
        "-Wl,--build-id=md5",
        "-Wl,--hash-style=gnu",
        "-Wl,-z,relro,-z,now",
    ]

    compiler_configuration = dict()
    if rctx.attr.compile_flags and len(rctx.attr.compile_flags) != 0:
        compile_flags.extend(rctx.attr.compile_flags)
    if rctx.attr.conly_flags and len(rctx.attr.conly_flags) != 0:
        conly_flags.extend(rctx.attr.conly_flags)
    if rctx.attr.cxx_flags and len(rctx.attr.cxx_flags) != 0:
        cxx_flags.extend(rctx.attr.cxx_flags)
    if rctx.attr.link_flags and len(rctx.attr.link_flags) != 0:
        link_flags.extend(rctx.attr.link_flags)
    if rctx.attr.archive_flags and len(rctx.attr.archive_flags) != 0:
        compiler_configuration["archive_flags"] = _list_to_string(rctx.attr.archive_flags)
    if rctx.attr.link_libs and len(rctx.attr.link_libs) != 0:
        compiler_configuration["link_libs"] = _list_to_string(rctx.attr.link_libs)
    if rctx.attr.opt_compile_flags and len(rctx.attr.opt_compile_flags) != 0:
        compiler_configuration["opt_compile_flags"] = _list_to_string(rctx.attr.opt_compile_flags)
    if rctx.attr.opt_link_flags and len(rctx.attr.opt_link_flags) != 0:
        compiler_configuration["opt_link_flags"] = _list_to_string(rctx.attr.opt_link_flags)
    if rctx.attr.dbg_compile_flags and len(rctx.attr.dbg_compile_flags) != 0:
        compiler_configuration["dbg_compile_flags"] = _list_to_string(rctx.attr.dbg_compile_flags)
    if rctx.attr.dbg_link_flags and len(rctx.attr.dbg_link_flags) != 0:
        compiler_configuration["dbg_link_flags"] = _list_to_string(rctx.attr.dbg_link_flags)
    if rctx.attr.coverage_compile_flags and len(rctx.attr.coverage_compile_flags) != 0:
        compiler_configuration["coverage_compile_flags"] = _list_to_string(rctx.attr.coverage_compile_flags)
    if rctx.attr.coverage_link_flags and len(rctx.attr.coverage_link_flags) != 0:
        compiler_configuration["coverage_link_flags"] = _list_to_string(rctx.attr.coverage_link_flags)
    if rctx.attr.unfiltered_compile_flags and len(rctx.attr.unfiltered_compile_flags) != 0:
        compiler_configuration["unfiltered_compile_flags"] = _list_to_string(rctx.attr.unfiltered_compile_flags)

    compiler_configuration["compile_flags"] = _list_to_string(compile_flags)
    compiler_configuration["conly_flags"] = _list_to_string(conly_flags)
    compiler_configuration["cxx_flags"] = _list_to_string(cxx_flags)
    compiler_configuration["link_flags"] = _list_to_string(link_flags)

    rctx.template(
        "bin/cc_wrapper.sh",
        Label("//toolchain:cc_wrapper.sh.tpl"),
        {
            "%{toolchain_path_prefix}": toolchain_path_prefix,
            "%{compiler_bin}": rctx.attr.tool_names["gcc"],
        },
    )

    rctx.template(
        "BUILD.bazel",
        Label("//toolchain:cc_toolchain_config.BUILD.tpl"),
        {
            "%{suffix}": suffix,
            "%{compiler}": rctx.attr.compiler,
            "%{target_arch}": rctx.attr.target_arch,
            "%{target_os}": rctx.attr.target_os,
            "%{libc}": rctx.attr.libc,
            "%{repo_all_files_label_str}": repo_all_files_label_str,
            "%{extra_compiler_files}": extra_compiler_files,
            "%{cxx_builtin_include_directories}": _list_to_string(cxx_builtin_include_directories),
            "%{compiler_configuration}": _dict_to_string(compiler_configuration),
            "%{tool_paths}": _dict_to_string(tool_paths),
            "%{supports_start_end_lib}": str(rctx.attr.supports_start_end_lib),
            "%{sysroot_path}": sysroot_path,
        },
    )
    if rctx.attr.debug:
        print(rctx.read("BUILD.bazel"))

cc_toolchain_config = repository_rule(
    attrs = _attrs,
    local = True,
    configure = True,
    implementation = _cc_toolchain_config_impl,
)

def cc_toolchains_setup(name, **kwargs):
    if not kwargs.get("toolchains"):
        fail("must set toolchains")
    toolchains = kwargs.get("toolchains")
    toolchain_args = dict()
    for chip_model, chip_model_info in toolchains.items():
        for target_arch, toolchain in chip_model_info.items():
            for compiler, toolchain_info in toolchain.items():
                if not toolchain_info.get("url"):
                    fail("must have url")
                if not _is_absolute_path(toolchain_info.get("url")) and not toolchain_info.get("sha256sum"):
                    fail("must have sha256sum unless url is a absolute path")

                toolchain_args["chip_model"] = chip_model  #eg. rockchip
                toolchain_args["compiler"] = compiler  #eg. clang
                toolchain_args["target_arch"] = target_arch  #eg. aarch64
                toolchain_args["url"] = toolchain_info.get("url")
                if toolchain_info.get("sha256sum"):
                    toolchain_args["sha256sum"] = toolchain_info.get("sha256sum")
                if toolchain_info.get("target_os"):
                    toolchain_args["target_os"] = toolchain_info.get("target_os")
                if toolchain_info.get("sysroot"):
                    toolchain_args["sysroot"] = toolchain_info.get("sysroot")
                if toolchain_info.get("strip_prefix"):
                    toolchain_args["strip_prefix"] = toolchain_info.get("strip_prefix")
                if toolchain_info.get("tool_names"):
                    toolchain_args["tool_names"] = toolchain_info.get("tool_names")
                if toolchain_info.get("extra_compiler_files"):
                    toolchain_args["extra_compiler_files"] = toolchain_info.get("extra_compiler_files")
                if toolchain_info.get("libc"):
                    toolchain_args["libc"] = toolchain_info.get("libc")
                if toolchain_info.get("c_builtin_include_directories"):
                    toolchain_args["c_builtin_include_directories"] = toolchain_info.get("c_builtin_include_directories")
                if toolchain_info.get("cxx_builtin_include_directories"):
                    toolchain_args["cxx_builtin_include_directories"] = toolchain_info.get("cxx_builtin_include_directories")
                if toolchain_info.get("compile_flags"):
                    toolchain_args["compile_flags"] = toolchain_info.get("compile_flags")
                if toolchain_info.get("conly_flags"):
                    toolchain_args["conly_flags"] = toolchain_info.get("conly_flags")
                if toolchain_info.get("cxx_flags"):
                    toolchain_args["cxx_flags"] = toolchain_info.get("cxx_flags")
                if toolchain_info.get("link_flags"):
                    toolchain_args["link_flags"] = toolchain_info.get("link_flags")
                if toolchain_info.get("archive_flags"):
                    toolchain_args["archive_flags"] = toolchain_info.get("archive_flags")
                if toolchain_info.get("link_libs"):
                    toolchain_args["link_libs"] = toolchain_info.get("link_libs")
                if toolchain_info.get("opt_compile_flags"):
                    toolchain_args["opt_compile_flags"] = toolchain_info.get("opt_compile_flags")
                if toolchain_info.get("opt_link_flags"):
                    toolchain_args["opt_link_flags"] = toolchain_info.get("opt_link_flags")
                if toolchain_info.get("dbg_compile_flags"):
                    toolchain_args["dbg_compile_flags"] = toolchain_info.get("dbg_compile_flags")
                if toolchain_info.get("dbg_link_flags"):
                    toolchain_args["dbg_link_flags"] = toolchain_info.get("dbg_link_flags")
                if toolchain_info.get("coverage_compile_flags"):
                    toolchain_args["coverage_compile_flags"] = toolchain_info.get("coverage_compile_flags")
                if toolchain_info.get("coverage_link_flags"):
                    toolchain_args["coverage_link_flags"] = toolchain_info.get("coverage_link_flags")
                if toolchain_info.get("unfiltered_compile_flags"):
                    toolchain_args["unfiltered_compile_flags"] = toolchain_info.get("unfiltered_compile_flags")
                if toolchain_info.get("supports_start_end_lib") != None:
                    toolchain_args["supports_start_end_lib"] = toolchain_info.get("supports_start_end_lib")
                if toolchain_info.get("debug") != None:
                    toolchain_args["debug"] = toolchain_info.get("debug")
                cc_toolchain_repo(name = "cc_toolchain_repo_{}_{}_{}".format(chip_model, target_arch, compiler), **toolchain_args)
                cc_toolchain_config(name = "cc_toolchain_config_{}_{}_{}".format(chip_model, target_arch, compiler), **toolchain_args)
