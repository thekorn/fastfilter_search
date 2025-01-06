// this tool for now just created a random index, and dumps the index to a file
// future:
// - [ ] read content of index from JSON file(s)
// - [ ] configurable index options
// - [ ] time / logging of index operations

const std = @import("std");
const TextIndex = @import("TextIndex.zig");

const usage =
    \\Usage: ./create_index [options]
    \\
    \\Options:
    \\  --output-file OUTPUT_IDX_FILE
    \\
;

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    var opt_output_file_path: ?[]const u8 = null;

    {
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, "-h", arg) or std.mem.eql(u8, "--help", arg)) {
                try std.io.getStdOut().writeAll(usage);
                return std.process.cleanExit();
            } else if (std.mem.eql(u8, "--output-file", arg)) {
                i += 1;
                if (i > args.len) fatal("expected arg after '{s}'", .{arg});
                if (opt_output_file_path != null) fatal("duplicated {s} argument", .{arg});
                opt_output_file_path = args[i];
            } else {
                fatal("unrecognized arg: '{s}'", .{arg});
            }
        }
    }

    const output_file_path = opt_output_file_path orelse fatal("missing --output-file", .{});

    const output_dirname = std.fs.path.dirname(output_file_path) orelse fatal("unable to get dirname from  --output-file={s}", .{opt_output_file_path orelse "unknown"});
    const output_filename = std.fs.path.basename(output_file_path);

    std.debug.print(">>>> output file: {s}\n", .{output_file_path});
    std.debug.print(">>>> output path: {s}\n", .{output_dirname});
    std.debug.print(">>>> output filename: {s}\n", .{output_filename});

    const output_dir = try std.fs.openDirAbsolute(output_dirname, .{});

    var ti = try TextIndex.init(arena, .{});
    defer ti.deinit();

    const p1 = try ti.insert("Hallo welt");
    defer arena.destroy(p1);

    const p2 = try ti.insert("dies ist ein test");
    defer arena.destroy(p2);

    try ti.index();

    try ti.save(output_dir, output_filename);
    return std.process.cleanExit();
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
