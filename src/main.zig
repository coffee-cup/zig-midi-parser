const std = @import("std");
const midi = @import("midi.zig");

const midi_file_name = "./midi/queen.midi";

pub fn main() !void {
    const file = try std.fs.cwd().openFile(midi_file_name, .{});
    defer file.close();

    _ = try midi.MidiFile.parse(file);
    std.debug.print("MIDI file parsed\n", .{});

    // while (reader.readByte()) |b| {
    //     byte = b;
    //     // Process each byte here
    //     std.debug.print("Read byte: {}\n", .{byte});
    // } else |err| {
    //     if (err != error.EndOfStream) {
    //         return err;
    //     }
    // }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
