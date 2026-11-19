// Hardware isolation: use the same full-buffer transfer path as Mopping_rotaly.
const fun = @import("ch32fun");
const options = @import("options");
const std = @import("std");
pub const ch32fun_ssd1306_buffer_mode: fun.ssd1306.BufferMode = .full;
pub const ch32fun_swio_log_enabled = false;
fn command(op: u8, value: u8) !void {
    const packet = [_]u8{ 0, op, value };
    try fun.i2c.writeBlocking7bit(@backingInt(fun.ssd1306.currentAddress()), &packet);
}
pub fn main() noreturn {
    fun.system.init(.{});
    fun.time.systick.init(1000);
    fun.gpio.enableAllClocks();
    // Keep SWIO enabled and all encoder pins untouched. No application IRQs.
    fun.time.delayMs(500);
    fun.ssd1306.initI2c() catch halt();
    const controller: fun.ssd1306.Controller = if (std.mem.eql(u8, options.display, "sh1106")) .sh1106 else if (std.mem.eql(u8, options.display, "ssd1309")) .ssd1309 else .ssd1306;
    fun.ssd1306.initPanelController(controller) catch halt();
    if (controller == .ssd1309) {
        command(0xd5, 0xf0) catch halt();
        command(0xdb, 0x34) catch halt();
    }
    var tick = false;
    while (true) {
        fun.ssd1306.setbuf(false);
        for (0..128) |x| {
            fun.ssd1306.drawPixel(@intCast(x), 0, true);
            fun.ssd1306.drawPixel(@intCast(x), 63, true);
        }
        for (0..64) |y| {
            fun.ssd1306.drawPixel(0, @intCast(y), true);
            fun.ssd1306.drawPixel(127, @intCast(y), true);
        }
        fun.ssd1306.drawStrSz(8, 8, "OLED TEST", true, .x1);
        fun.ssd1306.drawStrSz(8, 24, options.display, true, .x1);
        for (40..56) |y| for (8..120) |x| {
            if (((x / 8) & 1) == 0) fun.ssd1306.drawPixel(@intCast(x), @intCast(y), true);
        };
        if (tick) for (8..16) |y| for (112..120) |x| {
            fun.ssd1306.drawPixel(@intCast(x), @intCast(y), true);
        };
        fun.ssd1306.refresh() catch halt();
        tick = !tick;
        fun.time.delayMs(500);
    }
}
fn halt() noreturn {
    while (true) asm volatile ("wfi");
}
