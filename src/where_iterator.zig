const Iterator = @import("iterator.zig").Iterator;

pub fn WhereIterator(
    comptime TItem: type,
    comptime filter: fn (TItem) bool,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: *TPrevIter,

        pub fn next(self: *Self) ?TItem {
            while (self.prev_iter.next()) |item| {
                if (filter(item)) {
                    return item;
                }
            }
            return null;
        }
    };
}
