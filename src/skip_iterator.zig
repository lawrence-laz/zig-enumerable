pub fn SkipIterator(
    comptime TItem: type,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: TPrevIter,
        count: usize,
        index: usize,

        pub fn next(self: *Self) ?TItem {
            while (self.index < self.count) {
                _ = self.prev_iter.next();
                self.index += 1;
            }
            return self.prev_iter.next() orelse null;
        }
    };
}
