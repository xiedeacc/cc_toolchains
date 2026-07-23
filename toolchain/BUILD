exports_files(
    glob(
        ["*"],
        exclude = ["BUILD.bazel"],
    ),
)

constraint_setting(
    name = "libc",
    visibility = ["//visibility:public"],
)

constraint_value(
    name = "libc_glibc",
    constraint_setting = ":libc",
    visibility = ["//visibility:public"],
)

constraint_value(
    name = "libc_musl",
    constraint_setting = ":libc",
    visibility = ["//visibility:public"],
)
