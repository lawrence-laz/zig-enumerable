pub fn TakeWhileIterator(
    comptime TItem: type,
    comptime filter: fn (TItem) bool,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: *TPrevIter,
        completed: bool,

        pub fn next(self: *Self) ?TItem {
            if (self.completed) {
                return null;
            } else if (self.prev_iter.next()) |item| {
                if (filter(item)) {
                    return item;
                } else {
                    self.completed = true;
                    return null;
                }
            } else {
                return null;
            }
        }
    };
}
