const canvas = @import("canvas.zig");
const pre = @import("preprocess.zig");
const gen = @import("mnist_model");
const options = @import("options");
pub const Model = gen.Model;
pub const samples = [2][256]i8{ gen.inputs[0], gen.inputs[7] };
pub const expected = [2][10]i8{ gen.expected[0], gen.expected[7] };
pub const Mode = enum { draw, sample, inspect };
pub const App = struct {
    bitmap: canvas.Canvas = .{},
    undo_bitmap: canvas.Canvas = .{},
    turtle: canvas.Turtle = .{},
    undo_turtle: canvas.Turtle = .{},
    undo_valid: bool = false,
    stroke_active: bool = false,
    input: [256]i8 = @splat(0),
    output: [10]i8 = @splat(0),
    ws: Model.Workspace = .{},
    trace: if (options.trace) Model.Trace else [0]u8 = .{},
    mode: Mode = .draw,
    menu: bool = false,
    item: u3 = 0,
    sample_index: u1 = 0,
    selected: u4 = 0,
    method: pre.Method = .normalized,
    source_sample: bool = false,
    valid: bool = false,
    dirty: bool = true,
    pending: bool = false,
    changed: u32 = 0,
    inferences: u32 = 0,
    cycles: u32 = 0,
    cycles_valid: bool = false,
    reference_ok: bool = false,
    prep_cycles: u32 = 0,
    render_cycles: u32 = 0,
    transfer_cycles: u32 = 0,
    pub fn predict(self: *App) void {
        if (!self.source_sample and !(switch (self.method) {
            inline else => |method| pre.run(&self.bitmap, &self.input, method),
        })) {
            self.valid = false;
            self.pending = false;
            self.dirty = true;
            return;
        }
        self.infer();
    }
    pub fn infer(self: *App) void {
        if (options.trace) Model.inferTraced(&self.input, &self.output, &self.ws, &self.trace) else Model.infer(&self.input, &self.output, &self.ws);
        self.valid = true;
        self.reference_ok = self.source_sample;
        for (self.output, expected[self.sample_index]) |actual, reference| {
            if (actual != reference) self.reference_ok = false;
        }
        self.pending = false;
        self.dirty = true;
        self.inferences +%= 1;
    }
    pub fn prediction(self: *const App) u8 {
        var best: usize = 0;
        for (self.output, 0..) |v, i| if (v > self.output[best]) {
            best = i;
        };
        return @intCast(best);
    }
    pub fn margin(self: *const App) u16 {
        var first: i16 = -129;
        var second: i16 = -129;
        for (self.output) |v| {
            if (v > first) {
                second = first;
                first = v;
            } else if (v > second) second = v;
        }
        return @intCast(first - second);
    }
    pub fn sample(self: *App) void {
        self.mode = .sample;
        self.source_sample = true;
        self.input = samples[self.sample_index];
        self.pending = true;
        self.valid = false;
    }
    pub fn clear(self: *App) void {
        self.stroke_active = false;
        self.bitmap.clear();
        self.source_sample = false;
        @memset(&self.input, @import("preprocess.zig").zero);
        if (options.trace) self.trace = .{};
        self.valid = false;
        self.cycles_valid = false;
        self.reference_ok = false;
        self.pending = false;
        self.undo_valid = false;
        self.mode = .draw;
        self.turtle = .{};
        @memset(&self.output, 0);
        self.dirty = true;
    }
    fn resumeDraw(self: *App, now: u32) void {
        self.mode = .draw;
        if (self.source_sample) {
            self.source_sample = false;
            self.valid = false;
            self.pending = !self.bitmap.empty();
            self.changed = now;
        }
    }
    pub fn due(self: *const App, now: u32) bool {
        return !self.menu and !self.stroke_active and self.pending and (self.mode == .sample or now -% self.changed >= 600);
    }
    fn saveUndo(self: *App) void {
        self.undo_bitmap = self.bitmap;
        self.undo_turtle = self.turtle;
        self.undo_valid = true;
    }
    fn move(self: *App, d: i8, now: u32) void {
        const direction = self.turtle.direction;
        if (d < 0) self.turtle.rotate(4);
        const changed = self.turtle.advance(&self.bitmap);
        self.turtle.direction = direction;
        if (changed) {
            self.source_sample = false;
            self.pending = true;
            self.valid = false;
            self.changed = now;
        }
    }
    fn rotate(self: *App, d: i8) void {
        if (self.menu) {
            self.item = @intCast(@mod(@as(i16, self.item) + d, 7));
        } else switch (self.mode) {
            .draw => self.turtle.rotate(d),
            .sample => {
                self.sample_index ^= 1;
                self.sample();
            },
            .inspect => self.selected = @intCast(@mod(@as(i16, self.selected) + d, 10)),
        }
    }
    pub fn event(self: *App, e: @import("input.zig").Event, now: u32) void {
        self.dirty = true;
        switch (e) {
            .stroke_end => self.stroke_active = false,
            .stroke => |d| {
                if (!self.menu and self.mode == .draw) {
                    if (!self.stroke_active) self.saveUndo();
                    self.stroke_active = true;
                    var n: i16 = @intCast(@abs(d));
                    while (n > 0) : (n -= 1) self.move(d, now);
                } else self.rotate(d);
            },
            .long_press => {
                self.menu = !self.menu;
                self.item = 0;
            },
            .rotate => |d| self.rotate(d),
            .click => {
                if (self.menu) {
                    self.menu = false;
                    switch (self.item) {
                        0 => self.resumeDraw(now),
                        1 => {
                            self.resumeDraw(now);
                            self.turtle.down = !self.turtle.down;
                        },
                        2 => {
                            if (self.undo_valid) {
                                self.bitmap = self.undo_bitmap;
                                self.turtle = self.undo_turtle;
                                self.undo_valid = false;
                                self.valid = false;
                                self.pending = !self.bitmap.empty();
                                self.changed = now;
                            }
                            self.resumeDraw(now);
                        },
                        3 => {
                            self.pending = true;
                            self.changed = now -% 600;
                        },
                        4 => self.clear(),
                        5 => self.sample(),
                        6 => self.mode = .inspect,
                        else => unreachable,
                    }
                } else switch (self.mode) {
                    .draw => {
                        self.saveUndo();
                        self.move(1, now);
                    },
                    .sample => self.mode = .inspect,
                    .inspect => self.resumeDraw(now),
                }
            },
        }
    }
};
