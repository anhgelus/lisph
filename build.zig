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

    const std_lib = b.addLibrary(.{
        .name = "lisph",
        .root_module = b.addModule("lisph-std", .{
            .root_source_file = b.path("src/root.zig"),
            .optimize = optimize,
            .target = target,
            .strip = optimize != .Debug,
        }),
    });
    std_lib.step.dependOn(&interpreter_lib.step);
    std_lib.root_module.addImport("lisph-interpreter", interpreter_lib.root_module);

    const fmt = b.addFmt(.{
        .paths = &.{
            "interpreter/",
            "src/",
            "build.zig",
            "build.zig.zon",
        },
    });
    interpreter_lib.step.dependOn(&fmt.step);
    std_lib.step.dependOn(&fmt.step);

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
    exe.root_module.addImport("lib", std_lib.root_module);
    exe.step.dependOn(&interpreter_lib.step);

    b.installArtifact(exe);

    const test_step = b.step("test", "Run tests");
    const run_interpreter_tests = b.addRunArtifact(b.addTest(.{
        .root_module = interpreter_lib.root_module,
    }));
    const run_std_tests = b.addRunArtifact(b.addTest(.{
        .root_module = std_lib.root_module,
    }));
    test_step.dependOn(&run_interpreter_tests.step);
    test_step.dependOn(&run_std_tests.step);

    const check = b.step("check", "Check if it compiles");
    check.dependOn(&exe.step);
}
