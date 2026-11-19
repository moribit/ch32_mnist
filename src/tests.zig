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
