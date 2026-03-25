const std = @import("std");

pub const ExponentialMovingAverage = struct {
    alpha: f64,
    initialized: bool = false,
    current_value: f64 = 0.0,

    pub fn init(alpha: f64) @This() {
        std.debug.assert(alpha > 0.0 and alpha <= 1.0);
        return .{ .alpha = alpha };
    }

    pub fn push(self: *@This(), sample: f64) f64 {
        if (!self.initialized) {
            self.initialized = true;
            self.current_value = sample;
        } else {
            self.current_value =
                self.alpha * sample +
                (1.0 - self.alpha) * self.current_value;
        }

        return self.current_value;
    }

    pub fn value(self: *const @This()) ?f64 {
        if (!self.initialized) return null;
        return self.current_value;
    }
};

