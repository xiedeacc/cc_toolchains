package(default_visibility = ["//visibility:public"])

# attention: cannot contain sysbol link file
filegroup(
    name = "all_files",
    srcs = glob(
        ["**"],
        allow_empty = True,
    ),
)

