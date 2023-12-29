const Iterator = @import("iterator.zig").Iterator;

pub fn ZipIterator(
    comptime TItem: type,
    comptime TPrevIter: type,
    comptime TOtherIter: type,
    comptime TOtherItem: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: *TPrevIter,
        other_iter: *TOtherIter,

        pub fn next(self: *Self) ?struct { TItem, TOtherItem } {
            if (self.prev_iter.next()) |first_item| {
                if (self.other_iter.next()) |second_item| {
                    return .{ first_item, second_item };
                }
            }
            return null;
        }
    };
}
