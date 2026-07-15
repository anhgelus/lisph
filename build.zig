const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const interpreter_lib = b.addLibrary(.{
        .name = "lisph",
        .root_module = b.addModule("lisph", .{
            .root_source_file = b.path("interpreter/root.zig"),
            .optimize = optimize,
            .target = target,
            .strip = optimize != .Debug,
        }),
    });

    const fmt = b.addFmt(.{
        .paths = &.{
            "interpreter/",
            "src/",
            "build.zig",
            "build.zig.zon",
        },
    });
    interpreter_lib.step.dependOn(&fmt.step);

    const exe = b.addExecutable(.{
        .name = "lisph-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .optimize = optimize,
            .target = target,
            .strip = optimize != .Debug,
        }),
    });
    exe.root_module.addImport("lisph-interpreter", interpreter_lib.root_module);
    exe.step.dependOn(&interpreter_lib.step);

    b.installArtifact(exe);

    const test_step = b.step("test", "Run tests");
    const exe_tests = b.addTest(.{
        .root_module = interpreter_lib.root_module,
    });
    const run_tests = b.addRunArtifact(exe_tests);
    test_step.dependOn(&run_tests.step);

    const check = b.step("check", "Check if it compiles");
    check.dependOn(&exe.step);
}
