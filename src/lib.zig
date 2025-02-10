const std = @import("std");
const net = std.net;
const Stream = std.net.Stream;

const ZmmpError = enum {};

pub fn AddressedQuadlet(comptime T: type, sourceId: u16, address: u64) type {
    const sourceIdBytes = SourceId.asBytes(sourceId);
    const addressBytes = Offset.asBytes(address);
    return struct {
        sourceId: [2]u8 = sourceIdBytes,
        address: [6]u8 = addressBytes,
        pub fn put(stream: *const Stream, id: u8, value: T) !void {
            return putQuadlet(T, stream, &sourceIdBytes, &addressBytes, id, value);
        }
        pub fn get(stream: *const Stream, id: u8) !void {
            return getQuadlet(stream, &sourceIdBytes, &addressBytes, id);
        }
    };
}

pub fn AnonymousQaudlet(comptime T: type, sourceId: u16) type {
    const sourceIdBytes = SourceId.asBytes(sourceId);
    return struct {
        sourceId: [2]u8 = sourceIdBytes,
        pub fn put(stream: *const Stream, addr: u64, id: u8, value: T) !void {
            const addressBytes = Offset.asBytes(addr);
            return putQuadlet(T, stream, &sourceIdBytes, &addressBytes, id, value);
        }
        pub fn get(stream: *const Stream, addr: u64, id: u8) !void {
            const addressBytes = Offset.asBytes(addr);
            return getQuadlet(stream, &sourceIdBytes, &addressBytes, id);
        }
    };
}

fn putQuadlet(comptime T: type, stream: *const Stream, sourceId: *const [2]u8, address: *const [6]u8, id: u8, value: T) !void {
    const tLabel = id << 2;
    const tCode = 0x00;
    const valueBytes: [4]u8 = Bytes.asBytes([4]u8, value);
    const data: [16]u8 = [16]u8{
        0x00,          0x00,          tLabel,        tCode,
        sourceId[0],   sourceId[1],   address[0],    address[1],
        address[2],    address[3],    address[4],    address[5],
        valueBytes[0], valueBytes[1], valueBytes[2], valueBytes[3],
    };
    _ = try stream.write(&data);
}

fn getQuadlet(stream: *const Stream, sourceId: *const [2]u8, address: *const [6]u8, id: u8) !void {
    const tLabel = id << 2;
    const tCode = 0x04 << 4;
    const data: [12]u8 = [12]u8{ 0x00, 0x00, tLabel, tCode, sourceId[0], sourceId[1], address[0], address[1], address[2], address[3], address[4], address[5] };
    _ = try stream.write(&data);
}

fn UnpackedResponse(data: *[]u8) !void {
    const tLabel = data[2] >> 2;
    const tCode = data[3] >> 4;
    const sourceId: u16 = std.mem.nativeToBig(@bitCast(data[4..6]));
    const rCode = data[7] >> 4;
    if (tCode == 1) {
        // Write Quadlet or Block Response
        return struct {
            tLabel: u8 = tLabel,
            tCode: u8 = tCode,
            sourceId: u16 = sourceId,
            rCode: u8 = rCode,
        };
    } else if (tCode == 6) {
        // Read Quadlet Response
        return struct {
            tLabel: u8 = tLabel,
            tCode: u8 = tCode,
            sourceId: u16 = sourceId,
            rCode: u8 = rCode,
            data: *[]u8 = data[12..],
        };
    } else if (tCode == 7) {
        const length = std.mem.fromBytes(u16, data[12..14]);
        // Read Block Response
        return struct {
            tLabel: u8 = tLabel,
            tCode: u8 = tCode,
            sourceId: u16 = sourceId,
            rCode: u8 = rCode,
            length: u16 = length,
            data: *[]u8 = data[16..],
        };
    } else {
        return error.UnknownResponseCoe;
    }

    return UnpackedResponse{ .tLabel = tLabel, .tCode = tCode, .sourceId = sourceId, .rCode = rCode, .data = data[12..] };
}

pub const Offset = struct {
    pub fn asInt(data: [6]u8) u64 {
        const bytes: [8]u8 = [8]u8{ 0, 0, data[0], data[1], data[2], data[3], data[4], data[5] };
        return Bytes.asu64(bytes);
    }
    pub fn asBytes(offset: u64) [6]u8 {
        const bytes = Bytes.asBytes([8]u8, offset);
        return [6]u8{ bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7] };
    }
};

pub const SourceId = struct {
    pub fn asInt(data: [2]u8) u16 {
        return Bytes.asu16(data);
    }
    pub fn asBytes(sourceId: u16) [2]u8 {
        return Bytes.asBytes([2]u8, sourceId);
    }
};

pub const Bytes = struct {
    pub fn asu16(data: [2]u8) u16 {
        return std.mem.bigToNative(u16, @bitCast(data));
    }
    pub fn asu32(data: [4]u8) u32 {
        return std.mem.bigToNative(u32, @bitCast(data));
    }
    pub fn asu64(data: [8]u8) u64 {
        return std.mem.bigToNative(u64, @bitCast(data));
    }
    pub fn asi32(data: [4]u8) i32 {
        return std.mem.bigToNative(i32, @bitCast(data));
    }
    pub fn asi64(data: [8]u8) i64 {
        return std.mem.bigToNative(i64, @bitCast(data));
    }
    pub fn asf32(data: [4]u8) f32 {
        const intermediary: u32 = @bitCast(data);
        const n: u32 = std.mem.nativeToBig(u32, intermediary);
        return @bitCast(n);
    }
    pub fn asBytes(comptime T: type, n: anytype) T {
        const nType = @TypeOf(n);
        return switch (nType) {
            inline i32, i64, u8, u16, u32, u64 => {
                return @bitCast(std.mem.nativeToBig(nType, n));
            },
            inline f32 => {
                const intermediary = std.mem.nativeToBig(u32, @bitCast(n));
                return @bitCast(intermediary);
            },
            inline else => {
                std.debug.print("Found unsupported type: {}.", .{nType});
                @compileError(std.fmt.comptimePrint("Found unsupported type: {}.", .{nType}));
            },
        };
    }
};
