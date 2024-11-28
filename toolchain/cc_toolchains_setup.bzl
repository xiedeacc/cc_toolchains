load(
    "//toolchain:common.bzl",
    "BZLMOD_ENABLED",
    _canonical_dir_path = "canonical_dir_path",
    _dict_key_to_string = "dict_key_to_string",
    _dict_to_string = "dict_to_string",
    _download = "download",
    _exists = "exists",
    _is_absolute_path = "is_absolute_path",
    _is_cross_compiling = "is_cross_compiling",
    _is_cxx_search_path = "is_cxx_search_path",
    _is_system_include_directory = "is_system_include_directory",
    _label_to_string = "label_to_string",
    _list_to_string = "list_to_string",
)

_attrs = {
    "target_arch": attr.string(mandatory = True),
    "target_os": attr.string(mandatory = True),
    "vendor": attr.string(mandatory = True),
    "libc": attr.string(mandatory = False, default = "glibc"),
    "compiler": attr.string(mandatory = True),
    "triple": attr.string(mandatory = True),
    "url": attr.string(mandatory = True),
    "strip_prefix": attr.string(mandatory = False, default = ""),
    "sha256sum": attr.string(mandatory = False, default = ""),
    "sysroot": attr.string(mandatory = False),
    "tool_names": attr.string_dict(mandatory = True),
    "extra_compiler_files": attr.label(mandatory = False),
    "cxx_builtin_include_directories": attr.string_list(mandatory = False),
    "sysroot_include_directories": attr.string_list(mandatory = False),
    "sysroot_lib_directories": attr.string_list(mandatory = False),
    "lib_directories": attr.string_list(mandatory = False),
    "compile_flags": attr.string_list(mandatory = False),
    "conly_flags": attr.string_list(mandatory = False),
    "cxx_flags": attr.string_list(mandatory = False),
    "link_flags": attr.string_list(mandatory = False),
    "archive_flags": attr.string_list(mandatory = False),
    "link_libs": attr.string_list(mandatory = False),
    "opt_compile_flags": attr.string_list(mandatory = False),
    "opt_link_flags": attr.string_list(mandatory = False),
    "dbg_compile_flags": attr.string_list(mandatory = False),
    "coverage_compile_flags": attr.string_list(mandatory = False),
    "coverage_link_flags": attr.string_list(mandatory = False),
    "unfiltered_compile_flags": attr.string_list(mandatory = False),
    "supports_start_end_lib": attr.bool(mandatory = False, default = True),
    "debug": attr.bool(mandatory = False, default = False),
}

def _cc_toolchain_repo_impl(rctx):
    content = rctx.read(Label("//toolchain:cc_toolchain_repo.BUILD.tpl"))
    if rctx.attr.tool_names.get("windres"):
        windres = rctx.attr.tool_names.get("windres")
        content += """
native_binary(
    name = "{name}",
    out = "{name}",
    src = "bin/{name}",
)
""".format(name = windres)

        content += """
select_file(
    name = "windres",
    srcs = ":all_files",
    subpath = "bin/{name}",
)
""".format(name = windres)

    rctx.file(
        "BUILD.bazel",
        content = content,
        executable = False,
    )
    if _is_absolute_path(rctx.attr.url):
        toolchain_dir = _canonical_dir_path(rctx.attr.url) + rctx.attr.strip_prefix
        for path in rctx.path(toolchain_dir).readdir():
            rctx.execute(["cp", "-r", path, "."])
        return rctx.attr

    return _download(rctx)

cc_toolchain_repo = repository_rule(
    attrs = _attrs,
    local = False,
    implementation = _cc_toolchain_repo_impl,
)

def _cc_toolchain_config_impl(rctx):
    suffix = "{}_{}_{}_{}_{}".format(rctx.attr.compiler, rctx.attr.target_arch, rctx.attr.vendor, rctx.attr.target_os, rctx.attr.libc)
    toolchain_repo_root = ("@" if BZLMOD_ENABLED else "") + "@cc_toolchain_repo_{}//".format(suffix)
    toolchain_path_prefix = _canonical_dir_path(str(rctx.path(Label(toolchain_repo_root + ":BUILD.bazel")).dirname))

    sysroot_path = ""
    if rctx.attr.sysroot and len(rctx.attr.sysroot) > 0:
        if _is_absolute_path(rctx.attr.sysroot):
            sysroot_path = _canonical_dir_path(rctx.attr.sysroot)
        else:
            sysroot_path = _canonical_dir_path(str(rctx.path(Label(rctx.attr.sysroot)).dirname))

    if sysroot_path == "":
        fail("sysroot_path empty, set sysroot if cross compiling, else set to toolchain root")

    compile_flags = [
        "-B{}bin".format(toolchain_path_prefix),
        "-U_FORTIFY_SOURCE",  # https://github.com/google/sanitizers/issues/247
        "-fstack-protector",
        "-fno-omit-frame-pointer",
        "-Wall",
        #"-v",
    ]
    dbg_compile_flags = [
        "-g",
        "-fstack-protector",
        "-fstandalone-debug",
        "-fno-omit-frame-pointer",
        "-Wall",
    ]
    opt_compile_flags = [
        "-g0",
        "-O2",
        "-D_FORTIFY_SOURCE=1",
        "-DNDEBUG",
        "-ffunction-sections",
        "-fdata-sections",
    ]
    conly_flags = []
    cxx_flags = ["-std=c++17"]
    link_flags = [
        #"-v",
        "-B{}bin".format(toolchain_path_prefix),
    ]

    compile_flags.append("-nostdinc")
    conly_flags.append("-nostdinc")
    cxx_flags.append("-nostdinc")
    cxx_flags.append("-nostdinc++")
    if rctx.attr.compiler != "gcc":
        link_flags.append("-nostdlib")

    if rctx.attr.compiler == "clang":
        if rctx.attr.target_os == "linux":
            link_flags.append("-fuse-ld=lld")
    elif rctx.attr.compiler == "gcc":
        link_flags.append("-fuse-ld=lld")

    archive_flags = []
    opt_link_flags = []
    coverage_compile_flags = ["--coverage"]
    coverage_link_flags = ["--coverage"]

    if rctx.attr.target_os != "osx" and rctx.attr.target_os != "windows":
        link_flags.extend([
            "-Wl,--build-id=md5",
            "-Wl,--hash-style=gnu",
            "-Wl,-z,relro,-z,now",
            "-Wl,-no-as-needed",
        ])
        opt_link_flags.append("-Wl,--gc-sections")

    unfiltered_compile_flags = [
        "-no-canonical-prefixes",
        "-Wno-builtin-macro-redefined",
        "-D__DATE__=redacted",
        "-D__TIMESTAMP__=redacted",
        "-D__TIME__=redacted",
    ]

    system_include_directories = {}
    c_builtin_include_directories = {}
    cxx_builtin_include_directories = {}
    for item in rctx.attr.cxx_builtin_include_directories:
        if _is_absolute_path(item):
            if _is_system_include_directory(rctx, item, rctx.attr.triple):
                system_include_directories[item] = True
                continue
            c_builtin_include_directories[item] = True
            cxx_builtin_include_directories[item] = True
        else:
            if _is_system_include_directory(rctx, item, rctx.attr.triple):
                system_include_directories[toolchain_path_prefix + item] = True
                continue
            if not _is_cxx_search_path(item):
                c_builtin_include_directories[toolchain_path_prefix + item] = True
            cxx_builtin_include_directories[toolchain_path_prefix + item] = True

    for item in rctx.attr.sysroot_include_directories:
        if _is_absolute_path(item):
            if _is_system_include_directory(rctx, item, rctx.attr.triple):
                system_include_directories[item] = True
                continue
            c_builtin_include_directories[item] = True
            cxx_builtin_include_directories[item] = True
        else:
            if _is_system_include_directory(rctx, item, rctx.attr.triple):
                system_include_directories[sysroot_path + item] = True
                continue
            if not _is_cxx_search_path(item):
                c_builtin_include_directories[sysroot_path + item] = True
            cxx_builtin_include_directories[sysroot_path + item] = True

    # Filter out non-existing directories but keep as dictionaries
    system_include_directories = {dir: True for dir in system_include_directories.keys() if _exists(rctx, dir)}
    c_builtin_include_directories = {dir: True for dir in c_builtin_include_directories.keys() if _exists(rctx, dir)}
    cxx_builtin_include_directories = {dir: True for dir in cxx_builtin_include_directories.keys() if _exists(rctx, dir)}

    for item in c_builtin_include_directories.keys():
        conly_flags.append("-isystem")
        conly_flags.append(item)
        compile_flags.append("-idirafter")
        compile_flags.append(item)

    for item in cxx_builtin_include_directories.keys():
        cxx_flags.append("-isystem")
        cxx_flags.append(item)
    for item in system_include_directories.keys():
        compile_flags.append("-idirafter")
        compile_flags.append(item)

    cxx_builtin_include_directories.update(c_builtin_include_directories)
    cxx_builtin_include_directories.update(system_include_directories)
    cxx_builtin_include_directories = [dir for dir in cxx_builtin_include_directories.keys()]

    lib_directories = []
    for item in rctx.attr.lib_directories:
        if _is_absolute_path(item):
            lib_directories.append(item)
        else:
            lib_directories.append(toolchain_path_prefix + item)
    for item in rctx.attr.sysroot_lib_directories:
        if _is_absolute_path(item):
            lib_directories.append(item)
        else:
            lib_directories.append(sysroot_path + item)

    lib_directories = [_canonical_dir_path(dir) for dir in lib_directories]
    lib_directories = [dir for dir in lib_directories if _exists(rctx, dir)]
    for item in lib_directories:
        link_flags.append("-L{}".format(item))
        if not _is_cross_compiling(rctx):
            link_flags.append("-Wl,-rpath,{}".format(item))

    link_flags.append("-B{}lib".format(sysroot_path))
    link_flags.append("-B{}usr/lib".format(sysroot_path))

    link_libs = []
    for item in rctx.attr.link_libs:
        if _is_absolute_path(item):
            if _exists(rctx, item):
                link_libs.append(item)
        else:
            for dir in lib_directories:
                if _exists(rctx, dir + item):
                    link_libs.append(dir + item)
                    break

    for item in link_libs:
        if rctx.attr.supports_start_end_lib:
            link_flags.append("-Wl,--push-state,-as-needed")
        link_flags.append(item)
        if rctx.attr.supports_start_end_lib:
            link_flags.append("-Wl,--pop-state")
    link_libs = []

    if rctx.attr.supports_start_end_lib:
        link_flags.append("-Wl,--push-state,-as-needed")

    if rctx.attr.compiler == "clang":
        compile_flags.append("--target={}".format(rctx.attr.triple))
        link_flags.append("--target={}".format(rctx.attr.triple))
        if rctx.attr.target_os == "osx":
            link_flags.append("{}lib/darwin/libc++.a".format(toolchain_path_prefix))
            link_flags.append("{}lib/darwin/libc++abi.a".format(toolchain_path_prefix))
            link_flags.append("{}lib/darwin/libunwind.a".format(toolchain_path_prefix))
        elif rctx.attr.target_os == "linux":
            link_flags.append("{}lib/{}/libc++.a".format(toolchain_path_prefix, rctx.attr.triple))
            link_flags.append("{}lib/{}/libc++abi.a".format(toolchain_path_prefix, rctx.attr.triple))
            link_flags.append("{}lib/{}/libunwind.a".format(toolchain_path_prefix, rctx.attr.triple))
    elif rctx.attr.compiler == "gcc":
        link_flags.append("{}lib/libstdc++.a".format(sysroot_path))
        link_flags.append("{}lib/libstdc++fs.a".format(sysroot_path))

    if rctx.attr.supports_start_end_lib:
        link_flags.append("-Wl,--pop-state")

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
        archive_flags.extend(rctx.attr.archive_flags)

    if rctx.attr.opt_compile_flags and len(rctx.attr.opt_compile_flags) != 0:
        opt_compile_flags.extend(compiler_configuration["opt_compile_flags"])

    if rctx.attr.opt_link_flags and len(rctx.attr.opt_link_flags) != 0:
        opt_link_flags.extend(compiler_configuration["opt_link_flags"])

    if rctx.attr.dbg_compile_flags and len(rctx.attr.dbg_compile_flags) != 0:
        dbg_compile_flags.extend(compiler_configuration["dbg_compile_flags"])

    if rctx.attr.coverage_compile_flags and len(rctx.attr.coverage_compile_flags) != 0:
        coverage_compile_flags.extend(compiler_configuration["coverage_compile_flags"])

    if rctx.attr.coverage_link_flags and len(rctx.attr.coverage_link_flags) != 0:
        coverage_link_flags.extend(compiler_configuration["coverage_link_flags"])

    if rctx.attr.unfiltered_compile_flags and len(rctx.attr.unfiltered_compile_flags) != 0:
        unfiltered_compile_flags.extend(compiler_configuration["unfiltered_compile_flags"])

    compiler_configuration["compile_flags"] = _list_to_string(compile_flags)
    compiler_configuration["dbg_compile_flags"] = _list_to_string(dbg_compile_flags)
    compiler_configuration["opt_compile_flags"] = _list_to_string(opt_compile_flags)
    compiler_configuration["conly_flags"] = _list_to_string(conly_flags)
    compiler_configuration["cxx_flags"] = _list_to_string(cxx_flags)
    compiler_configuration["link_flags"] = _list_to_string(link_flags)
    compiler_configuration["archive_flags"] = _list_to_string(archive_flags)
    compiler_configuration["link_libs"] = _list_to_string(link_libs)
    compiler_configuration["opt_link_flags"] = _list_to_string(opt_link_flags)
    compiler_configuration["coverage_compile_flags"] = _list_to_string(coverage_compile_flags)
    compiler_configuration["coverage_link_flags"] = _list_to_string(coverage_link_flags)
    compiler_configuration["unfiltered_compile_flags"] = _list_to_string(unfiltered_compile_flags)

    rctx.template(
        "bin/cc_wrapper.sh",
        Label("//toolchain:cc_wrapper.sh.tpl"),
        {
            "%{toolchain_path_prefix}": toolchain_path_prefix,
            "%{compiler_bin}": rctx.attr.tool_names["gcc"],
        },
    )

    tool_paths = {}
    for k, v in rctx.attr.tool_names.items():
        tool_paths[k] = "\"{}bin/{}\"".format(toolchain_path_prefix, v)

    extra_compiler_files = _label_to_string(rctx.attr.extra_compiler_files) if rctx.attr.extra_compiler_files else ""
    repo_all_files_label_str = _label_to_string(Label(toolchain_repo_root + ":all_files"))

    windres_path = "\"\""
    if rctx.attr.tool_names.get("windres"):
        windres_name = rctx.attr.tool_names.get("windres")
        windres_path = "\"{}bin/{}\"".format(toolchain_path_prefix, windres_name)

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
            "%{windres_path}": windres_path,
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
    """Sets up C/C++ toolchains for cross-compilation.

    Args:
        name: The name of the toolchain setup.
        **kwargs: Must contain a "toolchains" dictionary mapping target architectures
            to their respective toolchain configurations.
    """
    if not kwargs.get("toolchains"):
        fail("must set toolchains")
    toolchains = kwargs.get("toolchains")
    toolchain_args = dict()
    for target_arch, target_arch_info in toolchains.items():
        for target_os, target_os_infos in target_arch_info.items():
            for target_toolchain_info in target_os_infos:
                toolchain_args = {}
                if not target_toolchain_info.get("url"):
                    fail("must have url")
                if not _is_absolute_path(target_toolchain_info.get("url")) and not target_toolchain_info.get("sha256sum"):
                    fail("must have sha256sum unless url is a absolute path")

                toolchain_args["target_arch"] = target_arch  #eg. aarch64
                toolchain_args["target_os"] = target_os
                toolchain_args["vendor"] = target_toolchain_info.get("vendor")  #eg. pc
                toolchain_args["libc"] = target_toolchain_info.get("libc")
                toolchain_args["compiler"] = target_toolchain_info.get("compiler")  #eg. clang
                toolchain_args["triple"] = target_toolchain_info.get("triple")  #eg. x86_64-linux-gnu
                toolchain_args["url"] = target_toolchain_info.get("url")

                if target_toolchain_info.get("strip_prefix"):
                    toolchain_args["strip_prefix"] = target_toolchain_info.get("strip_prefix")

                if target_toolchain_info.get("sha256sum"):
                    toolchain_args["sha256sum"] = target_toolchain_info.get("sha256sum")

                if target_toolchain_info.get("sysroot"):
                    toolchain_args["sysroot"] = target_toolchain_info.get("sysroot")

                toolchain_args["tool_names"] = target_toolchain_info.get("tool_names")

                if target_toolchain_info.get("extra_compiler_files"):
                    toolchain_args["extra_compiler_files"] = target_toolchain_info.get("extra_compiler_files")

                if target_toolchain_info.get("cxx_builtin_include_directories"):
                    toolchain_args["cxx_builtin_include_directories"] = target_toolchain_info.get("cxx_builtin_include_directories")

                if target_toolchain_info.get("sysroot_include_directories"):
                    toolchain_args["sysroot_include_directories"] = target_toolchain_info.get("sysroot_include_directories")

                if target_toolchain_info.get("sysroot_lib_directories"):
                    toolchain_args["sysroot_lib_directories"] = target_toolchain_info.get("sysroot_lib_directories")

                if target_toolchain_info.get("lib_directories"):
                    toolchain_args["lib_directories"] = target_toolchain_info.get("lib_directories")

                if target_toolchain_info.get("compile_flags"):
                    toolchain_args["compile_flags"] = target_toolchain_info.get("compile_flags")

                if target_toolchain_info.get("conly_flags"):
                    toolchain_args["conly_flags"] = target_toolchain_info.get("conly_flags")

                if target_toolchain_info.get("cxx_flags"):
                    toolchain_args["cxx_flags"] = target_toolchain_info.get("cxx_flags")

                if target_toolchain_info.get("link_flags"):
                    toolchain_args["link_flags"] = target_toolchain_info.get("link_flags")

                if target_toolchain_info.get("archive_flags"):
                    toolchain_args["archive_flags"] = target_toolchain_info.get("archive_flags")

                if target_toolchain_info.get("link_libs"):
                    toolchain_args["link_libs"] = target_toolchain_info.get("link_libs")

                if target_toolchain_info.get("opt_compile_flags"):
                    toolchain_args["opt_compile_flags"] = target_toolchain_info.get("opt_compile_flags")

                if target_toolchain_info.get("opt_link_flags"):
                    toolchain_args["opt_link_flags"] = target_toolchain_info.get("opt_link_flags")

                if target_toolchain_info.get("dbg_compile_flags"):
                    toolchain_args["dbg_compile_flags"] = target_toolchain_info.get("dbg_compile_flags")

                if target_toolchain_info.get("coverage_compile_flags"):
                    toolchain_args["coverage_compile_flags"] = target_toolchain_info.get("coverage_compile_flags")

                if target_toolchain_info.get("coverage_link_flags"):
                    toolchain_args["coverage_link_flags"] = target_toolchain_info.get("coverage_link_flags")

                if target_toolchain_info.get("unfiltered_compile_flags"):
                    toolchain_args["unfiltered_compile_flags"] = target_toolchain_info.get("unfiltered_compile_flags")

                if target_toolchain_info.get("supports_start_end_lib") != None:
                    toolchain_args["supports_start_end_lib"] = target_toolchain_info.get("supports_start_end_lib")

                if target_toolchain_info.get("debug") != None:
                    toolchain_args["debug"] = target_toolchain_info.get("debug")

                cc_toolchain_repo(name = "cc_toolchain_repo_{}_{}_{}_{}_{}".format(toolchain_args["compiler"], target_arch, toolchain_args["vendor"], target_os, toolchain_args["libc"]), **toolchain_args)
                cc_toolchain_config(name = "cc_toolchain_config_{}_{}_{}_{}_{}".format(toolchain_args["compiler"], target_arch, toolchain_args["vendor"], target_os, toolchain_args["libc"]), **toolchain_args)
