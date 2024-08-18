# CC toolchain for %{suffix}.
package(default_visibility = ["//visibility:public"])

load("@bazel_skylib//rules:native_binary.bzl", "native_binary")
load("@rules_cc//cc:defs.bzl", "cc_toolchain", "cc_toolchain_suite")
load("@cc_toolchains//toolchain:system_module_map.bzl", "system_module_map")
load("@cc_toolchains//toolchain:cc_toolchain_config.bzl", "cc_toolchain_config")

filegroup(name = "empty")

filegroup(
    name = "cc_wrapper",
    srcs = ["bin/cc_wrapper.sh"],
)

filegroup(
    name = "all-files-%{suffix}",
    srcs = [
        "bin/cc_wrapper.sh",
        %{repo_all_files_label_str}
        %{extra_compiler_files}
    ],
)

filegroup(
    name = "archiver-files-%{suffix}",
    srcs = [
        "bin/cc_wrapper.sh",
    ],
)

filegroup(
    name = "assembler-files-%{suffix}",
    srcs = [
        "bin/cc_wrapper.sh",
    ],
)

filegroup(
    name = "compiler-files-%{suffix}",
    srcs = [
        "bin/cc_wrapper.sh",
        %{repo_all_files_label_str}
    ],
)

filegroup(
    name = "linker-files-%{suffix}",
    srcs = [
        "bin/cc_wrapper.sh",
    ],
)

filegroup(
    name = "objcopy-files-%{suffix}",
    srcs = [
        "bin/cc_wrapper.sh",
    ],
)

filegroup(
    name = "strip-files-%{suffix}",
    srcs = [
        "bin/cc_wrapper.sh",
    ],
)

filegroup(
    name = "include-components-%{suffix}",
    srcs = [
        ":compiler-files-%{suffix}",
    ],
)

system_module_map(
    name = "modulemap-%{suffix}",
    cxx_builtin_include_files = ":include-components-%{suffix}",
    cxx_builtin_include_directories = %{cxx_builtin_include_directories},
    sysroot_path = "%{sysroot_path}",
)

toolchain(
    name = "toolchain-%{suffix}",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    target_compatible_with = [
        "@platforms//cpu:%{target_arch}",
        "@platforms//os:%{target_os}",
    ],
    toolchain = ":cc_toolchain-%{suffix}",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

cc_toolchain(
    name = "cc_toolchain-%{suffix}",
    all_files = ":all-files-%{suffix}",
    ar_files = ":all-files-%{suffix}",
    as_files = ":all-files-%{suffix}",
    compiler_files = ":all-files-%{suffix}",
    linker_files = ":all-files-%{suffix}",
    objcopy_files = ":all-files-%{suffix}",
    strip_files = ":all-files-%{suffix}",
    toolchain_config = ":local-%{suffix}",
    dwp_files = ":all-files-%{suffix}",
    #module_map = ":modulemap-%{suffix}",
    #supports_header_parsing = 1,
    #supports_param_files = 1,
)

cc_toolchain_config(
    name = "local-%{suffix}",
    compiler = "%{compiler}",
    toolchain_identifier = "cc_toolchain_%{suffix}",
    target_arch = "%{target_arch}",
    target_os = "%{target_os}",
    libc = "%{libc}",
    cxx_builtin_include_directories = %{cxx_builtin_include_directories},
    tool_paths = %{tool_paths},
    compiler_configuration = %{compiler_configuration},
    supports_start_end_lib = %{supports_start_end_lib},
    sysroot_path = "%{sysroot_path}",
)
