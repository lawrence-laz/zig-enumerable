const Iterator = @import("iterator.zig").Iterator;

pub fn ConcatIterator(
    comptime TItem: type,
    comptime TPrevIter: type,
    comptime TNextIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: *TPrevIter,
        next_iter: *TNextIter,

        pub fn next(self: *Self) ?TItem {
            return self.prev_iter.next() orelse self.next_iter.next() orelse null;
        }
    };
}
