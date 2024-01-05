const Iterator = @import("iterator.zig").Iterator;

pub fn AppendIterator(
    comptime TItem: type,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: TPrevIter,
        appended_item: ?TItem,

        pub fn next(self: *Self) ?TItem {
            if (self.prev_iter.next()) |item| {
                return item;
            } else if (self.appended_item) |appended_item| {
                self.appended_item = null;
                return appended_item;
            } else {
                return null;
            }
        }
    };
}
