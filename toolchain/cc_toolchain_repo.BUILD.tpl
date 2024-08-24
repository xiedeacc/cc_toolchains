load("@bazel_skylib//rules:native_binary.bzl", "native_binary")
load("@bazel_skylib//rules:select_file.bzl", "select_file")
package(default_visibility = ["//visibility:public"])

# attention: cannot contain sysbol link file
filegroup(
    name = "all_files",
    srcs = glob(
        ["**"],
        allow_empty = True,
    ),
)

