pub fn TakeEveryIterator(
    comptime TItem: type,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: *TPrevIter,
        every_nth: usize,

        pub fn next(self: *Self) ?TItem {
            var skipped: usize = 0;
            while (skipped < self.every_nth - 1) {
                _ = self.prev_iter.next();
                skipped += 1;
            }
            return self.prev_iter.next();
        }
    };
}
