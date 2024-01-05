pub fn TakeIterator(
    comptime TItem: type,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: TPrevIter,
        count: usize,
        index: usize,

        pub fn next(self: *Self) ?TItem {
            if (self.index < self.count) {
                self.index += 1;
                return self.prev_iter.next() orelse null;
            }
            return null;
        }
    };
}
