const std = @import("std");

fn link(
    root_module: *std.Build.Module,
    fastfilter: *std.Build.Dependency,
    zg: *std.Build.Dependency,
    snowballstem: *std.Build.Dependency,
) void {
    root_module.addImport("fastfilter", fastfilter.module("fastfilter"));
    root_module.addImport("CaseData", zg.module("CaseData"));
    root_module.addImport("snowballstem", snowballstem.module("snowballstem"));
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zg = b.dependency("zg", .{});
    const fastfilter = b.dependency("fastfilter", .{
        .target = target,
        .optimize = optimize,
    });
    const snowballstem = b.dependency("snowballstem", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "fastfilter_search",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    link(&exe.root_module, fastfilter, zg, snowballstem);

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
    link(&exe_unit_tests.root_module, fastfilter, zg, snowballstem);

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
    link(&wasm.root_module, fastfilter, zg, snowballstem);

    b.getInstallStep().dependOn(&b.addInstallFileWithDir(wasm.getEmittedBin(), .prefix, "../www/search.wasm").step);

    const create_index_tool = b.addExecutable(.{
        .name = "create_index",
        .root_source_file = b.path("src/create_index.zig"),
        .target = b.host,
    });
    link(&create_index_tool.root_module, fastfilter, zg, snowballstem);

    const create_index_tool_step = b.addRunArtifact(create_index_tool);
    create_index_tool_step.addArg("--output-file");
    const output = create_index_tool_step.addOutputFileArg("search.idx");

    b.getInstallStep().dependOn(&b.addInstallFileWithDir(output, .prefix, "../www/search.idx").step);
}
