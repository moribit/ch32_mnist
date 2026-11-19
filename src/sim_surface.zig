pub var frame: [1024]u8 = @splat(0);
pub fn pixel(x: i16, y: i16, on: bool) void {
    if (x < 0 or y < 0 or x >= 128 or y >= 64) return;
    const i: usize = @intCast(@divTrunc(y, 8) * 128 + x);
    const bit = @as(u8, 1) << @as(u3, @intCast(@mod(y, 8)));
    if (on) frame[i] |= bit else frame[i] &= ~bit;
}
