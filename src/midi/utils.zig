const std = @import("std");

pub fn readVariableLengthQuantity(reader: *const std.io.AnyReader) !u32 {
    var result: u32 = 0;
    var byte: u8 = undefined;

    while (true) {
        byte = try reader.readByte();
        result = (result << 7) | (byte & 0x7F);
        if (byte & 0x80 == 0) break;
    }

    return result;
}

test "readVariableLengthQuantity" {
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

    // std.debug.print("Running test: readVariableLengthQuantity\n", .{});
    for (cases) |case| {
        var fbs = std.io.fixedBufferStream(case.input);
        const reader = fbs.reader().any();
        const result = try readVariableLengthQuantity(&reader);
        try std.testing.expectEqual(case.expected, result);
        // std.debug.print("Test case passed: input = {any}, expected = {}, result = {}\n", .{ case.input, case.expected, result });
    }
}
