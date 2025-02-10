const std = @import("std");
const lib = @import("lib.zig");
const AddressedQuadlet = lib.AddressedQuadlet;
const Bytes = lib.Bytes;
const SourceId = lib.SourceId;
const Offset = lib.Offset;

fn random(comptime T: type, ptr: *std.rand.Xoshiro256) T {
    return ptr.*.random().intRangeAtMost(T, 0, 1000);
}

fn randomInit() std.rand.Xoshiro256 {
    return std.rand.Xoshiro256.init(@bitCast(std.time.timestamp()));
}

fn getHost(allocator: std.mem.Allocator) ![]const u8 {
    return try std.process.getEnvVarOwned(allocator, "HOST");
}

test "Quadlet" {
    // defer testAllocator.free();
    var rand = randomInit();
    var testAllocator = std.testing.allocator;
    const host = getHost(testAllocator) catch |err| {
        if (err == std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound) {
            if (@import("builtin").os.tag == .windows) {
                std.debug.print("Error: HOST environment variable not set\n", .{});
                std.debug.print("set HOST using: $env:HOST = \"<HOST>\"\n", .{});
            } else {
                std.debug.print("Error: HOST environment variable not set\n", .{});
            }
            // std.debug.print("Error: {}\n", .{err});
            return;
        }
        return;
    };
    defer testAllocator.free(host);
    const mmpAddress = try std.net.Address.parseIp4(host, 2001);
    const stream = try std.net.tcpConnectToAddress(mmpAddress);

    const myQuadlet = AddressedQuadlet(i32, 1, 0xFFFF_F0D8_1000);
    const value = random(i32, &rand);

    try myQuadlet.put(&stream, 3, value);
    var buffer: [1024]u8 = [_]u8{0} ** 1024;
    var bytesRead = try stream.read(&buffer);

    try myQuadlet.get(&stream, 2);
    buffer = [_]u8{0} ** 1024;
    bytesRead = try stream.read(&buffer);
}

test "bytes" {
    const f = 10.01;
    const fBytes: [4]u8 = Bytes.asBytes([4]u8, @as(f32, f));
    const f2: f32 = Bytes.asf32(fBytes);
    try std.testing.expectEqual(10.01, f2);

    const int1 = 10;
    const iBytes: [4]u8 = Bytes.asBytes([4]u8, @as(i32, int1));
    try std.testing.expectEqual(10, iBytes[3]);
    const int2: i32 = Bytes.asi32(iBytes);
    try std.testing.expectEqual(10, int2);

    const sourceId: u16 = 1;
    const sourceIdBytes: [2]u8 = SourceId.asBytes(sourceId);
    const sourceId2: u16 = SourceId.asInt(sourceIdBytes);
    try std.testing.expectEqual(sourceId, sourceId2);

    const offset: u64 = 0xFFFF_F0D8_1000;
    const offsetBytes = Offset.asBytes(offset);
    const offset2 = Offset.asInt(offsetBytes);
    try std.testing.expectEqual(offset, offset2);
}
