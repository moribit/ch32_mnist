const Canvas = @import("canvas.zig").Canvas;
const generated = @import("mnist_model");
const L = generated.Model.Layer(0);
pub const Method = enum { direct, centered, normalized, antialiased };
// Compile-time float metadata; the firmware only executes integer arithmetic.
pub const white: i8 = @intFromFloat(@min(127, @max(-128, @round(1.0 / generated.input_scale) + L.input_zero)));
pub const zero: i8 = L.input_zero;
fn quantize(coverage: u32) i8 {
    return @intCast(@as(i32, zero) + @divTrunc((@as(i32, white) - zero) * @as(i32, @intCast(coverage)) + 8, 16));
}
pub fn run(c: *const Canvas, out: *[256]i8, method: Method) bool {
    @memset(out, zero);
    const box = c.bounds() orelse return false;
    const longest = @max(box.w, box.h);
    const w: i32 = if (method == .normalized or method == .antialiased) @max(1, @divTrunc(@as(i32, box.w) * 12 + longest / 2, longest)) else box.w;
    const h: i32 = if (method == .normalized or method == .antialiased) @max(1, @divTrunc(@as(i32, box.h) * 12 + longest / 2, longest)) else box.h;
    const ox: i32 = if (method == .direct) box.x else @divTrunc(16 - w, 2);
    const oy: i32 = if (method == .direct) box.y else @divTrunc(16 - h, 2);
    for (0..16) |y| for (0..16) |x| {
        const xx: i32 = @intCast(x);
        const yy: i32 = @intCast(y);
        if (xx < ox or yy < oy or xx >= ox + w or yy >= oy + h) continue;
        var hits: u32 = 0;
        if (method == .antialiased) {
            for (0..4) |sy| for (0..4) |sx| {
                const px = box.x + @divTrunc(((xx - ox) * 8 + @as(i32, @intCast(sx)) * 2 + 1) * box.w, w * 8);
                const py = box.y + @divTrunc(((yy - oy) * 8 + @as(i32, @intCast(sy)) * 2 + 1) * box.h, h * 8);
                if (c.get(@intCast(px), @intCast(py))) hits += 1;
            };
        } else {
            const px = box.x + @divTrunc((xx - ox) * box.w, w);
            const py = box.y + @divTrunc((yy - oy) * box.h, h);
            hits = if (c.get(@intCast(px), @intCast(py))) 16 else 0;
        }
        out[y * 16 + x] = quantize(hits);
    };
    return true;
}
