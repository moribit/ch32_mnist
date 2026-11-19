//! Comparison only: reproduces Mopping_rotaly's application-owned entry.
//! Not for MNIST deployment: this does not initialize BSS/data or IRQ state.
const diagnostic = @import("display_test.zig");
pub const ch32fun_ssd1306_buffer_mode = diagnostic.ch32fun_ssd1306_buffer_mode;
pub const ch32fun_ssd1306_basic_ascii_font = true;
pub const ch32fun_swio_log_enabled = false;
pub export fn _start() noreturn {
    diagnostic.main();
}
