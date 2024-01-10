const Iterator = @import("iterator.zig").Iterator;

pub fn PrependIterator(
    comptime TItem: type,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: TPrevIter,
        prepended_item: ?TItem,

        pub fn next(self: *Self) ?TItem {
            if (self.prepended_item) |appended_item| {
                self.prepended_item = null;
                return appended_item;
            } else if (self.prev_iter.next()) |item| {
                return item;
            } else {
                return null;
            }
        }
    };
}
