const std = @import("std");
const Stemmer = @import("snowballstem");

const filter = @import("filter.zig");
const TokenIter = @import("TokenIter.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    const stemmer = try Stemmer.list(alloc);
    defer alloc.free(stemmer);

    std.debug.print(">>> {s}\n", .{stemmer});

    var tokenIter = try TokenIter.init(alloc, "HELLO über Ölung     123      ");
    defer tokenIter.deinit();

    while (tokenIter.next()) |token| {
        std.debug.print("---{s}---\n", .{token});
    }
}

test {
    _ = filter;
    _ = TokenIter;
}
