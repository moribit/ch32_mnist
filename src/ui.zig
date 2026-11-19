const App = @import("app.zig").App;
// Original compact 3x5 glyphs, LSB at top.
fn glyph(c: u8) [3]u8 {
    return switch (c) {
        '0' => .{ 31, 17, 31 },
        '1' => .{ 18, 31, 16 },
        '2' => .{ 29, 21, 23 },
        '3' => .{ 21, 21, 31 },
        '4' => .{ 7, 4, 31 },
        '5' => .{ 23, 21, 29 },
        '6' => .{ 31, 21, 29 },
        '7' => .{ 1, 1, 31 },
        '8' => .{ 31, 21, 31 },
        '9' => .{ 23, 21, 31 },
        'A' => .{ 30, 5, 30 },
        'B' => .{ 31, 21, 10 },
        'C' => .{ 31, 17, 17 },
        'D' => .{ 31, 17, 14 },
        'E' => .{ 31, 21, 17 },
        'F' => .{ 31, 5, 1 },
        'G' => .{ 31, 17, 29 },
        'H' => .{ 31, 4, 31 },
        'I' => .{ 17, 31, 17 },
        'J' => .{ 24, 16, 31 },
        'K' => .{ 31, 4, 27 },
        'L' => .{ 31, 16, 16 },
        'M' => .{ 31, 2, 31 },
        'N' => .{ 31, 1, 30 },
        'O' => .{ 31, 17, 31 },
        'P' => .{ 31, 5, 7 },
        'Q' => .{ 15, 9, 31 },
        'R' => .{ 31, 13, 23 },
        'S' => .{ 23, 21, 29 },
        'T' => .{ 1, 31, 1 },
        'U' => .{ 31, 16, 31 },
        'V' => .{ 15, 16, 15 },
        'W' => .{ 31, 8, 31 },
        'X' => .{ 27, 4, 27 },
        'Y' => .{ 3, 28, 3 },
        'Z' => .{ 25, 21, 19 },
        '-' => .{ 4, 4, 4 },
        ':' => .{ 0, 10, 0 },
        '>' => .{ 17, 10, 4 },
        else => .{ 0, 0, 0 },
    };
}
pub fn text(comptime D: type, x: i16, y: i16, s: []const u8, scale: i16) void {
    textColor(D, x, y, s, scale, true);
}
fn textColor(comptime D: type, x: i16, y: i16, s: []const u8, scale: i16, on: bool) void {
    for (s, 0..) |c, i| {
        for (glyph(c), 0..) |col, xx| {
            for (0..5) |yy| {
                if (col & (@as(u8, 1) << @intCast(yy)) == 0) continue;
                for (0..@as(usize, @intCast(scale))) |sy| {
                    for (0..@as(usize, @intCast(scale))) |sx| {
                        D.pixel(x + @as(i16, @intCast(i)) * 4 * scale + @as(i16, @intCast(xx)) * scale + @as(i16, @intCast(sx)), y + @as(i16, @intCast(yy)) * scale + @as(i16, @intCast(sy)), on);
                    }
                }
            }
        }
    }
}

fn number(comptime D: type, x: i16, y: i16, v: i32) void {
    var buf: [12]u8 = undefined;
    var n: u32 = @intCast(@abs(v));
    var end: usize = buf.len;
    while (true) {
        end -= 1;
        buf[end] = '0' + @as(u8, @intCast(n % 10));
        n /= 10;
        if (n == 0) break;
    }
    if (v < 0) {
        end -= 1;
        buf[end] = '-';
    }
    text(D, x, y, buf[end..], 1);
}
pub fn fillRect(comptime D: type, x: i16, y: i16, w: i16, h: i16, on: bool) void {
    var yy = y;
    while (yy < y + h) : (yy += 1) {
        var xx = x;
        while (xx < x + w) : (xx += 1) D.pixel(xx, yy, on);
    }
}
const digits = [10][5]u8{
    .{ 0x3e, 0x51, 0x49, 0x45, 0x3e }, .{ 0, 0x42, 0x7f, 0x40, 0 },
    .{ 0x62, 0x51, 0x49, 0x49, 0x46 }, .{ 0x22, 0x41, 0x49, 0x49, 0x36 },
    .{ 0x18, 0x14, 0x12, 0x7f, 0x10 }, .{ 0x27, 0x45, 0x45, 0x45, 0x39 },
    .{ 0x3e, 0x49, 0x49, 0x49, 0x32 }, .{ 1, 0x71, 9, 5, 3 },
    .{ 0x36, 0x49, 0x49, 0x49, 0x36 }, .{ 0x26, 0x49, 0x49, 0x49, 0x3e },
};
pub fn predictionDigit(comptime D: type, digit: u8) void {
    for (digits[digit], 0..) |column, x| for (0..7) |y| {
        if (column & (@as(u8, 1) << @intCast(y)) != 0)
            fillRect(D, 84 + @as(i16, @intCast(x)) * 4, 25 + @as(i16, @intCast(y)) * 4, 4, 4, true);
    };
}
fn overlay(comptime D: type, a: *const App, x: i16, y: i16) void {
    if (x < 3 or x > 52 or y < 3 or y > 52) return;
    const white = x >= 4 and x < 52 and y >= 4 and y < 52 and a.bitmap.get(@intCast(@divTrunc(x - 4, 3)), @intCast(@divTrunc(y - 4, 3)));
    D.pixel(x, y, !white);
}
fn overlayLine(comptime D: type, a: *const App, x: i16, y: i16, dx: i16, dy: i16, len: i16) void {
    var i: i16 = 0;
    while (i < len) : (i += 1) overlay(D, a, x + dx * i, y + dy * i);
}
fn drawCanvas(comptime D: type, a: *const App) void {
    for (0..16) |y| for (0..16) |x| {
        if (a.bitmap.get(@intCast(x), @intCast(y))) fillRect(D, 4 + @as(i16, @intCast(x)) * 3, 4 + @as(i16, @intCast(y)) * 3, 3, 3, true);
    };
    fillRect(D, 2, 2, 52, 1, true);
    fillRect(D, 2, 53, 52, 1, true);
    fillRect(D, 2, 2, 1, 52, true);
    fillRect(D, 53, 2, 1, 52, true);
    const cx: i16 = 5 + @as(i16, a.turtle.x) * 3;
    const cy: i16 = 5 + @as(i16, a.turtle.y) * 3;
    overlayLine(D, a, cx - 2, cy - 2, 1, 0, 5);
    overlayLine(D, a, cx - 2, cy + 2, 1, 0, 5);
    overlayLine(D, a, cx - 2, cy - 2, 0, 1, 5);
    overlayLine(D, a, cx + 2, cy - 2, 0, 1, 5);
    const T = @import("canvas.zig").Turtle;
    const dx: i16 = T.dx[a.turtle.direction];
    const dy: i16 = T.dy[a.turtle.direction];
    // At an outward edge, finish the arrow at the cursor rather than clip its head.
    const outward = cx + dx * 6 < 3 or cx + dx * 6 > 52 or cy + dy * 6 < 3 or cy + dy * 6 > 52;
    const tx = cx + if (outward) 0 else dx * 6;
    const ty = cy + if (outward) 0 else dy * 6;
    const bx = tx - dx * 6;
    const by = ty - dy * 6;
    overlayLine(D, a, bx, by, dx, dy, 7);
    const wing1 = a.turtle.direction +% 3;
    const wing2 = a.turtle.direction +% 5;
    overlayLine(D, a, tx, ty, T.dx[wing1], T.dy[wing1], 3);
    overlayLine(D, a, tx, ty, T.dx[wing2], T.dy[wing2], 3);
}
fn drawDraw(comptime D: type, a: *const App) void {
    drawCanvas(D, a);
    fillRect(D, 57, 0, 1, 64, true);
    text(D, 65, 2, "ZINN MNIST", 1);
    fillRect(D, 61, 11, 64, 1, true);
    text(D, 73, 16, "PREDICTION", 1);
    if (a.valid) predictionDigit(D, a.prediction()) else if (a.pending and !a.bitmap.empty()) {
        inline for (.{ 80, 92, 104 }) |x| fillRect(D, x, 39, 4, 4, true);
    } else {
        fillRect(D, 82, 36, 9, 3, true);
        fillRect(D, 98, 36, 9, 3, true);
    }
    fillRect(D, 61, 56, 64, 1, true);
    text(D, 84, 59, "HOLD: MENU", 1);
    const circle = if (a.turtle.down) [5]u8{ 14, 31, 31, 31, 14 } else [5]u8{ 14, 17, 17, 17, 14 };
    for (circle, 0..) |column, x| for (0..5) |y| {
        if (column & (@as(u8, 1) << @intCast(y)) != 0) D.pixel(2 + @as(i16, @intCast(x)), 58 + @as(i16, @intCast(y)), true);
    };
    text(D, 10, 58, if (a.turtle.down) "PEN DOWN" else "PEN UP", 1);
}
pub fn draw(comptime D: type, a: *const App) void {
    if (a.menu) {
        text(D, 0, 0, "MENU", 1);
        const labels = [7][]const u8{ "RESUME", if (a.turtle.down) "PEN UP" else "PEN DOWN", "UNDO", "PREDICT", "CLEAR", "SAMPLE", "INSPECT" };
        for (labels, 0..) |s, i| {
            const y: i16 = 9 + @as(i16, @intCast(i)) * 8;
            if (i == a.item) fillRect(D, 0, y - 1, 128, 7, true);
            textColor(D, 8, y, s, 1, i != a.item);
        }
        return;
    }
    if (a.mode == .draw) {
        drawDraw(D, a);
        return;
    }
    if (a.mode == .inspect) {
        if (!a.valid) {
            text(D, 0, 0, "NO RESULT", 1);
            return;
        }
        text(D, 0, 0, "LOGITS NOT PROB", 1);
        text(D, 88, 0, "P:", 1);
        number(D, 100, 0, a.prediction());
        var lo: i16 = 127;
        var hi: i16 = -128;
        for (a.output) |v| {
            lo = @min(lo, v);
            hi = @max(hi, v);
        }
        for (a.output, 0..) |v, i| {
            const x: i16 = if (i < 5) 0 else 64;
            const y: i16 = 10 + @as(i16, @intCast(i % 5)) * 8;
            number(D, x, y, @intCast(i));
            if (i == a.selected) {
                D.pixel(x, y + 6, true);
                D.pixel(x + 1, y + 6, true);
                D.pixel(x + 2, y + 6, true);
            }
            number(D, x + 9, y, v);
            const w: i16 = if (hi == lo) 0 else @intCast(@divTrunc((@as(i32, v) - lo) * 26, hi - lo));
            var j: i16 = 0;
            while (j < w) : (j += 1) D.pixel(x + 34 + j, y + 2, true);
        }
        text(D, 0, 52, "MARGIN", 1);
        if (a.valid) number(D, 28, 52, a.margin());
        text(D, 64, 52, "US", 1);
        if (a.cycles_valid) number(D, 76, 52, @intCast(a.cycles / 48)) else text(D, 76, 52, "--", 1);
        if (@import("options").trace) {
            for (a.trace.layer(0), 0..) |v, i| {
                if (v > 0) {
                    const x: i16 = 88 + @as(i16, @intCast(i % 8)) * 5;
                    const y: i16 = 56 + @as(i16, @intCast(i / 8)) * 2;
                    D.pixel(x, y, true);
                    if (v > 42) D.pixel(x + 1, y, true);
                    if (v > 84) D.pixel(x + 2, y, true);
                }
            }
        }
        return;
    }
    text(D, 63, 0, "ZINN MNIST", 1);
    for (0..16) |y| for (0..16) |x| {
        const on = if (a.mode == .sample) a.input[y * 16 + x] > 0 else a.bitmap.get(@intCast(x), @intCast(y));
        if (on) for (0..3) |sy| for (0..3) |sx| {
            D.pixel(2 + @as(i16, @intCast(x * 3 + sx)), 10 + @as(i16, @intCast(y * 3 + sy)), true);
        };
    };
    text(D, 0, 0, "SAMPLE", 1);
    number(D, 63, 12, a.sample_index);
    text(D, 63, 21, "US", 1);
    if (a.cycles_valid) number(D, 76, 21, @intCast(a.cycles / 48)) else text(D, 76, 21, "--", 1);
    if (a.valid) text(D, 63, 54, if (a.reference_ok) "PASS" else "FAIL", 1);
    if (a.valid) {
        const b = [1]u8{'0' + a.prediction()};
        text(D, 78, 33, &b, 4);
    } else text(D, 78, 40, "--", 2);
    text(D, 0, 60, "HOLD: MENU", 1);
}
