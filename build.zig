const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const target_linux = b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .x86_64 });
    const mod_linux = b.addModule("root", .{
        .root_source_file = b.path("src/e272.zig"),
        .target = target_linux,
        .optimize = optimize,
        .link_libc = true,
    });

    mod_linux.addCSourceFile(.{
        .file = b.path("deps/gl.c"),
    });

    mod_linux.addLibraryPath(b.path("lib/linux"));
    mod_linux.addIncludePath(b.path("include"));

    mod_linux.linkSystemLibrary("glfw", .{});
    mod_linux.linkSystemLibrary("GL", .{});
    mod_linux.linkSystemLibrary("X11", .{});
    mod_linux.linkSystemLibrary("Xrandr", .{});
    mod_linux.linkSystemLibrary("Xi", .{});
    mod_linux.linkSystemLibrary("dl", .{});
    mod_linux.linkSystemLibrary("m", .{});

    const zigimg_dep = b.dependency("zigimg", .{
        .target = target_linux,
        .optimize = optimize,
    });
    mod_linux.addImport("zigimg", zigimg_dep.module("zigimg"));

    const zmath_dep = b.dependency("zmath", .{
        .target = target_linux,
        .optimize = optimize,
    });
    mod_linux.addImport("zmath", zmath_dep.module("root"));

    const exe_linux = b.addExecutable(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/test.zig"),
            .target = target_linux,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "e272", .module = mod_linux },
            },
        }),
        .use_llvm = true,
        .use_lld = true,
    });

    b.installArtifact(exe_linux);

    const target_windows = b.resolveTargetQuery(.{ .os_tag = .windows, .abi = .gnu, .cpu_arch = .x86_64 });
    const mod_windows = b.addModule("root", .{
        .root_source_file = b.path("src/e272.zig"),
        .target = target_windows,
        .optimize = optimize,
        .link_libc = true,
    });

    mod_windows.addCSourceFile(.{
        .file = b.path("deps/gl.c"),
    });

    mod_windows.addLibraryPath(b.path("lib/win"));
    mod_windows.addIncludePath(b.path("include"));

    mod_windows.linkSystemLibrary("glfw3", .{});
    mod_windows.linkSystemLibrary("gdi32", .{});
    mod_windows.linkSystemLibrary("opengl32", .{});

    const zigimg_dep_windows = b.dependency("zigimg", .{
        .target = target_windows,
        .optimize = optimize,
    });
    mod_windows.addImport("zigimg", zigimg_dep_windows.module("zigimg"));

    const zmath_dep_windows = b.dependency("zmath", .{
        .target = target_windows,
        .optimize = optimize,
    });
    mod_windows.addImport("zmath", zmath_dep_windows.module("root"));

    const exe_windows = b.addExecutable(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/test.zig"),
            .target = target_windows,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "e272", .module = mod_windows },
            },
        }),
    });

    b.installArtifact(exe_windows);

    b.installDirectory(.{
        .source_dir = b.path("test/res"),
        .install_dir = .bin,
        .install_subdir = "res",
    });
}
