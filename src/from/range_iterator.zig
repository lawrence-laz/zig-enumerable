const std = @import("std");

pub fn RangeIterator(comptime TNumber: type) type {
    return struct {
        const Self = @This();

        from_inclusive: TNumber,
        to_exclusive: TNumber,
        current: TNumber,

        pub fn next(self: *Self) ?TNumber {
            if (self.current < self.to_exclusive) {
                const current = self.current;
                self.current += 1;
                return current;
            }

            return null;
        }
    };
}
