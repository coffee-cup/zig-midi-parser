const std = @import("std");
const utils = @import("./utils.zig");

fn parse_channel(byte: u8) u4 {
    return @truncate(byte & 0x0F);
}

pub const MidiEvent = union(enum) {
    note_off: struct { channel: u8, key: u8, velocity: u8 },
    note_on: struct { channel: u8, key: u8, velocity: u8 },
    note_aftertouch: struct { channel: u8, key: u8, pressure: u8 },
    controller_change: struct { channel: u8, controller: u8, value: u8 },
    program_change: struct { channel: u8, program: u8 },
    channel_aftertouch: struct { channel: u8, pressure: u8 },
    pitch_wheel_change: struct { channel: u8, value: u16 },
    meta_event: MetaEvent,

    pub fn len(self: MidiEvent) usize {
        return switch (self) {
            .note_off => 3,
            .note_on => 3,
            .note_aftertouch => 3,
            .controller_change => 3,
            .program_change => 2,
            .channel_aftertouch => 2,
            .pitch_wheel_change => 3,
            .meta_event => |meta_event| meta_event.len(),
        };
    }

    pub fn parse(bytes: []const u8) !MidiEvent {
        if (bytes.len < 1) return error.InvalidMessage;

        const status = bytes[0];

        switch (status & 0xF0) { // Parse the status without the channel
            0x80 => return .{ .note_off = .{
                .channel = parse_channel(status),
                .key = bytes[1],
                .velocity = bytes[2],
            } },

            0x90 => return .{ .note_on = .{
                .channel = parse_channel(status),
                .key = bytes[1],
                .velocity = bytes[2],
            } },

            0xA0 => return .{ .note_aftertouch = .{
                .channel = parse_channel(status),
                .key = bytes[1],
                .pressure = bytes[2],
            } },

            0xB0 => return .{ .controller_change = .{
                .channel = parse_channel(status),
                .controller = bytes[1],
                .value = bytes[2],
            } },

            0xC0 => return .{ .program_change = .{
                .channel = parse_channel(status),
                .program = bytes[1],
            } },

            0xD0 => return .{ .channel_aftertouch = .{
                .channel = parse_channel(status),
                .pressure = bytes[1],
            } },

            0xE0 => return .{ .pitch_wheel_change = .{
                .channel = parse_channel(status),
                .value = (@as(u16, bytes[1]) << 7) | bytes[2],
            } },

            else => {},
        }

        switch (status) {
            0xFF => return .{ .meta_event = try MetaEvent.parse(bytes) },

            else => return error.Unimplemented,
        }
    }
};

pub const MetaEvent = union(enum) {
    sequence_number: struct { number: u16 },
    text: struct { text: []const u8 },
    copyright_notice: struct { text: []const u8 },
    sequence_name: struct { text: []const u8 },
    instrument_name: struct { text: []const u8 },
    lyric: struct { text: []const u8 },
    marker: struct { text: []const u8 },
    cue_point: struct { text: []const u8 },
    midi_channel_prefix: struct { channel: u8 },
    end_of_track: void,
    set_tempo: struct { microseconds_per_quarter_note: u24 },
    smtpe_offset: struct { hour: u8, minute: u8, second: u8, frame: u8, sub_frame: u8 },
    time_signature: struct { numerator: u8, denominator: u8, metro: u8, thirty_seconds: u8 },
    key_signature: struct { key: u8, scale: u8 },
    sequencer_specific: struct { data: []const u8 },

    pub fn len(self: MetaEvent) usize {
        return switch (self) {
            .sequence_number => 4,
            .text => |s| s.text.len + 3,
            .copyright_notice => |s| s.text.len + 3,
            .sequence_name => |s| s.text.len + 3,
            .instrument_name => |s| s.text.len + 3,
            .lyric => |s| s.text.len + 3,
            .marker => |s| s.text.len + 3,
            .cue_point => |s| s.text.len + 3,
            .midi_channel_prefix => 3,
            .end_of_track => 1,
            .set_tempo => 5,
            .smtpe_offset => 7,
            .time_signature => 6,
            .key_signature => 4,
            .sequencer_specific => |s| s.data.len + 3,
        };
    }

    pub fn parse(bytes: []const u8) !MetaEvent {
        const meta_event_type = bytes[1];

        switch (meta_event_type) {
            0x00 => return .{ .sequence_number = .{ .number = (@as(u16, bytes[2]) << 7) | bytes[3] } },

            0x01 => {
                const text = parse_text(bytes);
                return .{ .text = .{ .text = text } };
            },

            0x02 => {
                const text = parse_text(bytes);
                return .{ .copyright_notice = .{ .text = text } };
            },

            0x03 => {
                const text = parse_text(bytes);
                return .{ .sequence_name = .{ .text = text } };
            },

            0x04 => {
                const text = parse_text(bytes);
                return .{ .instrument_name = .{ .text = text } };
            },

            0x05 => {
                const text = parse_text(bytes);
                return .{ .lyric = .{ .text = text } };
            },

            0x06 => {
                const text = parse_text(bytes);
                return .{ .marker = .{ .text = text } };
            },

            0x07 => {
                const text = parse_text(bytes);
                return .{ .cue_point = .{ .text = text } };
            },

            0x20 => {
                const channel = bytes[2];
                return .{ .midi_channel_prefix = .{ .channel = channel } };
            },

            0x2F => return .{ .end_of_track = {} },

            0x51 => {
                const microseconds_per_quarter_note = (@as(u24, bytes[2]) << 16) | (@as(u24, bytes[3]) << 8) | bytes[4];
                return .{ .set_tempo = .{ .microseconds_per_quarter_note = microseconds_per_quarter_note } };
            },

            0x54 => {
                const hour = bytes[2];
                const minute = bytes[3];
                const second = bytes[4];
                const frame = bytes[5];
                const sub_frame = bytes[6];
                return .{ .smtpe_offset = .{ .hour = hour, .minute = minute, .second = second, .frame = frame, .sub_frame = sub_frame } };
            },

            0x58 => {
                const numerator = bytes[2];
                const denominator = bytes[3];
                const metro = bytes[4];
                const thirty_seconds = bytes[5];
                return .{ .time_signature = .{ .numerator = numerator, .denominator = denominator, .metro = metro, .thirty_seconds = thirty_seconds } };
            },

            0x59 => {
                const key = bytes[2];
                const scale = bytes[3];
                return .{ .key_signature = .{ .key = key, .scale = scale } };
            },

            0x7F => {
                const data_length = try utils.readVariableLengthQuantity(bytes[2..]);
                const data = bytes[3 .. 3 + data_length];
                return .{ .sequencer_specific = .{ .data = data } };
            },

            else => return error.Unimplemented,
        }
    }

    fn parse_text(bytes: []const u8) []const u8 {
        const text_length = bytes[2];
        const text = bytes[3 .. 3 + text_length];
        return text;
    }
};

test "midi channel events" {
    const testing = std.testing;

    // NoteOff
    {
        const bytes = [_]u8{ 0x81, 10, 60 };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqual(MidiEvent{ .note_off = .{ .channel = 1, .key = 10, .velocity = 60 } }, message);
        try testing.expectEqual(bytes.len, message.len());
    }

    // NoteOn
    {
        const bytes = [_]u8{ 0x9A, 1, 127 };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqual(MidiEvent{ .note_on = .{ .channel = 10, .key = 1, .velocity = 127 } }, message);
    }

    // NoteAftertouch
    {
        const bytes = [_]u8{ 0xAF, 10, 60 };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqual(MidiEvent{ .note_aftertouch = .{ .channel = 15, .key = 10, .pressure = 60 } }, message);
    }

    // ControlChange
    {
        const bytes = [_]u8{ 0xB0, 4, 60 };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqual(MidiEvent{ .controller_change = .{ .channel = 0, .controller = 4, .value = 60 } }, message);
    }

    // ProgramChange
    {
        const bytes = [_]u8{ 0xC0, 10 };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqual(MidiEvent{ .program_change = .{ .channel = 0, .program = 10 } }, message);
    }

    // ChannelAftertouch
    {
        const bytes = [_]u8{ 0xD0, 125 };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqual(MidiEvent{ .channel_aftertouch = .{ .channel = 0, .pressure = 125 } }, message);
    }

    // PitchWheelChange
    {
        const bytes = [_]u8{ 0xE0, 125, 125 };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqual(MidiEvent{ .pitch_wheel_change = .{ .channel = 0, .value = 16125 } }, message);
    }
}

test "midi meta events" {
    const testing = std.testing;

    // SequenceNumber
    {
        const bytes = [_]u8{ 0xFF, 0x00, 125, 125 };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqual(MidiEvent{ .meta_event = .{ .sequence_number = .{ .number = 16125 } } }, message);
        try testing.expectEqual(bytes.len, message.len());
    }

    // Text
    {
        const bytes = [_]u8{ 0xFF, 0x01, 4, 'j', 'a', 'k', 'e' };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqualDeep(MidiEvent{ .meta_event = .{ .text = .{ .text = "jake" } } }, message);
        try testing.expectEqual(bytes.len, message.len());
    }

    // CopyrightNotice
    {
        const bytes = [_]u8{ 0xFF, 0x02, 5, 'h', 'e', 'l', 'l', 'o' };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqualDeep(MidiEvent{ .meta_event = .{ .copyright_notice = .{ .text = "hello" } } }, message);
        try testing.expectEqual(bytes.len, message.len());
    }

    // SequenceName
    {
        const bytes = [_]u8{ 0xFF, 0x03, 4, 'j', 'a', 'k', 'e' };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqualDeep(MidiEvent{ .meta_event = .{ .sequence_name = .{ .text = "jake" } } }, message);
        try testing.expectEqual(bytes.len, message.len());
    }

    // InstrumentName
    {
        const bytes = [_]u8{ 0xFF, 0x04, 4, 'j', 'a', 'k', 'e' };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqualDeep(MidiEvent{ .meta_event = .{ .instrument_name = .{ .text = "jake" } } }, message);
        try testing.expectEqual(bytes.len, message.len());
    }

    // Lyric
    {
        const bytes = [_]u8{ 0xFF, 0x05, 4, 'j', 'a', 'k', 'e' };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqualDeep(MidiEvent{ .meta_event = .{ .lyric = .{ .text = "jake" } } }, message);
        try testing.expectEqual(bytes.len, message.len());
    }

    // Marker
    {
        const bytes = [_]u8{ 0xFF, 0x06, 4, 'j', 'a', 'k', 'e' };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqualDeep(MidiEvent{ .meta_event = .{ .marker = .{ .text = "jake" } } }, message);
        try testing.expectEqual(bytes.len, message.len());
    }

    // CuePoint
    {
        const bytes = [_]u8{ 0xFF, 0x07, 4, 'j', 'a', 'k', 'e' };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqualDeep(MidiEvent{ .meta_event = .{ .cue_point = .{ .text = "jake" } } }, message);
        try testing.expectEqual(bytes.len, message.len());
    }

    // MidiChannelPrefix
    {
        const bytes = [_]u8{ 0xFF, 0x20, 4 };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqualDeep(MidiEvent{ .meta_event = .{ .midi_channel_prefix = .{ .channel = 4 } } }, message);
        try testing.expectEqual(bytes.len, message.len());
    }

    // EndOfTrack
    {
        const bytes = [_]u8{ 0xFF, 0x2F };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqualDeep(MidiEvent{ .meta_event = .{ .end_of_track = {} } }, message);
        try testing.expectEqual(1, message.len());
    }

    // SetTempo
    {
        const bytes = [_]u8{ 0xFF, 0x51, 0x02, 0x10, 0x00 };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqualDeep(MidiEvent{ .meta_event = .{ .set_tempo = .{ .microseconds_per_quarter_note = 135168 } } }, message);
        try testing.expectEqual(bytes.len, message.len());
    }

    // SMPTEOffset
    {
        const bytes = [_]u8{ 0xFF, 0x54, 1, 2, 3, 4, 5 };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqualDeep(MidiEvent{ .meta_event = .{ .smtpe_offset = .{ .hour = 1, .minute = 2, .second = 3, .frame = 4, .sub_frame = 5 } } }, message);
        try testing.expectEqual(bytes.len, message.len());
    }

    // TimeSignature
    {
        const bytes = [_]u8{ 0xFF, 0x58, 123, 234, 242, 12 };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqualDeep(MidiEvent{ .meta_event = .{ .time_signature = .{ .numerator = 123, .denominator = 234, .metro = 242, .thirty_seconds = 12 } } }, message);
        try testing.expectEqual(bytes.len, message.len());
    }

    // KeySignature
    {
        const bytes = [_]u8{ 0xFF, 0x59, 123, 234 };
        const message = try MidiEvent.parse(&bytes);
        try testing.expectEqualDeep(MidiEvent{ .meta_event = .{ .key_signature = .{ .key = 123, .scale = 234 } } }, message);
        try testing.expectEqual(bytes.len, message.len());
    }

    // SequencerSpecific
    {
        const bytes = [_]u8{ 0xFF, 0x7F, 0x04, 0x00, 0x00, 0x00, 0x00, 0xFF };
        const message = try MidiEvent.parse(&bytes);

        try testing.expectEqualDeep(MidiEvent{ .meta_event = .{ .sequencer_specific = .{ .data = &[_]u8{ 0x00, 0x00, 0x00, 0x00 } } } }, message);
        try testing.expectEqual(7, message.len());
    }
}
