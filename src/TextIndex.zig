const std = @import("std");
const Stemmer = @import("snowballstem");
const SliceIterator = @import("fastfilter").SliceIterator;

const Filter = @import("filter.zig").Filter;
const TokenIter = @import("TokenIter.zig");

const TextIterator = SliceIterator(u64);
const TextFilter = Filter(.{}, []const u8, *TextIterator);

const TextOptions = struct {
    estimated_keys: usize = 100,
    language: []const u8 = "german",
    charenc: []const u8 = "UTF_8",
};

alloc: std.mem.Allocator,
filter: TextFilter,
stemmer: Stemmer,
cache: std.ArrayListUnmanaged([]u64),

const Self = @This();

pub fn init(alloc: std.mem.Allocator, options: TextOptions) !Self {
    return .{
        .alloc = alloc,
        .filter = TextFilter.init(options.estimated_keys),
        .stemmer = try Stemmer.init(options.language, options.charenc),
        .cache = std.ArrayListUnmanaged([]u64){},
    };
}

pub fn deinit(self: *Self) void {
    self.stemmer.deinit();
    self.filter.deinit(self.alloc);
    for (self.cache.items) |item| {
        self.alloc.free(item);
    }
    self.cache.deinit(self.alloc);
}

pub fn insert(self: *Self, text: []const u8) !*TextIterator {
    var tokens = try TokenIter.init(self.alloc, text);
    defer tokens.deinit();
    var keys = std.ArrayListUnmanaged(u64){};

    // TODO: use hashmap ??
    while (tokens.next()) |token| {
        const s = self.stemmer.stem(token);
        try keys.append(self.alloc, std.hash_map.hashString(s));
    }

    const ts = try keys.toOwnedSlice(self.alloc);
    errdefer self.alloc.free(ts);

    try self.cache.append(self.alloc, ts);

    const ptr = try self.alloc.create(TextIterator);

    ptr.* = TextIterator.init(ts);
    try self.filter.insert(self.alloc, ptr, text);
    return ptr;
}

pub fn index(self: *Self) !void {
    try self.filter.index(self.alloc);
}

pub fn contains(self: *Self, word: []const u8) !bool {
    var token = try TokenIter.init(self.alloc, word);
    defer token.deinit();

    const t = token.next();
    if (t == null) return error.EmptySearchWord;
    if (token.next() != null) return error.MoreThanOneWord;
    const s = self.stemmer.stem(t.?);
    const key = std.hash_map.hashString(s);
    return self.filter.contains(key);
}

test "index contains words" {
    var ti = try Self.init(std.testing.allocator, .{});
    defer ti.deinit();

    const p1 = try ti.insert("Hallo welt");
    defer std.testing.allocator.destroy(p1);

    const p2 = try ti.insert("dies ist ein test");
    defer std.testing.allocator.destroy(p2);

    try ti.index();

    try std.testing.expectEqual(true, try ti.contains("Hallo"));
    try std.testing.expectEqual(true, try ti.contains("hallo"));
    try std.testing.expectEqual(true, try ti.contains("test"));
    try std.testing.expectEqual(false, try ti.contains("boo"));
}

test "invalid contains words" {
    var ti = try Self.init(std.testing.allocator, .{});
    defer ti.deinit();

    const p1 = try ti.insert("Hallo welt");
    defer std.testing.allocator.destroy(p1);

    const p2 = try ti.insert("dies ist ein test");
    defer std.testing.allocator.destroy(p2);

    try ti.index();

    try std.testing.expectError(error.MoreThanOneWord, ti.contains("Hallo googog"));
    try std.testing.expectError(error.EmptySearchWord, ti.contains("        "));
}
