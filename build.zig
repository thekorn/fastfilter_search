const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zg = b.dependency("zg", .{});

    const exe = b.addExecutable(.{
        .name = "fastfilter_search",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("CaseData", zg.module("CaseData"));

    const fastfilter = b.dependency("fastfilter", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("fastfilter", fastfilter.module("fastfilter"));

    const snowballstem = b.dependency("snowballstem", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("snowballstem", snowballstem.module("snowballstem"));

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .test_runner = b.path("test_runner.zig"),
    });
    exe_unit_tests.root_module.addImport("fastfilter", fastfilter.module("fastfilter"));
    exe_unit_tests.root_module.addImport("CaseData", zg.module("CaseData"));
    exe_unit_tests.root_module.addImport("snowballstem", snowballstem.module("snowballstem"));

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    const wasm = b.addExecutable(.{
        .name = "search",
        .root_source_file = b.path("src/wasm.zig"),
        .target = b.resolveTargetQuery(std.Target.Query.parse(
            .{ .arch_os_abi = "wasm32-freestanding" },
        ) catch unreachable),
        .optimize = optimize,
    });
    wasm.entry = .disabled;
    wasm.rdynamic = true;

    wasm.root_module.addImport("snowballstem", snowballstem.module("snowballstem"));

    //b.installArtifact(wasm);
    //const wasm_step = b.step("wasm", "wasm");

    //wasm_step.dependOn(b.getInstallStep());
    //var wasm_install_step = b.addInstallFileWithDir(wasm.getEmittedBin(), .prefix, "../www/search.wasm").step;

    b.getInstallStep().dependOn(&b.addInstallFileWithDir(wasm.getEmittedBin(), .prefix, "../www/search.wasm").step);
}
