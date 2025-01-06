const std = @import("std");
const Stemmer = @import("snowballstem");
const TextIndex = @import("TextIndex.zig");

fn loadTextIndex(alloc: std.mem.Allocator, buf: []u8, options: anytype) !*TextIndex {
    const ret = try alloc.create(TextIndex);
    errdefer alloc.destroy(ret);

    ret.* = try TextIndex.loads(alloc, buf, options);

    return ret;
}

pub const std_options = std.Options{
    .logFn = wasmLog,
    .log_level = .debug,
};

pub extern fn logWasm(s: [*]const u8, len: usize) void;
fn wasmLog(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = message_level;
    _ = scope;
    print(format, args);
}

fn print(comptime fmt: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    const slice = std.fmt.bufPrint(&buf, fmt, args) catch {
        logWasm(&buf, buf.len);
        return;
    };
    logWasm(slice.ptr, slice.len);
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = ret_addr;
    _ = error_return_trace;
    logWasm(msg.ptr, msg.len);
    asm volatile ("unreachable");
    unreachable;
}

pub export var global_chunk: [16384]u8 = undefined;

pub export fn pushTextIndexData(len: usize) void {
    global.text_index_data.appendSlice(global_chunk[0..len]) catch unreachable;
    print(">>> we loaded {d} bytes of index data", .{len});
}

const GlobalState = struct {
    text_index: *TextIndex = undefined,
    text_index_data: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.wasm_allocator),
};

var global = GlobalState{};

pub export fn listStemmer() void {
    const stemmer = Stemmer.list(std.heap.wasm_allocator) catch |e| {
        print("Error: {any}\n", .{e});
        return;
    };
    //defer std.heap.wasm_allocator.free(stemmer);

    print(">>> {s}\n", .{stemmer});
}

pub export fn init() void {
    global.text_index = loadTextIndex(std.heap.wasm_allocator, global.text_index_data.items, .{}) catch |e| {
        std.log.err("TextIndex.loads failed: {any}", .{e});
        return;
    };
}

//FIXME: somehow main is not stripped by build, so we need this entry point
// if we manage to disable the entry point, remove this function
pub fn main() !void {
    print(">>> HELLO MAIN\n", .{});
}
