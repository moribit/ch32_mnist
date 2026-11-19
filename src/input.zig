pub const Event = union(enum) { rotate: i8, click, long_press };
pub const Encoder = struct {
    // Match Mopping_rotaly: two valid Gray-code edges per reported step.
    previous: u2 = 3,
    phase: i8 = 0,
    invalid: u16 = 0,
    pub fn update(self: *Encoder, current: u2) i8 {
        const table = [16]i8{ 0, -1, 1, 0, 1, 0, 0, -1, -1, 0, 0, 1, 0, 1, -1, 0 };
        const old = self.previous;
        self.previous = current;
        const d = table[(@as(u4, old) << 2) | current];
        if (d == 0 and old != current) {
            self.phase = 0;
            self.invalid +|= 1;
            return 0;
        }
        self.phase += d;
        if (self.phase >= 2) {
            self.phase -= 2;
            return 1;
        }
        if (self.phase <= -2) {
            self.phase += 2;
            return -1;
        }
        return 0;
    }
};
pub const Button = struct {
    raw: bool = false,
    stable: bool = false,
    changed: u32 = 0,
    pressed: u32 = 0,
    long_sent: bool = false,
    pub fn update(self: *Button, down: bool, now: u32) ?Event {
        if (down != self.raw) {
            self.raw = down;
            self.changed = now;
        }
        if (self.stable != self.raw and now -% self.changed >= 20) {
            self.stable = self.raw;
            if (self.stable) {
                self.pressed = now;
                self.long_sent = false;
            } else if (!self.long_sent) return if (self.changed -% self.pressed >= 700) .long_press else .click;
        }
        if (self.stable and self.raw and !self.long_sent and now -% self.pressed >= 700) {
            self.long_sent = true;
            return .long_press;
        }
        return null;
    }
};
