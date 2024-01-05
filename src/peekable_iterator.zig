const Iterator = @import("iterator.zig").Iterator;

pub fn PeekableIterator(
    comptime TItem: type,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: TPrevIter,
        peeked_item: ??TItem,

        pub fn next(self: *Self) ?TItem {
            if (self.peeked_item) |item| {
                self.peeked_item = null;
                return item;
            }
            return self.prev_iter.next();
        }

        pub fn peek(self: *Self) ?TItem {
            if (self.peeked_item) |item| {
                return item;
            } else if (self.next()) |item| {
                self.peeked_item = item;
                return item;
            } else {
                return null;
            }
        }
    };
}
