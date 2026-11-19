const std = @import("std");
const input = @import("input.zig");
const c = @import("canvas.zig");
const pre = @import("preprocess.zig");
const application = @import("app.zig");
const gen = @import("mnist_model");
test "encoder detents, bounce, invalid transition and reversal" {
    var e: input.Encoder = .{};
    var total: i32 = 0;
    for ([_]u2{ 2, 0, 1, 3 }) |s| total += e.update(s);
    try std.testing.expectEqual(@as(i32, -1), total);
    for ([_]u2{ 1, 0, 2, 3 }) |s| total += e.update(s);
    try std.testing.expectEqual(@as(i32, 0), total);
    for ([_]u2{ 2, 3, 2, 3 }) |s| try std.testing.expectEqual(@as(i8, 0), e.update(s));
    _ = e.update(0);
    try std.testing.expectEqual(@as(u16, 1), e.invalid);
}
test "button debounce, single long press, release and wrap" {
    var b: input.Button = .{};
    try std.testing.expect(b.update(true, 0) == null);
    try std.testing.expect(b.update(false, 5) == null);
    try std.testing.expect(b.update(true, 10) == null);
    try std.testing.expect(b.update(true, 30) == null);
    try std.testing.expect(b.update(false, 90) == null);
    try std.testing.expect(b.update(false, 110).? == .click);
    try std.testing.expect(b.update(true, 200) == null);
    _ = b.update(true, 220);
    try std.testing.expect(b.update(true, 920).? == .long_press);
    try std.testing.expect(b.update(true, 2000) == null);
    _ = b.update(false, 2100);
    try std.testing.expect(b.update(false, 2120) == null);
    b = .{};
    _ = b.update(true, 0xfffffff0);
    _ = b.update(true, 10);
    _ = b.update(false, 60);
    try std.testing.expect(b.update(false, 80).? == .click);
}
test "canvas bitmap, brush, box, edge and line" {
    var bitmap: c.Canvas = .{};
    try std.testing.expect(bitmap.empty());
    bitmap.set(-1, 0, true);
    bitmap.set(16, 0, true);
    try std.testing.expect(bitmap.empty());
    bitmap.line(0, 0, 15, 15);
    try std.testing.expect(bitmap.get(15, 15));
    const box = bitmap.bounds().?;
    try std.testing.expectEqual(@as(u8, 16), box.w);
    bitmap.set(0, 0, false);
    try std.testing.expect(!bitmap.get(0, 0));
    bitmap.clear();
    bitmap.stamp(15, 15, true);
    try std.testing.expectEqual(@as(u8, 1), bitmap.bounds().?.w);
    var t: c.Turtle = .{ .x = 0, .y = 0, .direction = 7 };
    _ = t.advance(&bitmap);
    try std.testing.expectEqual(@as(u8, 0), t.x);
    try std.testing.expectEqual(@as(u8, 0), t.y);
    t.rotate(1);
    try std.testing.expectEqual(@as(u3, 0), t.direction);
}
test "preprocessing blank, translation, range and area coverage" {
    var bitmap: c.Canvas = .{};
    var out: [256]i8 = undefined;
    try std.testing.expect(!pre.run(&bitmap, &out, .direct));
    for (out) |q| try std.testing.expectEqual(pre.zero, q);
    bitmap.line(1, 1, 1, 8);
    try std.testing.expect(pre.run(&bitmap, &out, .direct));
    try std.testing.expectEqual(pre.white, out[17]);
    var centered: [256]i8 = undefined;
    _ = pre.run(&bitmap, &centered, .centered);
    var moved: c.Canvas = .{};
    moved.line(7, 5, 7, 12);
    _ = pre.run(&moved, &out, .centered);
    try std.testing.expectEqualSlices(i8, &centered, &out);
    inline for (.{ pre.Method.direct, pre.Method.centered, pre.Method.normalized, pre.Method.antialiased }) |method| {
        _ = pre.run(&bitmap, &out, method);
        for (out) |q| {
            try std.testing.expect(q >= pre.zero and q <= pre.white);
        }
    }
}
test "all generated golden logits and trace equal ordinary inference" {
    const M = gen.Model;
    var ws: M.Workspace = .{};
    var trace: M.Trace = .{};
    var out: [10]i8 = undefined;
    var plain: [10]i8 = undefined;
    for (gen.inputs, gen.expected) |values, expected| {
        M.infer(&values, &plain, &ws);
        M.inferTraced(&values, &out, &ws, &trace);
        try std.testing.expectEqualSlices(i8, &expected, &out);
        try std.testing.expectEqualSlices(i8, &plain, &out);
        try std.testing.expectEqualSlices(i8, &out, trace.layer(1));
    }
}
test "app sample, blank, dirty inference, menu, undo, source and wrap" {
    var a: application.App = .{};
    try std.testing.expectEqual(application.Mode.draw, a.mode);
    a.predict();
    try std.testing.expect(!a.valid);
    a.sample();
    try std.testing.expect(a.pending);
    a.predict();
    try std.testing.expectEqualSlices(i8, &application.expected[0], &a.output);
    const count = a.inferences;
    try std.testing.expect(!a.due(999999));
    try std.testing.expectEqual(count, a.inferences);
    a.clear();
    a.turtle.direction = 2;
    a.event(.click, 0xfffffff0);
    try std.testing.expect(a.pending);
    try std.testing.expect(!a.due(100));
    try std.testing.expect(a.due(700));
    a.event(.long_press, 700);
    a.item = 2;
    a.event(.click, 700);
    try std.testing.expect(a.bitmap.empty());
    a.clear();
    try std.testing.expect(!a.valid);
    try std.testing.expect(!a.pending);
    a.sample();
    a.predict();
    a.event(.click, 20);
    try std.testing.expectEqual(application.Mode.inspect, a.mode);
    a.event(.click, 30);
    try std.testing.expectEqual(application.Mode.draw, a.mode);
    try std.testing.expect(!a.valid);
}
test "canvas and UI only write inside display surface" {
    const S = @import("sim_surface.zig");
    var app: application.App = .{};
    inline for (.{ application.Mode.draw, application.Mode.sample, application.Mode.inspect }) |mode| {
        app.sample();
        app.predict();
        app.mode = mode;
        @memset(&S.frame, 0);
        @import("ui.zig").draw(S, &app);
    }
    app.menu = true;
    @import("ui.zig").draw(S, &app);
    try std.testing.expect(std.mem.indexOfNone(u8, &S.frame, &.{0}) != null);
}

test "menu transitions preserve input source and explicit predict is immediate" {
    var a: application.App = .{};
    a.sample();
    a.predict();
    try std.testing.expect(a.reference_ok);
    a.event(.long_press, 30);
    a.item = 1;
    a.event(.click, 40);
    try std.testing.expect(!a.source_sample);
    try std.testing.expect(!a.valid);
    a.turtle.down = true;
    a.event(.click, 50);
    const before = a.bitmap;
    a.event(.click, 60);
    a.event(.long_press, 70);
    a.item = 2;
    a.event(.click, 80);
    try std.testing.expectEqualSlices(u8, &before.pixels, &a.bitmap.pixels);
    a.event(.long_press, 90);
    a.item = 3;
    a.event(.click, 100);
    try std.testing.expect(a.due(100));
    a.predict();
    a.clear();
    for (a.trace.values) |v| try std.testing.expectEqual(@as(i8, 0), v);
}
test "long release after a blocked poll never becomes a click; AA has partial coverage" {
    var b: input.Button = .{};
    _ = b.update(true, 0);
    _ = b.update(true, 20);
    _ = b.update(false, 900);
    try std.testing.expect(b.update(false, 920).? == .long_press);
    try std.testing.expect(b.update(false, 940) == null);
    var bitmap: c.Canvas = .{};
    bitmap.line(2, 2, 6, 8);
    var values: [256]i8 = undefined;
    _ = pre.run(&bitmap, &values, .antialiased);
    var partial = false;
    for (values) |q| {
        partial = partial or (q > pre.zero and q < pre.white);
    }
    try std.testing.expect(partial);
}

test "one full cycle per detent with bounce and reversal" {
    var e: input.Encoder = .{};
    for ([_]u2{ 2, 0, 1 }) |q| try std.testing.expectEqual(@as(i8, 0), e.update(q));
    try std.testing.expectEqual(@as(i8, -1), e.update(3));
    for ([_]u2{ 1, 0, 2 }) |q| try std.testing.expectEqual(@as(i8, 0), e.update(q));
    try std.testing.expectEqual(@as(i8, 1), e.update(3));
    for ([_]u2{ 2, 3, 2, 3, 2, 0, 1 }) |q| try std.testing.expectEqual(@as(i8, 0), e.update(q));
    try std.testing.expectEqual(@as(i8, -1), e.update(3));
    _ = e.update(2);
    _ = e.update(1); // invalid jump resets partial cycle
    try std.testing.expectEqual(@as(u16, 1), e.invalid);
    for ([_]u2{ 3, 2, 0 }) |q| try std.testing.expectEqual(@as(i8, 0), e.update(q));
    try std.testing.expectEqual(@as(i8, -1), e.update(1));
}

fn drain(cn: *input.Controller, a: *application.App) void {
    while (cn.pop()) |r| a.event(r.event, r.at);
}
fn turn(cn: *input.Controller, a: *application.App, down: bool, now: u32, reverse: bool) void {
    const sequence = if (reverse) [_]u2{ 1, 0, 2, 3 } else [_]u2{ 2, 0, 1, 3 };
    for (sequence, 0..) |q, i| {
        cn.sample(q, down, now + @as(u32, @intCast(i)));
        drain(cn, a);
    }
}
test "held rotation is one undo gesture, release has no click, no long menu" {
    var a: application.App = .{};
    var cn: input.Controller = .{};
    cn.sample(3, true, 0);
    cn.sample(3, true, 20);
    drain(&cn, &a);
    const before = a.turtle;
    turn(&cn, &a, true, 30, true);
    try std.testing.expectEqual(@as(u8, 6), a.turtle.y);
    try std.testing.expectEqual(before.direction, a.turtle.direction);
    try std.testing.expect(a.stroke_active);
    try std.testing.expect(!a.due(1000));
    cn.sample(3, true, 1200);
    drain(&cn, &a);
    try std.testing.expect(!a.menu);
    cn.sample(3, false, 1210);
    cn.sample(3, false, 1230);
    drain(&cn, &a);
    try std.testing.expectEqual(@as(u8, 6), a.turtle.y);
    try std.testing.expect(!a.stroke_active);
    try std.testing.expect(a.due(1230));
    a.event(.long_press, 1240);
    a.item = 2;
    a.event(.click, 1250);
    try std.testing.expect(a.bitmap.empty());
    try std.testing.expectEqual(before, a.turtle);
}
test "stroke signs preserve direction, move path, pen-up and repeated pixels retain prediction" {
    var a: application.App = .{};
    a.event(.{ .stroke = 3 }, 10); // reverse N = south for negative, forward for positive
    try std.testing.expectEqual(@as(u8, 4), a.turtle.y);
    a.event(.{ .stroke = -2 }, 20);
    try std.testing.expectEqual(@as(u8, 6), a.turtle.y);
    try std.testing.expectEqual(@as(u3, 0), a.turtle.direction);
    a.event(.stroke_end, 30);
    a.predict();
    const count = a.inferences;
    const old = a.output;
    a.event(.{ .rotate = 2 }, 40);
    a.turtle.down = false;
    a.event(.{ .stroke = 2 }, 50);
    a.event(.stroke_end, 60);
    try std.testing.expect(a.valid);
    try std.testing.expect(!a.pending);
    try std.testing.expectEqualSlices(i8, &old, &a.output);
    try std.testing.expectEqual(count, a.inferences);
    a.event(.long_press, 70);
    a.item = 1;
    a.event(.click, 80);
    try std.testing.expect(a.valid); // pen toggle does not invalidate current image
    a.event(.long_press, 90);
    a.event(.long_press, 100);
    try std.testing.expect(a.valid);
}
test "debounce boundaries, long menu latch, queue ordering and overflow fail closed" {
    var a: application.App = .{};
    var cn: input.Controller = .{};
    cn.sample(3, true, 0);
    cn.sample(2, true, 5);
    cn.sample(0, true, 10);
    drain(&cn, &a);
    try std.testing.expectEqual(@as(u8, 7), a.turtle.y);
    try std.testing.expectEqual(@as(u3, 0), a.turtle.direction);
    cn.sample(0, true, 20);
    cn.sample(0, true, 720);
    drain(&cn, &a);
    try std.testing.expect(a.menu);
    const bitmap = a.bitmap;
    turn(&cn, &a, true, 730, false);
    try std.testing.expectEqualSlices(u8, &bitmap.pixels, &a.bitmap.pixels);
    cn.sample(3, false, 750);
    cn.sample(3, false, 770);
    drain(&cn, &a);
    try std.testing.expect(a.menu);
    cn = .{};
    a = .{};
    // Capture both directions before consumption; never collapse their order.
    for ([_]u2{ 1, 0, 2, 3, 2, 0, 1, 3 }, 0..) |q, i| cn.sample(q, false, @intCast(i));
    var records: usize = 0;
    while (cn.pop()) |r| {
        records += 1;
        try std.testing.expectEqual(@as(i8, if (records <= 1) 1 else -1), r.event.rotate);
    }
    try std.testing.expectEqual(@as(usize, 2), records);
    cn = .{};
    for (0..8) |cycle| for ([_]u2{ 1, 0, 2, 3 }, 0..) |q, i| cn.sample(q, true, @intCast(20 + cycle * 4 + i));
    // Establish a stable press then deliberately exceed queue capacity.
    cn.sample(3, true, 100);
    for (0..8) |cycle| for ([_]u2{ 1, 0, 2, 3 }, 0..) |q, i| cn.sample(q, true, @intCast(110 + cycle * 4 + i));
    drain(&cn, &a);
    try std.testing.expect(cn.lost > 0);
    try std.testing.expect(!a.stroke_active);
    cn.sample(3, false, 200);
    cn.sample(3, false, 220);
    drain(&cn, &a);
    try std.testing.expect(!a.stroke_active);
}
test "gesture timing wraps, short press remains one step and image change waits 600ms" {
    var cn: input.Controller = .{};
    var a: application.App = .{};
    cn.sample(3, true, 0xffffffe0);
    cn.sample(3, true, 0xfffffff4);
    turn(&cn, &a, true, 0xfffffff5, true);
    cn.sample(3, false, 5);
    cn.sample(3, false, 25);
    drain(&cn, &a);
    try std.testing.expect(!a.stroke_active);
    try std.testing.expect(!a.due(500));
    try std.testing.expect(a.due(600));
    cn = .{};
    a = .{};
    cn.sample(3, true, 0);
    cn.sample(3, true, 20);
    cn.sample(3, false, 50);
    cn.sample(3, false, 70);
    drain(&cn, &a);
    try std.testing.expectEqual(@as(u8, 6), a.turtle.y);
    a.predict();
    a.turtle.y = 0;
    a.event(.click, 100);
    try std.testing.expect(a.valid);
    try std.testing.expect(!a.pending);
}
const CheckedSurface = struct {
    pub var frame: [1024]u8 = @splat(0);
    pub var page: ?usize = null;
    pub fn pixel(x: i16, y: i16, on: bool) void {
        std.debug.assert(x >= 0 and x < 128 and y >= 0 and y < 64);
        if (page) |p| {
            if (@divTrunc(y, 8) != p) return;
        }
        const idx: usize = @intCast(@divTrunc(y, 8) * 128 + x);
        const bit = @as(u8, 1) << @as(u3, @intCast(@mod(y, 8)));
        if (on) frame[idx] |= bit else frame[idx] &= ~bit;
    }
};
test "DRAW arrows edges and page rendering preserve model data" {
    const ui = @import("ui.zig");
    var a: application.App = .{};
    for ([_]u8{ 0, 7, 15 }) |x| for ([_]u8{ 0, 7, 15 }) |y| for (0..8) |dir| {
        a.turtle.x = x;
        a.turtle.y = y;
        a.turtle.direction = @intCast(dir);
        inline for (.{ false, true }) |ink| {
            a.turtle.down = ink;
            if (ink) @memset(&a.bitmap.pixels, 255) else a.bitmap.clear();
            const before = a;
            CheckedSurface.page = null;
            @memset(&CheckedSurface.frame, 0);
            ui.draw(CheckedSurface, &a);
            const full = CheckedSurface.frame;
            try std.testing.expect(full[2] & 4 != 0); // frame top left
            @memset(&CheckedSurface.frame, 0);
            for (0..8) |p| {
                CheckedSurface.page = p;
                ui.draw(CheckedSurface, &a);
            }
            CheckedSurface.page = null;
            try std.testing.expectEqualSlices(u8, &full, &CheckedSurface.frame);
            try std.testing.expectEqualDeep(before, a);
        }
    };
}
test "prediction glyphs distinct and menu selection inverted without state mutation" {
    const ui = @import("ui.zig");
    var images: [10][1024]u8 = undefined;
    for (0..10) |digit| {
        @memset(&CheckedSurface.frame, 0);
        ui.predictionDigit(CheckedSurface, @intCast(digit));
        images[digit] = CheckedSurface.frame;
        for (0..digit) |old| try std.testing.expect(!std.mem.eql(u8, &images[digit], &images[old]));
    }
    var a: application.App = .{};
    a.menu = true;
    a.item = 1;
    const before = a;
    @memset(&CheckedSurface.frame, 0);
    ui.draw(CheckedSurface, &a);
    try std.testing.expect(CheckedSurface.frame[127 + 2 * 128] & 1 != 0); // selected y16 row
    try std.testing.expectEqualDeep(before, a);
    a.menu = false;
    a.bitmap.line(3, 3, 10, 10);
    a.pending = true;
    @memset(&CheckedSurface.frame, 0);
    ui.draw(CheckedSurface, &a);
    const pending = CheckedSurface.frame;
    a.pending = false;
    @memset(&CheckedSurface.frame, 0);
    ui.draw(CheckedSurface, &a);
    try std.testing.expect(!std.mem.eql(u8, &pending, &CheckedSurface.frame));
    a.predict();
    try std.testing.expect(a.valid);
    @memset(&CheckedSurface.frame, 0);
    ui.draw(CheckedSurface, &a);
}

test "normal rotation recovers after queue overflow and prior long menu cannot draw" {
    var cn: input.Controller = .{};
    var a: application.App = .{};
    for (0..8) |cycle| for ([_]u2{ 1, 0, 2, 3 }, 0..) |q, i| cn.sample(q, false, @intCast(cycle * 4 + i));
    drain(&cn, &a);
    try std.testing.expect(cn.lost > 0);
    const old = a.turtle.direction;
    turn(&cn, &a, false, 100, true);
    try std.testing.expect(a.turtle.direction != old);
    cn = .{};
    a = .{};
    cn.sample(3, true, 0);
    cn.sample(3, true, 20);
    cn.sample(3, true, 720);
    drain(&cn, &a);
    try std.testing.expect(a.menu);
    a.menu = false; // even if the screen changes, this held gesture is latched
    turn(&cn, &a, true, 730, true);
    try std.testing.expect(a.bitmap.empty());
    try std.testing.expectEqual(@as(u8, 7), a.turtle.y);
}
test "one-cell turtle path equals Bresenham endpoints in all directions" {
    const T = c.Turtle;
    for (0..8) |dir| for (0..16) |y| for (0..16) |x| {
        var t: T = .{ .x = @intCast(x), .y = @intCast(y), .direction = @intCast(dir) };
        var got: c.Canvas = .{};
        var want: c.Canvas = .{};
        _ = t.advance(&got);
        if (t.x != x or t.y != y) want.line(@intCast(x), @intCast(y), t.x, t.y);
        try std.testing.expectEqualSlices(u8, &want.pixels, &got.pixels);
    };
}

test "partial encoder steps never straddle a debounced press or release" {
    var cn: input.Controller = .{};
    cn.sample(2, false, 0);
    cn.sample(3, true, 1);
    cn.sample(3, true, 21);
    for ([_]u2{ 2, 0, 1 }, 0..) |q, i| {
        cn.sample(q, true, @intCast(30 + i));
        try std.testing.expect(cn.pop() == null);
    }
    cn.sample(3, true, 33);
    try std.testing.expect(cn.pop().?.event == .stroke);
    cn.sample(3, false, 40);
    cn.sample(3, false, 60);
    try std.testing.expect(cn.pop().?.event == .stroke_end);
    for ([_]u2{ 2, 0, 1 }, 0..) |q, i| {
        cn.sample(q, false, @intCast(61 + i));
        try std.testing.expect(cn.pop() == null);
    }
    cn.sample(3, false, 64);
    try std.testing.expect(cn.pop().?.event == .rotate);
}
test "redrawing existing ink keeps inference current" {
    var a: application.App = .{};
    a.bitmap.line(7, 7, 7, 6);
    a.predict();
    const before = a.output;
    const count = a.inferences;
    a.event(.click, 10);
    try std.testing.expect(a.valid);
    try std.testing.expect(!a.pending);
    try std.testing.expectEqualSlices(i8, &before, &a.output);
    try std.testing.expectEqual(count, a.inferences);
}
