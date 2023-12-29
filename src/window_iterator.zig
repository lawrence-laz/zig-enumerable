const Iterator = @import("iterator.zig").Iterator;

pub fn WindowIterator(
    comptime TItem: type,
    comptime window_size: usize,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: *TPrevIter,
        maybe_window: ?[window_size]TItem,

        pub fn next(self: *Self) ?[window_size]TItem {
            if (self.maybe_window) |*window| {
                var index: usize = 0;
                while (index < window_size - 1) {
                    window[index] = window[index + 1];
                    index += 1;
                }
                if (self.prev_iter.next()) |item| {
                    window[index] = item;
                    return window.*;
                } else {
                    return null;
                }
            } else {
                self.maybe_window = .{0} ** window_size;
                var index: usize = 0;
                while (index < window_size) {
                    if (self.prev_iter.next()) |item| {
                        self.maybe_window.?[index] = item;
                    } else {
                        return null;
                    }
                    index += 1;
                }
                return self.maybe_window;
            }
        }
    };
}
