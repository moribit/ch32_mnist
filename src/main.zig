const fun = @import("ch32fun");
const application = @import("app.zig");
const App = application.App;
const input = @import("input.zig");
const options = @import("options");
pub const ch32fun_ssd1306_buffer_mode: fun.ssd1306.BufferMode = .page;
pub const ch32fun_swio_log_enabled = false;
var app: App = @import("std").mem.zeroes(App);
var encoder: input.Encoder = .{};
var button: input.Button = .{};
var rotation: i16 = 0;
var lost: u16 = 0;
const a = fun.gpio.pin(.A, 2);
const b = fun.gpio.pin(.D, 5);
const sw = fun.gpio.pin(.C, 4);
fn state() u2 {
    return (@as(u2, @intFromBool(a.read())) << 1) | @as(u2, @intFromBool(b.read()));
}
fn edge(_: u8) callconv(.c) void {
    const delta = encoder.update(state());
    const p: *volatile i16 = &rotation;
    const old = p.*;
    const next = @addWithOverflow(old, @as(i16, delta));
    if (next[1] == 0) p.* = next[0] else {
        const q: *volatile u16 = &lost;
        q.* +|= 1;
    }
}
const Draw = struct {
    pub fn pixel(x: i16, y: i16, on: bool) void {
        fun.ssd1306.drawPixel(x, y, on);
    }
};
fn predict() void {
    const start = fun.time.nowCycles();
    app.prep_cycles = 0;
    if (!app.source_sample) {
        const ok = @import("preprocess.zig").run(&app.bitmap, &app.input, @fromBackingInt(@intCast(@backingInt(options.preprocess))));
        app.prep_cycles = fun.time.nowCycles() -% start;
        if (!ok) {
            app.valid = false;
            app.pending = false;
            app.dirty = true;
            return;
        }
    }
    const t = fun.time.nowCycles();
    app.infer();
    app.cycles = fun.time.nowCycles() -% t;
    app.cycles_valid = true;
}
var measurements: if (options.benchmark) [9]u32 else [0]u32 = undefined;
var timing: if (options.benchmark) @import("cycle_benchmark").Summary else [0]u8 = undefined;
pub const Metrics = extern struct { model_id: u32, min: u32, median: u32, max: u32, timer_overhead: u32, preprocess: u32, render: u32, transfer: u32, stack_upper: u32, lost: u16, invalid: u16, reference_ok: u8, logits: [10]i8 };
pub export var mnist_metrics: Metrics = @import("std").mem.zeroes(Metrics);
const Clock = struct {
    pub fn now() u32 {
        return fun.time.nowCycles();
    }
};
pub fn main() noreturn {
    app.turtle = .{};
    app.method = .normalized;
    app.dirty = true;
    fun.system.init(.{});
    fun.time.systick.init(1000);
    fun.gpio.enableAllClocks();
    if (!options.diagnostic) {
        // Isolate Encoder B while programming. Never drive this shared lead.
        fun.time.delayMs(2000);
        fun.registers.afio().PCFR1 = (fun.registers.afio().PCFR1 & ~@as(u32, 7 << 24)) | @as(u32, 4 << 24);
        fun.gpio.pin(.D, 1).configure(.input_floating);
        fun.gpio.pin(.D, 4).configure(.input_floating);
        b.configure(.input_pull);
        b.write(true);
    }
    inline for (.{ a, sw }) |pin| {
        pin.configure(.input_pull);
        pin.write(true);
    }
    encoder.previous = state();
    if (options.benchmark) @import("stack_monitor.zig").init();
    mnist_metrics.model_id = @import("mnist_model").model_id;
    if (!options.diagnostic) {
        fun.exti.config(.{ .port = .A, .line = 2, .trigger = .both, .handler = edge });
        fun.exti.config(.{ .port = .D, .line = 5, .trigger = .both, .handler = edge });
        fun.exti.enable(2);
        fun.exti.enable(5);
    } else app.sample();
    fun.system.enableInterrupts();
    fun.ssd1306.initI2c() catch fail();
    fun.i2c.setBusClockHz(400_000);
    const controller: fun.ssd1306.Controller = if (@import("std").mem.eql(u8, options.display, "sh1106")) .sh1106 else if (@import("std").mem.eql(u8, options.display, "ssd1309")) .ssd1309 else .ssd1306;
    fun.ssd1306.initPanelController(controller) catch fail();
    if (controller == .ssd1309) {
        // Match the SSD1309 panel setup used by Mopping_rotaly.
        const clock = [3]u8{ 0, 0xd5, 0xf0 };
        const vcom = [3]u8{ 0, 0xdb, 0x34 };
        fun.i2c.writeBlocking7bit(@backingInt(fun.ssd1306.currentAddress()), &clock) catch fail();
        fun.i2c.writeBlocking7bit(@backingInt(fun.ssd1306.currentAddress()), &vcom) catch fail();
    }
    var last = fun.time.nowCycles();
    var remainder: u32 = 0;
    var ms: u32 = 0;
    while (true) {
        const now = fun.time.nowCycles();
        const delta = now -% last;
        last = now;
        ms +%= delta / 48000;
        remainder += delta % 48000;
        ms +%= remainder / 48000;
        remainder %= 48000;
        fun.system.disableInterrupts();
        asm volatile ("" ::: .{ .memory = true });
        const ptr: *volatile i16 = &rotation;
        const turns = ptr.*;
        ptr.* = 0;
        asm volatile ("" ::: .{ .memory = true });
        fun.system.enableInterrupts();
        var todo = turns;
        while (todo != 0) {
            const d: i8 = if (todo > 0) 1 else -1;
            app.event(.{ .rotate = d }, ms);
            todo -= d;
        }
        if (button.update(!sw.read(), ms)) |e| app.event(e, ms);
        if (app.due(ms)) predict();
        if (options.benchmark and app.valid and app.inferences == 1) {
            timing = @import("cycle_benchmark").measure(application.Model, Clock, &app.input, &app.output, &app.ws, &measurements);
            app.cycles = timing.median;
            const metrics: *volatile Metrics = &mnist_metrics;
            metrics.min = timing.min;
            metrics.median = timing.median;
            metrics.max = timing.max;
            metrics.timer_overhead = timing.overhead;
            app.inferences += 10;
        }
        if (app.dirty) {
            var draw_cycles: u32 = 0;
            var transfer: u32 = 0;
            fun.ssd1306.firstPage();
            while (true) {
                const t = fun.time.nowCycles();
                @import("ui.zig").draw(Draw, &app);
                draw_cycles +%= fun.time.nowCycles() -% t;
                const tt = fun.time.nowCycles();
                const more = fun.ssd1306.nextPage() catch fail();
                transfer +%= fun.time.nowCycles() -% tt;
                if (!more) break;
            }
            app.render_cycles = draw_cycles;
            app.transfer_cycles = transfer;
            app.dirty = false;
            const metrics: *volatile Metrics = &mnist_metrics;
            metrics.preprocess = app.prep_cycles;
            metrics.render = draw_cycles;
            metrics.transfer = transfer;
            metrics.reference_ok = @intFromBool(app.reference_ok);
            metrics.logits = app.output;
            fun.system.disableInterrupts();
            asm volatile ("" ::: .{ .memory = true });
            if (options.benchmark) metrics.stack_upper = @import("stack_monitor.zig").highWaterUpperBound();
            metrics.lost = (@as(*volatile u16, &lost)).*;
            metrics.invalid = encoder.invalid;
            asm volatile ("" ::: .{ .memory = true });
            fun.system.enableInterrupts();
        }
    }
}
fn fail() noreturn {
    while (true) asm volatile ("wfi");
}
