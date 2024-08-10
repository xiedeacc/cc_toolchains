load("@bazel_tools//tools/cpp:unix_cc_toolchain_config.bzl", unix_cc_toolchain_config = "cc_toolchain_config")

def cc_toolchain_config(
        name,
        compiler,
        toolchain_identifier,
        target_arch,
        target_os,
        libc,
        cxx_builtin_include_directories,
        tool_paths,
        compiler_configuration,
        supports_start_end_lib,
        sysroot_path):
    compile_flags = [
        "-U_FORTIFY_SOURCE",  # https://github.com/google/sanitizers/issues/247
        "-fstack-protector",
        "-fno-omit-frame-pointer",
        "-Wall",
        "-v",
        "-nostdinc",
        #"-nostdlib",
        #"-nodefaultlibs",
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
    conly_flags = [
        #"-nostdinc",
    ]

    #cxx_flags = ["-std=c++17"]
    cxx_flags = ["-std=c++17"]

    link_flags = [
        #"-nostdlib",
        #"-nodefaultlibs",
    ]
    archive_flags = []
    link_libs = []

    opt_link_flags = ["-Wl,--gc-sections"]
    unfiltered_compile_flags = [
        "-no-canonical-prefixes",
        "-Wno-builtin-macro-redefined",
        "-D__DATE__=\"redacted\"",
        "-D__TIMESTAMP__=\"redacted\"",
        "-D__TIME__=\"redacted\"",
    ]
    coverage_compile_flags = ["-fprofile-instr-generate", "-fcoverage-mapping"]
    coverage_link_flags = ["-fprofile-instr-generate"]

    if compiler_configuration.get("compile_flags") != None and len(compiler_configuration.get("compile_flags")) != 0:
        compile_flags.extend(compiler_configuration["compile_flags"])

    if compiler_configuration.get("dbg_compile_flags") != None and len(compiler_configuration.get("dbg_compile_flags")) != 0:
        dbg_compile_flags.extend(compiler_configuration["dbg_compile_flags"])

    if compiler_configuration.get("opt_compile_flags") != None and len(compiler_configuration.get("opt_compile_flags")) != 0:
        opt_compile_flags.extend(compiler_configuration["opt_compile_flags"])

    if compiler_configuration.get("conly_flags") != None and len(compiler_configuration.get("conly_flags")) != 0:
        conly_flags.extend(compiler_configuration["conly_flags"])

    if compiler_configuration.get("cxx_flags") != None and len(compiler_configuration.get("cxx_flags")) != 0:
        cxx_flags.extend(compiler_configuration["cxx_flags"])

    if compiler_configuration.get("link_flags") != None and len(compiler_configuration.get("link_flags")) != 0:
        link_flags.extend(compiler_configuration["link_flags"])

    if compiler_configuration.get("archive_flags") != None and len(compiler_configuration.get("archive_flags")) != 0:
        archive_flags.extend(compiler_configuration["archive_flags"])

    if compiler_configuration.get("link_libs") != None and len(compiler_configuration.get("link_libs")) != 0:
        link_libs.extend(compiler_configuration["link_libs"])

    if compiler_configuration.get("opt_link_flags") != None and len(compiler_configuration.get("opt_link_flags")) != 0:
        opt_link_flags.extend(compiler_configuration["opt_link_flags"])

    if compiler_configuration.get("coverage_compile_flags") != None and len(compiler_configuration.get("coverage_compile_flags")) != 0:
        coverage_compile_flags.extend(compiler_configuration["coverage_compile_flags"])

    if compiler_configuration.get("coverage_link_flags") != None and len(compiler_configuration.get("coverage_link_flags")) != 0:
        coverage_link_flags.extend(compiler_configuration["coverage_link_flags"])

    if compiler_configuration.get("unfiltered_compile_flags") != None and len(compiler_configuration.get("unfiltered_compile_flags")) != 0:
        unfiltered_compile_flags.extend(compiler_configuration["unfiltered_compile_flags"])

    unix_cc_toolchain_config(
        name = name,
        cpu = target_arch,
        compiler = compiler,
        toolchain_identifier = toolchain_identifier,
        host_system_name = "local",
        target_system_name = "{}-{}".format(target_arch, target_os),
        target_libc = libc,
        abi_version = compiler,
        abi_libc_version = libc,
        cxx_builtin_include_directories = cxx_builtin_include_directories,
        tool_paths = tool_paths,
        compile_flags = compile_flags,
        dbg_compile_flags = dbg_compile_flags,
        opt_compile_flags = opt_compile_flags,
        conly_flags = conly_flags,
        cxx_flags = cxx_flags,
        link_flags = link_flags,
        archive_flags = archive_flags,
        link_libs = link_libs,
        opt_link_flags = opt_link_flags,
        unfiltered_compile_flags = unfiltered_compile_flags,
        coverage_compile_flags = coverage_compile_flags,
        coverage_link_flags = coverage_link_flags,
        supports_start_end_lib = supports_start_end_lib,
        builtin_sysroot = sysroot_path,
    )
