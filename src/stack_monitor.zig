//! Optional conservative watermark; no value is claimed until run on hardware.
extern var _ebss: u8;
extern var _stack_top: u8;
var begin: usize = 0;
var end: usize = 0;
pub fn init() void {
    const sp: usize = asm volatile ("mv %[value], sp"
        : [value] "=r" (-> usize),
    );
    begin = (@intFromPtr(&_ebss) + 3) & ~@as(usize, 3);
    end = (sp - 128) & ~@as(usize, 3);
    var address = begin;
    while (address < end) : (address += 4) {
        const p: *volatile u32 = @ptrFromInt(address);
        p.* = 0xa5a5a5a5;
    }
}
pub fn highWaterUpperBound() u32 {
    var address = begin;
    while (address < end) : (address += 4) {
        const p: *volatile u32 = @ptrFromInt(address);
        if (p.* != 0xa5a5a5a5) break;
    }
    return @intCast(@intFromPtr(&_stack_top) - address);
}
