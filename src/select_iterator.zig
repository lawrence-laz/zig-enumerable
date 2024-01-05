const Iterator = @import("iterator.zig").Iterator;

pub fn SelectIterator(
    comptime TSource: type,
    comptime TDest: type,
    comptime project: fn (TSource) TDest,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: TPrevIter,

        pub fn next(self: *Self) ?TDest {
            while (self.prev_iter.next()) |item| {
                return project(item);
            }
            return null;
        }
    };
}
