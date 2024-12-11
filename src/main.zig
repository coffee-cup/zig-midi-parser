const std = @import("std");
const midi = @import("midi/midi.zig");

// Ensure all the modules are comptime so they are tested
comptime {
    _ = @import("midi/midi.zig");
    _ = @import("midi/midi_message.zig");
    _ = @import("midi/utils.zig");
}

const midi_file_name = "./midi/queen.midi";

pub fn main() !void {
    const file = try std.fs.cwd().openFile(midi_file_name, .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const midi_file = try midi.MidiFile.parse(allocator, file);

    midi_file.print();

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

test {
    @import("std").testing.refAllDecls(@This());
}
