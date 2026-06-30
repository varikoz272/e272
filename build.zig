const std = @import("std");

pub fn build(b: *std.Build) void {
    const target_linux = b.resolveTargetQuery(.{ .os_tag = .linux, .cpu_arch = .x86_64, .abi = .gnu, .glibc_version = .{ .major = 2, .minor = 34, .patch = 0 } });
    // const target_win: std.Target.Query = &.{ .os_tag = .windows, .cpu_arch = .x86_64 };
    const optimize = b.standardOptimizeOption(.{});

    const core_mod = b.addModule("e272", .{
        .root_source_file = b.path("src/e272.zig"),
        .target = target_linux,
        .optimize = optimize,
        .link_libc = true,
    });

    core_mod.addIncludePath(b.path("include"));
    core_mod.addLibraryPath(b.path("lib/linux"));

    core_mod.addCSourceFile(.{
        .file = b.path("deps/gl.c"),
        .flags = &.{
            "-DGLM_FORCE_PURE=ON",
            "-DGLM_FORCE_DEFAULT_ALIGNMENT",
            "-DGLM_FORCE_INLINE",
            "-DCGLM_NO_SSE2",
        },
    });

    core_mod.linkSystemLibrary("pthread", .{});
    core_mod.linkSystemLibrary("glfw", .{});
    core_mod.linkSystemLibrary("GL", .{});
    core_mod.linkSystemLibrary("X11", .{});
    core_mod.linkSystemLibrary("Xrandr", .{});
    core_mod.linkSystemLibrary("Xi", .{});
    core_mod.linkSystemLibrary("dl", .{});
    core_mod.linkSystemLibrary("glm", .{});
    core_mod.linkSystemLibrary("m", .{});

    const zigimg_dep = b.dependency("zigimg", .{
        .target = target_linux,
        .optimize = optimize,
    });

    core_mod.addImport("zigimg", zigimg_dep.module("zigimg"));

    b.installDirectory(.{
        .source_dir = b.path("test/res"),
        .install_dir = .bin,
        .install_subdir = "res",
    });

    const test_mod = b.addModule("test", .{
        .root_source_file = b.path("test/test.zig"),
        .target = target_linux,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "e272", .module = core_mod },
        },
    });

    const tests = b.addTest(.{
        .root_module = test_mod,
        .use_llvm = true,
        .use_lld = true,
    });

    const test_step = b.step("test", "run tests");
    const test_cmd = b.addRunArtifact(tests);
    test_step.dependOn(&test_cmd.step);

    b.installArtifact(tests);

    test_cmd.step.dependOn(b.getInstallStep());
}
