const std = @import("std");
const midi_message = @import("midi_message.zig");
const utils = @import("utils.zig");

pub const HeaderChunk = struct {
    magic: [4]u8,
    length: u32,
    format: Format,
    num_tracks: u16,
    division: u16,

    pub const Format = enum(u16) {
        single_track = 0,
        multiple_tracks = 1,
        multiple_songs = 2,
    };

    pub fn parse(bytes: []const u8) !HeaderChunk {
        if (bytes.len < 14) return error.InsufficientData;

        const magic = bytes[0..4].*;

        const length = std.mem.readVarInt(u32, bytes[4..8], .big);
        const format: Format = @enumFromInt(std.mem.readVarInt(u16, bytes[8..10], .big));
        const num_tracks = std.mem.readVarInt(u16, bytes[10..12], .big);
        const division = std.mem.readVarInt(u16, bytes[12..14], .big);

        const header = HeaderChunk{
            .magic = magic,
            .length = length,
            .format = format,
            .num_tracks = num_tracks,
            .division = division,
        };

        try header.validate();

        return header;
    }

    pub fn validate(self: HeaderChunk) !void {
        if (!std.mem.eql(u8, &self.magic, "MThd")) {
            return error.InvalidMagicNumber;
        }
        if (self.length != 6) {
            return error.InvalidHeaderLength;
        }
    }

    pub fn print(self: HeaderChunk) void {
        std.debug.print("HeaderChunk:\n", .{});
        std.debug.print("  magic: {s}\n", .{self.magic});
        std.debug.print("  length: {}\n", .{self.length});
        std.debug.print("  format: {}\n", .{self.format});
        std.debug.print("  num_tracks: {}\n", .{self.num_tracks});
        std.debug.print("  division: {}\n", .{self.division});
    }
};

pub const TrackChunk = struct {
    magic: [4]u8,
    length: u32,
    // events: []TrackEvent,

    pub fn parse(bytes: []const u8) !TrackChunk {
        if (bytes.len < 8) return error.InsufficientData;

        const magic = bytes[0..4].*;
        const length = std.mem.readIntBig(u32, bytes[4..8]);

        const track = TrackChunk{
            .magic = magic,
            .length = length,
        };

        try track.validate();

        return track;
    }

    pub fn validate(self: TrackChunk) !void {
        if (!std.mem.eql(u8, &self.magic, "MTrk")) {
            return error.InvalidMagicNumber;
        }
    }
};

pub const TrackEvent = struct {
    delta_time: u32,
    // event: Event,

    pub fn parse(bytes: []const u8) !TrackEvent {
        const delta_time = try utils.readVariableLengthQuantity(bytes);

        return TrackEvent{
            .delta_time = delta_time,
        };
    }
};

// pub const Event = union(enum) {
//     track: TrackEvent,
//     meta: MetaEvent,
//     system: SystemEvent,
// };

pub const MidiFile = struct {
    header: HeaderChunk,

    pub fn parse(allocator: std.mem.Allocator, file: std.fs.File) !MidiFile {
        // Buffer to hold the file contents
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();

        // Read the entire file into the buffer
        try file.reader().readAllArrayList(&buffer, std.math.maxInt(usize));
        const bytes = buffer.items;

        // Parse the header chunk
        const header = try HeaderChunk.parse(bytes);
        header.print();

        const event_bytes = [_]u8{ 0x90, 0x3C, 0x7F };
        const message = try midi_message.MidiEvent.parse(&event_bytes);
        std.debug.print("MIDI Event: {}\n", .{message});

        return MidiFile{ .header = header };
    }
};

test {
    @import("std").testing.refAllDecls(@This());
}
