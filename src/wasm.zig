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
    gpa: std.heap.GeneralPurposeAllocator(.{
        .MutexType = std.Thread.Mutex,
    }) = std.heap.GeneralPurposeAllocator(.{
        .MutexType = std.Thread.Mutex,
    }){},
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

// Allocator implementation, taken from https://github.com/marler8997/ziglibc/blob/main/src/cstd.zig

const alloc_align = 16;

const alloc_metadata_len = std.mem.alignForward(usize, alloc_align, @sizeOf(usize));

pub export fn malloc(size: usize) callconv(.C) ?[*]align(alloc_align) u8 {
    print("malloc {}", .{size});
    std.debug.assert(size > 0); // TODO: what should we do in this case?
    const full_len = alloc_metadata_len + size;
    const buf = global.gpa.allocator().alignedAlloc(u8, alloc_align, full_len) catch |err| switch (err) {
        error.OutOfMemory => {
            print("malloc return null", .{});
            return null;
        },
    };
    @as(*usize, @ptrCast(buf)).* = full_len;
    const result = @as([*]align(alloc_align) u8, @ptrFromInt(@intFromPtr(buf.ptr) + alloc_metadata_len));
    print("malloc return {*}", .{result});
    return result;
}

fn getGpaBuf(ptr: [*]u8) []align(alloc_align) u8 {
    const start = @intFromPtr(ptr) - alloc_metadata_len;
    const len = @as(*usize, @ptrFromInt(start)).*;
    return @alignCast(@as([*]u8, @ptrFromInt(start))[0..len]);
}

export fn realloc(ptr: ?[*]align(alloc_align) u8, size: usize) callconv(.C) ?[*]align(alloc_align) u8 {
    print("realloc {*} {}", .{ ptr, size });
    const gpa_buf = getGpaBuf(ptr orelse {
        const result = malloc(size);
        print("realloc return {*} (from malloc)", .{result});
        return result;
    });
    if (size == 0) {
        global.gpa.allocator().free(gpa_buf);
        return null;
    }

    const gpa_size = alloc_metadata_len + size;
    if (global.gpa.allocator().rawResize(gpa_buf, std.math.log2(alloc_align), gpa_size, @returnAddress())) {
        @as(*usize, @ptrCast(gpa_buf.ptr)).* = gpa_size;
        print("realloc return {*}", .{ptr});
        return ptr;
    }

    const new_buf = global.gpa.allocator().reallocAdvanced(
        gpa_buf,
        gpa_size,
        @returnAddress(),
    ) catch |e| switch (e) {
        error.OutOfMemory => {
            print("realloc out-of-mem from {} to {}", .{ gpa_buf.len, gpa_size });
            return null;
        },
    };
    @as(*usize, @ptrCast(new_buf.ptr)).* = gpa_size;
    const result = @as([*]align(alloc_align) u8, @ptrFromInt(@intFromPtr(new_buf.ptr) + alloc_metadata_len));
    print("realloc return {*}", .{result});
    return result;
}

export fn calloc(nmemb: usize, size: usize) callconv(.C) ?[*]align(alloc_align) u8 {
    const total = std.math.mul(usize, nmemb, size) catch {
        // TODO: set errno
        //errno = c.ENOMEM;
        return null;
    };
    const ptr = malloc(total) orelse return null;
    @memset(ptr[0..total], 0);
    return ptr;
}

pub export fn free(ptr: ?[*]align(alloc_align) u8) callconv(.C) void {
    print("free {*}", .{ptr});
    const p = ptr orelse return;
    global.gpa.allocator().free(getGpaBuf(p));
}
