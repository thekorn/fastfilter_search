const std = @import("std");
const CaseData = @import("CaseData");

caseData: CaseData,
alloc: std.mem.Allocator,
lcased: []const u8,
lineIter: std.mem.TokenIterator(u8, .sequence),

const Self = @This();

pub fn init(
    alloc: std.mem.Allocator,
    input: []const u8,
) !Self {
    const cd = try CaseData.init(alloc);
    const lcased = try cd.toLowerStr(alloc, input);

    const lineIter = std.mem.tokenizeSequence(u8, lcased, " ");

    return .{
        .alloc = alloc,
        .caseData = cd,
        .lineIter = lineIter,
        .lcased = lcased,
    };
}

pub fn next(self: *Self) ?[]const u8 {
    const result = self.lineIter.next();
    if (result == null) {
        return null;
    }
    return result;
}

pub fn deinit(self: *Self) void {
    defer self.alloc.free(self.lcased);
    self.caseData.deinit();
}

test "tokenize sentence" {
    var tokenIter = try Self.init(std.testing.allocator, "HELLO über Ölung     123      ");
    defer tokenIter.deinit();

    try std.testing.expectEqualStrings("hello", tokenIter.next().?);
    try std.testing.expectEqualStrings("über", tokenIter.next().?);
    try std.testing.expectEqualStrings("ölung", tokenIter.next().?);
    try std.testing.expectEqualStrings("123", tokenIter.next().?);
}
