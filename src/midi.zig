const std = @import("std");

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

pub const MidiFile = struct {
    header: HeaderChunk,

    pub fn parse(file: std.fs.File) !MidiFile {
        var reader = file.reader().any();

        const header = try HeaderChunk.parse(&reader);
        header.print();

        return MidiFile{ .header = header };
    }
};
