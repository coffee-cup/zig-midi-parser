const std = @import("std");
const midi = @import("midi/midi.zig");

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

test {
    @import("std").testing.refAllDecls(@This());
}
