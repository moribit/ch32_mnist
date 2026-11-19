const std = @import("std");
const A = @import("app.zig");
const C = @import("canvas.zig");
const pre = @import("preprocess.zig");
const surface = @import("sim_surface.zig");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var a: A.App = .{};
    a.sample();
    a.predict();
    if (args.len == 2 and std.mem.eql(u8, args[1], "benchmark")) {
        var report: std.Io.Writer.Allocating = .init(init.arena.allocator());
        try report.writer.writeAll("scene,iterations,host_ns_per_full_draw\n");
        inline for (.{ A.Mode.draw, A.Mode.sample, A.Mode.inspect }) |mode| {
            a.mode = mode;
            const start = std.Io.Clock.awake.now(init.io);
            for (0..2000) |i| {
                @memset(&surface.frame, 0);
                a.turtle.x = @intCast(i % 16);
                @import("ui.zig").draw(surface, &a);
            }
            const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
            try report.writer.print("{s},2000,{d}\n", .{ @tagName(mode), @divTrunc(elapsed, 2000) });
        }
        try std.Io.File.stdout().writeStreamingAll(init.io, report.written());
        return;
    }
    if (args.len == 2 and std.mem.eql(u8, args[1], "golden")) {
        var report: std.Io.Writer.Allocating = .init(init.arena.allocator());
        try report.writer.writeAll("model_id,sample,q0,q1,q2,q3,q4,q5,q6,q7,q8,q9\n");
        for (0..2) |i| {
            a.sample_index = @intCast(i);
            a.sample();
            a.predict();
            try report.writer.print("{d},{d}", .{ @import("mnist_model").model_id, i });
            for (a.output) |q| try report.writer.print(",{d}", .{q});
            try report.writer.writeByte('\n');
        }
        try std.Io.File.stdout().writeStreamingAll(init.io, report.written());
        return;
    }
    if (args.len == 3) {
        if (std.mem.startsWith(u8, args[1], "draw-") or std.mem.eql(u8, args[1], "menu")) {
            a.clear();
            const scene = args[1];
            if (std.mem.eql(u8, scene, "draw-result")) {
                for (a.input, 0..) |_, i| a.bitmap.set(@intCast(i % 16), @intCast(i / 16), A.samples[0][i] > 32);
                a.predict();
            } else if (std.mem.eql(u8, scene, "draw-pending") or std.mem.eql(u8, scene, "draw-down") or std.mem.eql(u8, scene, "draw-up")) {
                a.bitmap.line(4, 3, 11, 3);
                a.bitmap.line(11, 3, 5, 13);
                a.pending = true;
                if (std.mem.eql(u8, scene, "draw-up")) a.turtle.down = false;
            } else if (std.mem.eql(u8, scene, "draw-edge")) {
                a.turtle.x = 15;
                a.turtle.y = 0;
                a.turtle.direction = 1;
            } else if (std.mem.eql(u8, scene, "menu")) {
                a.menu = true;
                a.item = 1;
            } else if (!std.mem.eql(u8, scene, "draw-empty")) return error.UnknownScene;
        } else if (std.mem.eql(u8, args[1], "inspect")) a.mode = .inspect else if (!std.mem.eql(u8, args[1], "sample")) return error.UnknownScene;
        @import("ui.zig").draw(surface, &a);
        var file = try std.Io.Dir.cwd().createFile(init.io, args[2], .{});
        defer file.close(init.io);
        try file.writeStreamingAll(init.io, "P4\n128 64\n");
        var row: [16]u8 = undefined;
        for (0..64) |y| {
            @memset(&row, 0);
            for (0..128) |x| {
                if (surface.frame[(y / 8) * 128 + x] & (@as(u8, 1) << @intCast(y % 8)) == 0) row[x / 8] |= @as(u8, 128) >> @intCast(x % 8);
            }
            try file.writeStreamingAll(init.io, &row);
        }
        return;
    }
    if (args.len != 1) return error.ExpectedSceneAndPath;
    var output: std.Io.Writer.Allocating = .init(init.arena.allocator());
    try output.writer.writeAll("fixture,method,prediction,expected_style,margin\n");
    const segments = [7][4]i16{ .{ 4, 2, 11, 2 }, .{ 12, 3, 12, 7 }, .{ 12, 8, 12, 13 }, .{ 4, 14, 11, 14 }, .{ 3, 8, 3, 13 }, .{ 3, 3, 3, 7 }, .{ 4, 8, 11, 8 } };
    const masks = [10]u7{ 63, 6, 91, 79, 102, 109, 125, 7, 127, 111 };
    for (masks, 0..) |mask, digit| {
        for (0..3) |variant| {
            a.clear();
            for (segments, 0..) |line, i| {
                if (mask & (@as(u7, 1) << @intCast(i)) != 0) {
                    const dx: i16 = if (variant == 1) -2 else 0;
                    const dy: i16 = if (variant == 1) -1 else 0;
                    walk(&a, @intCast(line[0] + dx), @intCast(line[1] + dy), false);
                    walk(&a, @intCast(line[2] + dx), @intCast(line[3] + dy), true);
                    if (variant == 2) {
                        walk(&a, @intCast(line[0] + 1), @intCast(line[1]), false);
                        walk(&a, @intCast(line[2] + 1), @intCast(line[3]), true);
                    }
                }
            }
            inline for (.{ pre.Method.direct, pre.Method.centered, pre.Method.normalized, pre.Method.antialiased }) |method| {
                _ = pre.run(&a.bitmap, &a.input, method);
                a.infer();
                try output.writer.print("{d}-{d},{s},{d},{d},{d}\n", .{ digit, variant, @tagName(method), a.prediction(), digit, a.margin() });
            }
        }
    }
    try std.Io.File.stdout().writeStreamingAll(init.io, output.written());
}

fn walk(a: *A.App, x: u8, y: u8, down: bool) void {
    a.turtle.down = down;
    while (a.turtle.x != x or a.turtle.y != y) {
        const dx = std.math.sign(@as(i16, x) - a.turtle.x);
        const dy = std.math.sign(@as(i16, y) - a.turtle.y);
        for (C.Turtle.dx, C.Turtle.dy, 0..) |xx, yy, dir| {
            if (xx == dx and yy == dy) {
                a.event(.{ .rotate = @intCast(@as(i16, @intCast(dir)) - a.turtle.direction) }, 0);
                break;
            }
        }
        a.event(.click, 0);
    }
}
