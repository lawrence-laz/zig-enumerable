pub fn ScanIterator(
    comptime TItem: type,
    comptime TState: type,
    comptime function: fn (TState, TItem) TState,
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();

        prev_iter: *TPrevIter,
        state: TState,

        pub fn next(self: *Self) ?TState {
            if (self.prev_iter.next()) |item| {
                self.state = function(self.state, item);
                return self.state;
            }
            return null;
        }
    };
}
