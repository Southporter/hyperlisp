const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("hyperlisp", lib_mod);

    const lib = b.addStaticLibrary(.{
        .name = "hyperlisp",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "hyperlisp",
        .root_module = exe_mod,
    });
    exe.linkLibC();
    exe.linkSystemLibrary("readline");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const check_exe = b.addExecutable(.{
        .name = "hyperlisp",
        .root_module = exe_mod,
    });
    check_exe.linkLibC();
    check_exe.linkSystemLibrary("readline");

    const check_step = b.step("check", "Check for build errors");
    check_step.dependOn(&check_exe.step);

    const wasm_mod = b.createModule(.{
        .root_source_file = b.path("src/wasm.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        }),
        .optimize = .Debug,
    });
    wasm_mod.addImport("hyperlisp", lib_mod);
    const wasm_exe = b.addExecutable(.{
        .name = "hyperlisp",
        .root_module = wasm_mod,
    });
    wasm_exe.export_memory = true;
    wasm_exe.rdynamic = true;

    b.installArtifact(wasm_exe);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
