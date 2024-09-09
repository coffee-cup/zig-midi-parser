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

    pub fn parse(reader: *const std.io.AnyReader) !HeaderChunk {
        const magic = try reader.readBytesNoEof(4);
        const length = try reader.readInt(u32, .big);
        const format: Format = @enumFromInt(try reader.readInt(u16, .big));
        const num_tracks = try reader.readInt(u16, .big);
        const division = try reader.readInt(u16, .big);

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

    pub fn parse(reader: *const std.io.AnyReader) !TrackChunk {
        const magic = try reader.readBytesNoEof(4);
        const length = try reader.readInt(u32, .big);

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

    pub fn parse(reader: *const std.io.AnyReader) !TrackEvent {
        const delta_time = try utils.readVariableLengthQuantity(reader);
        const event = try reader.readByte();

        return TrackEvent{
            .delta_time = delta_time,
            .event = event,
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

    pub fn parse(file: std.fs.File) !MidiFile {
        var reader = file.reader().any();

        const header = try HeaderChunk.parse(&reader);
        header.print();

        const bytes = [_]u8{ 0x90, 0x3C, 0x7F };
        const message = try midi_message.MidiEvent.parse(&bytes);
        std.debug.print("MIDI Event: {}\n", .{message});

        return MidiFile{ .header = header };
    }
};

test {
    @import("std").testing.refAllDecls(@This());
}
