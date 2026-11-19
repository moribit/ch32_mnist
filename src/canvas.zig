const std = @import("std");
pub const Canvas = struct {
    pixels: [32]u8 = @splat(0),
    pub fn get(self: *const Canvas, x: u8, y: u8) bool {
        if (x >= 16 or y >= 16) return false;
        return self.pixels[@as(usize, y) * 2 + x / 8] & (@as(u8, 1) << @intCast(x % 8)) != 0;
    }
    pub fn set(self: *Canvas, x: i16, y: i16, on: bool) void {
        if (x < 0 or y < 0 or x >= 16 or y >= 16) return;
        const i: usize = @intCast(y * 2 + @divTrunc(x, 8));
        const mask = @as(u8, 1) << @as(u3, @intCast(@mod(x, 8)));
        if (on) self.pixels[i] |= mask else self.pixels[i] &= ~mask;
    }
    pub fn clear(self: *Canvas) void {
        self.* = .{};
    }
    pub fn empty(self: *const Canvas) bool {
        for (self.pixels) |b| {
            if (b != 0) return false;
        }
        return true;
    }
    pub const Box = struct { x: u8, y: u8, w: u8, h: u8 };
    pub fn bounds(self: *const Canvas) ?Box {
        var x0: u8 = 16;
        var y0: u8 = 16;
        var x1: u8 = 0;
        var y1: u8 = 0;
        for (0..16) |y| for (0..16) |x| {
            if (self.get(@intCast(x), @intCast(y))) {
                x0 = @min(x0, @as(u8, @intCast(x)));
                y0 = @min(y0, @as(u8, @intCast(y)));
                x1 = @max(x1, @as(u8, @intCast(x)));
                y1 = @max(y1, @as(u8, @intCast(y)));
            }
        };
        if (x0 == 16) return null;
        return .{ .x = x0, .y = y0, .w = x1 - x0 + 1, .h = y1 - y0 + 1 };
    }
    pub fn stamp(self: *Canvas, x: i16, y: i16, thick: bool) void {
        self.set(x, y, true);
        if (thick) {
            self.set(x + 1, y, true);
            self.set(x, y + 1, true);
            self.set(x + 1, y + 1, true);
        }
    }
    pub fn line(self: *Canvas, ax: i16, ay: i16, bx: i16, by: i16) void {
        var x = ax;
        var y = ay;
        const dx: i16 = @intCast(@abs(bx - ax));
        const dy: i16 = -@as(i16, @intCast(@abs(by - ay)));
        const sx: i16 = if (ax < bx) 1 else -1;
        const sy: i16 = if (ay < by) 1 else -1;
        var e = dx + dy;
        while (true) {
            self.set(x, y, true);
            if (x == bx and y == by) break;
            const ee = e * 2;
            if (ee >= dy) {
                e += dy;
                x += sx;
            }
            if (ee <= dx) {
                e += dx;
                y += sy;
            }
        }
    }
};
pub const Turtle = struct {
    x: u8 = 7,
    y: u8 = 7,
    direction: u3 = 0,
    down: bool = true,
    pub const dx = [8]i8{ 0, 1, 1, 1, 0, -1, -1, -1 };
    pub const dy = [8]i8{ -1, -1, 0, 1, 1, 1, 0, -1 };
    pub fn rotate(self: *Turtle, d: i8) void {
        self.direction = @intCast(@mod(@as(i16, self.direction) + d, 8));
    }
    pub fn advance(self: *Turtle, c: *Canvas) bool {
        const x: u8 = @intCast(std.math.clamp(@as(i16, self.x) + dx[self.direction], 0, 15));
        const y: u8 = @intCast(std.math.clamp(@as(i16, self.y) + dy[self.direction], 0, 15));
        if (x == self.x and y == self.y) return false;
        if (self.down) c.line(self.x, self.y, x, y);
        self.x = x;
        self.y = y;
        return self.down;
    }
};
