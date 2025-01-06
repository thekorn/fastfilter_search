const std = @import("std");
const Stemmer = @import("snowballstem");

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

const GlobalState = struct {};

var global = GlobalState{};

pub export fn listStemmer() void {
    const stemmer = Stemmer.list(std.heap.wasm_allocator) catch |e| {
        print("Error: {any}\n", .{e});
        return;
    };
    //defer std.heap.wasm_allocator.free(stemmer);

    print(">>> {s}\n", .{stemmer});
}

//FIXME: somehow main is not stripped by build, so we need this entry point
// if we manage to disable the entry point, remove this function
pub fn main() !void {
    print(">>> HELLO MAIN\n", .{});
}
