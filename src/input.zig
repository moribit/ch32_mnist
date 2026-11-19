pub const Event = union(enum) { rotate: i8, stroke: i8, stroke_end, click, long_press };
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
    consumed: bool = false,
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
                self.consumed = false;
            } else if (!self.long_sent and !self.consumed) return if (self.changed -% self.pressed >= 700) .long_press else .click;
        }
        if (self.stable and self.raw and !self.consumed and !self.long_sent and now -% self.pressed >= 700) {
            self.long_sent = true;
            return .long_press;
        }
        return null;
    }
};

/// Main-loop owned queue: preserve acquisition order while rendering an immutable
/// picture. Overflow cancels the gesture rather than replaying misclassified input.
pub const Controller = struct {
    pub const Record = struct { at: u32, event: Event };
    encoder: Encoder = .{},
    button: Button = .{},
    queue: [4]Record = undefined,
    head: u8 = 0,
    len: u8 = 0,
    lost: u16 = 0,
    overflowed: bool = false,
    pub fn pop(self: *Controller) ?Record {
        if (self.len == 0) {
            if (!self.button.stable and !self.button.raw) self.overflowed = false;
            return null;
        }
        const record = self.queue[self.head];
        self.head = (self.head + 1) % 4;
        self.len -= 1;
        return record;
    }
    fn push(self: *Controller, event: Event, now: u32) void {
        if (self.overflowed) return;
        if (self.len == 4) {
            self.lost +|= 1;
            self.head = 0;
            self.len = 1;
            self.queue[0] = .{ .at = now, .event = .stroke_end };
            self.overflowed = true;
            self.button.consumed = true;
            return;
        }
        self.queue[(self.head + self.len) % 4] = .{ .at = now, .event = event };
        self.len += 1;
    }
    pub fn sample(self: *Controller, state: u2, down: bool, now: u32) void {
        const was_pressed = self.button.stable;
        const e = self.button.update(down, now);
        if (was_pressed and !self.button.stable) {
            const consumed = self.button.consumed;
            self.overflowed = false;
            if (consumed) self.push(.stroke_end, now);
        }
        if (e) |event| self.push(event, now);
        // Never carry a partial quadrature step across a press/release boundary.
        if (down != was_pressed) {
            self.encoder.previous = state;
            self.encoder.phase = 0;
            return;
        }
        const delta = self.encoder.update(state);
        if (delta == 0 or self.overflowed) return;
        if (self.button.stable and !self.button.long_sent) {
            self.button.consumed = true;
            self.push(.{ .stroke = delta }, now);
        } else self.push(.{ .rotate = delta }, now);
    }
};
