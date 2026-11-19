//! Optional PTQ, Zinn owns all weight conversion and source generation.
const std = @import("std");
const z = @import("zinn");
const original = @import("original");
const S = z.Definition(256, &.{ .{ .units = 32, .activation = .relu }, .{ .units = 10 } });
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedCheckpointAndOutput;
    const T = z.Trainer(S);
    var t = T.init(0);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.arena.allocator(), .limited(T.checkpoint_len + 1024));
    try t.decode(bytes);
    var samples: [16]T.Sample = undefined;
    for (&samples, original.inputs) |*sample, input| {
        for (&sample.input, input) |*v, q| v.* = @as(f32, @floatFromInt(q)) * original.input_scale;
        @memset(&sample.target, 0);
    }
    const Q = z.export_model.QuantizedFormat(S, .int4);
    const q = try Q.calibrate(&t, &samples);
    var writer: std.Io.Writer.Allocating = .init(init.arena.allocator());
    try q.writeSource(&writer.writer);
    try q.writeVerification(&writer.writer, &samples);
    var file = try std.Io.Dir.cwd().createFile(init.io, args[2], .{});
    defer file.close(init.io);
    try file.writeStreamingAll(init.io, writer.written());
}
