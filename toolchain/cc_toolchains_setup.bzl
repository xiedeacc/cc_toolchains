load(
    "//toolchain:common.bzl",
    "BZLMOD_ENABLED",
    _canonical_dir_path = "canonical_dir_path",
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
    "target_distro": attr.string(mandatory = True),
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
    rctx.file(
        "BUILD.bazel",
        content = rctx.read(Label("//toolchain:cc_toolchain_repo.BUILD.tpl")),
        executable = False,
    )
    if _is_absolute_path(rctx.attr.url):
        toolchain_dir = _canonical_dir_path(rctx.attr.url) + rctx.attr.strip_prefix
        for path in rctx.path(toolchain_dir).readdir():
            rctx.execute(["cp", "-r", path, "."])
        return rctx.attr

    updated_attrs = _download(rctx)

cc_toolchain_repo = repository_rule(
    attrs = _attrs,
    local = False,
    implementation = _cc_toolchain_repo_impl,
)

def _cc_toolchain_config_impl(rctx):
    suffix = "{}_{}_{}_{}_{}".format(rctx.attr.target_arch, rctx.attr.target_os, rctx.attr.target_distro, rctx.attr.libc, rctx.attr.compiler)
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
    if _is_cross_compiling(rctx):
        compile_flags.append("-nostdinc")
        conly_flags.append("-nostdinc")
        cxx_flags.append("-nostdinc")
        cxx_flags.append("-nostdinc++")
        link_flags.append("-nostdlib")

    if rctx.attr.target_os != "osx":
        link_flags.append("-fuse-ld=lld")
    if rctx.attr.target_os != "windows":
        link_flags.append("-lc")
        link_flags.append("-lm")

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

    system_include_directories = []
    c_builtin_include_directories = []
    cxx_builtin_include_directories = []
    for item in rctx.attr.cxx_builtin_include_directories:
        if _is_absolute_path(item):
            if _is_system_include_directory(rctx, item, rctx.attr.triple):
                system_include_directories.append(item)
                continue
            c_builtin_include_directories.append(item)
            cxx_builtin_include_directories.append(item)
        else:
            if _is_system_include_directory(rctx, item, rctx.attr.triple):
                system_include_directories.append(toolchain_path_prefix + item)
                continue
            if not _is_cxx_search_path(item):
                c_builtin_include_directories.append(toolchain_path_prefix + item)
            cxx_builtin_include_directories.append(toolchain_path_prefix + item)

    for item in rctx.attr.sysroot_include_directories:
        if _is_absolute_path(item):
            if _is_system_include_directory(rctx, item, rctx.attr.triple):
                system_include_directories.append(item)
                continue
            c_builtin_include_directories.append(item)
            cxx_builtin_include_directories.append(item)
        else:
            if _is_system_include_directory(rctx, item, rctx.attr.triple):
                system_include_directories.append(sysroot_path + item)
                continue
            if not _is_cxx_search_path(item):
                c_builtin_include_directories.append(sysroot_path + item)
            cxx_builtin_include_directories.append(sysroot_path + item)

    system_include_directories = [dir for dir in system_include_directories if _exists(rctx, dir)]
    c_builtin_include_directories = [dir for dir in c_builtin_include_directories if _exists(rctx, dir)]
    cxx_builtin_include_directories = [dir for dir in cxx_builtin_include_directories if _exists(rctx, dir)]

    for item in c_builtin_include_directories:
        conly_flags.append("-isystem")
        conly_flags.append(item)
        compile_flags.append("-idirafter")
        compile_flags.append(item)

    for item in cxx_builtin_include_directories:
        cxx_flags.append("-isystem")
        cxx_flags.append(item)
    for item in system_include_directories:
        compile_flags.append("-idirafter")
        compile_flags.append(item)

    cxx_builtin_include_directories.extend(c_builtin_include_directories)
    cxx_builtin_include_directories.extend(system_include_directories)

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

    link_libs = []
    for item in rctx.attr.link_libs:
        if _is_absolute_path(item):
            if _exists(rctx, item):
                link_libs.append(item)
        else:
            for dir in lib_directories:
                if _exists(rctx, dir + item):
                    link_libs.append(dir + item)
    for item in link_libs:
        if rctx.attr.supports_start_end_lib:
            link_flags.append("-Wl,--push-state,-as-needed")
        link_flags.append(item)
        if rctx.attr.supports_start_end_lib:
            link_flags.append("-Wl,--pop-state")
    link_libs = []

    if rctx.attr.compiler == "clang":
        link_flags.append("-rtlib=compiler-rt")
        link_flags.append("-stdlib=libc++")
        if rctx.attr.supports_start_end_lib:
            link_flags.append("-Wl,--push-state,-as-needed")
        link_flags.append("-lc++")
        link_flags.append("-lc++abi")
        link_flags.append("-lunwind")
        if rctx.attr.supports_start_end_lib:
            link_flags.append("-Wl,--pop-state")

        if _is_cross_compiling(rctx):
            compile_flags.append("--target={}".format(rctx.attr.triple))
            link_flags.append("--target={}".format(rctx.attr.triple))
    elif rctx.attr.compiler == "gcc":
        if rctx.attr.supports_start_end_lib:
            link_flags.append("-Wl,--push-state,-as-needed")
        link_flags.append("-lstdc++")
        link_flags.append("-lstdc++fs")
        if rctx.attr.supports_start_end_lib:
            link_flags.append("-Wl,--pop-state")

    if not _is_cross_compiling(rctx):
        link_flags.append("-B/usr/lib/x86_64-linux-gnu")
        sysroot_path = ""

    #if _is_cross_compiling(rctx) and rctx.attr.target_os == "windows":
    #link_flags.append("-B{}usr/x86_64-w64-mingw32/lib".format(sysroot_path))

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
    for target_arch, target_arch_info in toolchains.items():
        for target_os, target_os_infos in target_arch_info.items():
            for target_distro_info in target_os_infos:
                toolchain_args = {}
                if not target_distro_info.get("url"):
                    fail("must have url")
                if not _is_absolute_path(target_distro_info.get("url")) and not target_distro_info.get("sha256sum"):
                    fail("must have sha256sum unless url is a absolute path")

                toolchain_args["target_arch"] = target_arch  #eg. aarch64
                toolchain_args["target_os"] = target_os
                toolchain_args["target_distro"] = target_distro_info.get("distro")  #eg. openwrt
                toolchain_args["libc"] = target_distro_info.get("libc")
                toolchain_args["compiler"] = target_distro_info.get("compiler")  #eg. clang
                toolchain_args["triple"] = target_distro_info.get("triple")  #eg. x86_64-linux-gnu
                toolchain_args["url"] = target_distro_info.get("url")

                if target_distro_info.get("strip_prefix"):
                    toolchain_args["strip_prefix"] = target_distro_info.get("strip_prefix")

                if target_distro_info.get("sha256sum"):
                    toolchain_args["sha256sum"] = target_distro_info.get("sha256sum")

                if target_distro_info.get("sysroot"):
                    toolchain_args["sysroot"] = target_distro_info.get("sysroot")

                toolchain_args["tool_names"] = target_distro_info.get("tool_names")

                if target_distro_info.get("extra_compiler_files"):
                    toolchain_args["extra_compiler_files"] = target_distro_info.get("extra_compiler_files")

                if target_distro_info.get("cxx_builtin_include_directories"):
                    toolchain_args["cxx_builtin_include_directories"] = target_distro_info.get("cxx_builtin_include_directories")

                if target_distro_info.get("sysroot_include_directories"):
                    toolchain_args["sysroot_include_directories"] = target_distro_info.get("sysroot_include_directories")

                if target_distro_info.get("sysroot_lib_directories"):
                    toolchain_args["sysroot_lib_directories"] = target_distro_info.get("sysroot_lib_directories")

                if target_distro_info.get("lib_directories"):
                    toolchain_args["lib_directories"] = target_distro_info.get("lib_directories")

                if target_distro_info.get("compile_flags"):
                    toolchain_args["compile_flags"] = target_distro_info.get("compile_flags")

                if target_distro_info.get("conly_flags"):
                    toolchain_args["conly_flags"] = target_distro_info.get("conly_flags")

                if target_distro_info.get("cxx_flags"):
                    toolchain_args["cxx_flags"] = target_distro_info.get("cxx_flags")

                if target_distro_info.get("link_flags"):
                    toolchain_args["link_flags"] = target_distro_info.get("link_flags")

                if target_distro_info.get("archive_flags"):
                    toolchain_args["archive_flags"] = target_distro_info.get("archive_flags")

                if target_distro_info.get("link_libs"):
                    toolchain_args["link_libs"] = target_distro_info.get("link_libs")

                if target_distro_info.get("opt_compile_flags"):
                    toolchain_args["opt_compile_flags"] = target_distro_info.get("opt_compile_flags")

                if target_distro_info.get("opt_link_flags"):
                    toolchain_args["opt_link_flags"] = target_distro_info.get("opt_link_flags")

                if target_distro_info.get("dbg_compile_flags"):
                    toolchain_args["dbg_compile_flags"] = target_distro_info.get("dbg_compile_flags")

                if target_distro_info.get("coverage_compile_flags"):
                    toolchain_args["coverage_compile_flags"] = target_distro_info.get("coverage_compile_flags")

                if target_distro_info.get("coverage_link_flags"):
                    toolchain_args["coverage_link_flags"] = target_distro_info.get("coverage_link_flags")

                if target_distro_info.get("unfiltered_compile_flags"):
                    toolchain_args["unfiltered_compile_flags"] = target_distro_info.get("unfiltered_compile_flags")

                if target_distro_info.get("supports_start_end_lib") != None:
                    toolchain_args["supports_start_end_lib"] = target_distro_info.get("supports_start_end_lib")

                if target_distro_info.get("debug") != None:
                    toolchain_args["debug"] = target_distro_info.get("debug")

                cc_toolchain_repo(name = "cc_toolchain_repo_{}_{}_{}_{}_{}".format(target_arch, target_os, toolchain_args["target_distro"], toolchain_args["libc"], toolchain_args["compiler"]), **toolchain_args)
                cc_toolchain_config(name = "cc_toolchain_config_{}_{}_{}_{}_{}".format(target_arch, target_os, toolchain_args["target_distro"], toolchain_args["libc"], toolchain_args["compiler"]), **toolchain_args)
