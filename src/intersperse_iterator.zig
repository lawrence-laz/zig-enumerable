const Iterator = @import("iterator.zig").Iterator;
const PeekableIterator = @import("peekable_iterator.zig").PeekableIterator;

pub fn IntersperseIterator(
    comptime TItem: type,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: PeekableIterator(TItem, TPrevIter),
        delimiter: ?TItem,
        next_is_delimiter: bool,

        pub fn next(self: *Self) ?TItem {
            if (self.prev_iter.peek()) |_| {
                if (self.next_is_delimiter) {
                    self.next_is_delimiter = false;
                    return self.delimiter;
                } else {
                    self.next_is_delimiter = true;
                    return self.prev_iter.next();
                }
            }
            return null;
        }
    };
}
