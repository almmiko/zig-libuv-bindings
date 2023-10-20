const std = @import("std");

/// Directories with our includes.
const root = thisDir() ++ "/vendor/libuv/";
const include_path = root ++ "include";

pub const pkg = std.build.Pkg{
    .name = "libuv",
    .source = .{ .path = thisDir() ++ "/src/main.zig" },
};

fn thisDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zig-libuv",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    _ = try link(b, exe);
    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

// pub fn build(b: *std.build.Builder) !void {
//     const target = b.standardTargetOptions(.{});
//     const optimize = b.standardOptimizeOption(.{});
//
//     const exe = b.addExecutable(.{
//         .name = "zig-libuv",
//         // In this case the main source file is merely a path, however, in more
//         // complicated build scripts, this could be a generated file.
//         .root_source_file = .{ .path = "src/main.zig" },
//         .target = target,
//         .optimize = optimize,
//     });
//
//     _ = try link(b, exe);
//     b.installArtifact(exe);
//
//     const run_cmd = b.addRunArtifact(exe);
//
//     // This allows the user to pass arguments to the application in the build
//     // command itself, like this: `zig build run -- arg1 arg2 etc`
//     if (b.args) |args| {
//         run_cmd.addArgs(args);
//     }
//
//     const test_step = b.step("test", "Run tests");
//     const tests_run = b.addRunArtifact(exe);
//     test_step.dependOn(&tests_run.step);
// }

pub fn link(b: *std.build.Builder, step: *std.build.LibExeObjStep) !*std.build.LibExeObjStep {
    const libuv = try buildLibuv(b, step);
    step.linkLibrary(libuv);
    step.addIncludePath(.{ .path = include_path });
    return libuv;
}

pub fn buildLibuv(
    b: *std.build.Builder,
    step: *std.build.LibExeObjStep,
) !*std.build.LibExeObjStep {
    const target = step.target;
    const lib = b.addStaticLibrary(.{
        .name = "uv",
        .target = target,
        .optimize = step.optimize,
    });

    // Include dirs
    lib.addIncludePath(.{ .path = include_path });
    lib.addIncludePath(.{ .path = root ++ "src" });

    // Links
    if (target.isWindows()) {
        lib.linkSystemLibrary("psapi");
        lib.linkSystemLibrary("user32");
        lib.linkSystemLibrary("advapi32");
        lib.linkSystemLibrary("iphlpapi");
        lib.linkSystemLibrary("userenv");
        lib.linkSystemLibrary("ws2_32");
    }
    if (target.isLinux()) {
        lib.linkSystemLibrary("pthread");
    }
    lib.linkLibC();

    // Compilation
    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();
    // try flags.appendSlice(&.{});

    if (!target.isWindows()) {
        try flags.appendSlice(&.{
            "-D_FILE_OFFSET_BITS=64",
            "-D_LARGEFILE_SOURCE",
        });
    }

    if (target.isLinux()) {
        try flags.appendSlice(&.{
            "-D_GNU_SOURCE",
            "-D_POSIX_C_SOURCE=200112",
        });
    }

    if (target.isDarwin()) {
        try flags.appendSlice(&.{
            "-D_DARWIN_UNLIMITED_SELECT=1",
            "-D_DARWIN_USE_64_BIT_INODE=1",
        });
    }

    // C files common to all platforms
    lib.addCSourceFiles(&.{
        root ++ "src/fs-poll.c",
        root ++ "src/idna.c",
        root ++ "src/inet.c",
        root ++ "src/random.c",
        root ++ "src/strscpy.c",
        root ++ "src/strtok.c",
        root ++ "src/threadpool.c",
        root ++ "src/timer.c",
        root ++ "src/uv-common.c",
        root ++ "src/uv-data-getter-setters.c",
        root ++ "src/version.c",
    }, flags.items);

    if (!target.isWindows()) {
        lib.addCSourceFiles(&.{
            root ++ "src/unix/async.c",
            root ++ "src/unix/core.c",
            root ++ "src/unix/dl.c",
            root ++ "src/unix/fs.c",
            root ++ "src/unix/getaddrinfo.c",
            root ++ "src/unix/getnameinfo.c",
            root ++ "src/unix/loop-watcher.c",
            root ++ "src/unix/loop.c",
            root ++ "src/unix/pipe.c",
            root ++ "src/unix/poll.c",
            root ++ "src/unix/process.c",
            root ++ "src/unix/random-devurandom.c",
            root ++ "src/unix/signal.c",
            root ++ "src/unix/stream.c",
            root ++ "src/unix/tcp.c",
            root ++ "src/unix/thread.c",
            root ++ "src/unix/tty.c",
            root ++ "src/unix/udp.c",
        }, flags.items);
    }

    if (target.isLinux() or target.isDarwin()) {
        lib.addCSourceFiles(&.{
            root ++ "src/unix/proctitle.c",
        }, flags.items);
    }

    if (target.isLinux()) {
        lib.addCSourceFiles(&.{
            root ++ "src/unix/linux.c",
            root ++ "src/unix/procfs-exepath.c",
            root ++ "src/unix/random-getrandom.c",
            root ++ "src/unix/random-sysctl-linux.c",
        }, flags.items);
    }

    if (target.isDarwin() or
        target.isOpenBSD() or
        target.isNetBSD() or
        target.isFreeBSD() or
        target.isDragonFlyBSD())
    {
        lib.addCSourceFiles(&.{
            root ++ "src/unix/bsd-ifaddrs.c",
            root ++ "src/unix/kqueue.c",
        }, flags.items);
    }

    if (target.isDarwin() or target.isOpenBSD()) {
        lib.addCSourceFiles(&.{
            root ++ "src/unix/random-getentropy.c",
        }, flags.items);
    }

    if (target.isDarwin()) {
        lib.addCSourceFiles(&.{
            root ++ "src/unix/darwin-proctitle.c",
            root ++ "src/unix/darwin.c",
            root ++ "src/unix/fsevents.c",
        }, flags.items);
    }

    return lib;
}
