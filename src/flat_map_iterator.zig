const Iterator = @import("iterator.zig").Iterator;
const from = @import("from.zig");
const SliceIterator = @import("from/slice_iterator.zig").SliceIterator;

pub fn FlatMapIterator(
    comptime TSource: type,
    comptime TDest: type,
    comptime function: fn (TSource) []const TDest,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: TPrevIter,
        slice_iter: ?Iterator(TDest, SliceIterator(TDest)),

        pub fn next(self: *Self) ?TDest {
            if (self.slice_iter == null) {
                if (self.prev_iter.next()) |item| {
                    var slice = function(item);
                    self.slice_iter = from.slice(slice);
                } else {
                    return null;
                }
            }

            if (self.slice_iter.?.next()) |slice_item| {
                return slice_item;
            } else {
                while (self.prev_iter.next()) |item| {
                    var slice = function(item);
                    self.slice_iter = from.slice(slice);
                    if (self.slice_iter.?.next()) |slice_item| {
                        return slice_item;
                    }
                }
            }
            return null;
        }
    };
}
