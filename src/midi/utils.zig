const std = @import("std");

pub fn readVariableLengthQuantity(bytes: []const u8) !u32 {
    var result: u32 = 0;
    var index: usize = 0;

    while (index < bytes.len) {
        const byte = bytes[index];
        result = (result << 7) | (byte & 0x7F);
        index += 1;
        if (byte & 0x80 == 0) break;
    }

    if (index == bytes.len and bytes[index - 1] & 0x80 != 0) {
        return error.IncompleteVariableLengthQuantity;
    }

    return result;
}

test "readVariableLengthQuantity" {
    const testing = std.testing;

    const TestCase = struct { input: []const u8, expected: u32 };
    const cases = [_]TestCase{
        .{ .input = &[_]u8{0x00}, .expected = 0x00 },
        .{ .input = &[_]u8{0x40}, .expected = 0x40 },
        .{ .input = &[_]u8{0x7F}, .expected = 0x7F },
        .{ .input = &[_]u8{ 0x81, 0x00 }, .expected = 0x80 },
        .{ .input = &[_]u8{ 0xC0, 0x00 }, .expected = 0x2000 },
        .{ .input = &[_]u8{ 0xFF, 0x7F }, .expected = 0x3FFF },
        .{ .input = &[_]u8{ 0x81, 0x80, 0x00 }, .expected = 0x4000 },
        .{ .input = &[_]u8{ 0xFF, 0xFF, 0x7F }, .expected = 0x1FFFFF },
        .{ .input = &[_]u8{ 0x81, 0x80, 0x80, 0x00 }, .expected = 0x200000 },
        .{ .input = &[_]u8{ 0xFF, 0xFF, 0xFF, 0x7F }, .expected = 0xFFFFFFF },
    };

    for (cases) |case| {
        const result = try readVariableLengthQuantity(case.input);
        try testing.expectEqual(case.expected, result);
    }
}
