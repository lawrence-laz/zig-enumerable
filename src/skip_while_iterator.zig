pub fn SkipWhileIterator(
    comptime TItem: type,
    comptime filter: fn (TItem) bool,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: *TPrevIter,
        skipping_is_done: bool,

        pub fn next(self: *Self) ?TItem {
            if (!self.skipping_is_done) {
                while (self.prev_iter.next()) |item| {
                    if (!filter(item)) {
                        self.skipping_is_done = true;
                        return item;
                    }
                }
            }

            return self.prev_iter.next();
        }
    };
}
