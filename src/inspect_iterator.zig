const Iterator = @import("iterator.zig").Iterator;

pub fn InspectIterator(
    comptime TItem: type,
    comptime function: fn (TItem) void,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: TPrevIter,

        pub fn next(self: *Self) ?TItem {
            if (self.prev_iter.next()) |item| {
                function(item);
                return item;
            }
            return null;
        }
    };
}
