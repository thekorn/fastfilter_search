const std = @import("std");
const Stemmer = @import("snowballstem");
const fastfilter = @import("fastfilter");

const filter = @import("filter.zig");
const TokenIter = @import("TokenIter.zig");
const TextIndex = @import("TextIndex.zig");

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

    var ti = try TextIndex.init(alloc, .{});
    defer ti.deinit();

    const p1 = try ti.insert("Hallo welt");
    defer alloc.destroy(p1);

    const p2 = try ti.insert("dies ist ein test");
    defer alloc.destroy(p2);

    try ti.index();

    std.debug.print("contains 'Hallo'? {any}\n", .{try ti.contains("Hallo")});
    std.debug.print("contains 'Test'? {any}\n", .{try ti.contains("test")});
    std.debug.print("contains 'hallo'? {any}\n", .{try ti.contains("hallo")});
    std.debug.print("contains 'boo'? {any}\n", .{try ti.contains("boo")});
}

test {
    _ = filter;
    _ = TokenIter;
    _ = TextIndex;
}
