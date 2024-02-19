const std = @import("std");
const meta = @import("meta.zig");
const expectEqual = @import("std").testing.expectEqual;

const enumerable = @This();

/// Returns the type of an iterator over a type `T`.
pub fn Iterator(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .Pointer => |type_info| switch (type_info.size) {
            .One => switch (@typeInfo(type_info.child)) {
                .Array => SliceIterator(std.meta.Elem(T)),
                else => type_info.child,
            },
            .Slice => if (type_info.is_const) SliceIterator(std.meta.Elem(T)) else MutSliceIterator(std.meta.Elem(T)),
            else => T,
        },
        else => T,
    };
}

/// Returns the type of an item from iterator of type `TIter`.
pub fn IteratorItem(comptime TIter: type) type {
    return @typeInfo(@typeInfo(@TypeOf(Iterator(TIter).next)).Fn.return_type.?).Optional.child;
}

/// Returns a new iterator for the given `iterable`.
///
/// The function determines the type of the `iterable` and adapts the iterator creation accordingly.
/// It supports pointers, slices, and other types directly.
pub inline fn from(iterable: anytype) Iterator(@TypeOf(iterable)) {
    return switch (@typeInfo(@TypeOf(iterable))) {
        .Pointer => |info| switch (info.size) {
            .One => switch (@typeInfo(info.child)) {
                .Array => fromSlice(iterable),
                else => iterable.*,
            },
            .Slice => if (info.is_const) fromSlice(iterable) else fromMutSlice(iterable),
            else => iterable,
        },
        else => iterable,
    };
}

test from {
    var foo = from(std.mem.tokenizeSequence(u8, "foo\nbar\nbaz\n", "\n"));
    try std.testing.expectEqualStrings("foo", foo.next().?);
    try std.testing.expectEqualStrings("bar", foo.next().?);
    try std.testing.expectEqualStrings("baz", foo.next().?);
    try std.testing.expectEqual(@as(?[]const u8, null), foo.next());

    try expectEqualIter("abcd", from("abcd"));
    try expectEqualIter(&[_]i32{ -1, 0, 1 }, from(&[_]i32{ -1, 0, 1 }));
}

/// Returns an iterator for the provided slice.
inline fn fromSlice(slice: anytype) SliceIterator(std.meta.Elem(@TypeOf(slice))) {
    return .{ .slice = slice };
}

/// A generic iterator for slices.
///
/// This iterator supports both forward and reverse iteration.
pub fn SliceIterator(comptime TItem: type) type {
    return struct {
        const Self = @This();

        slice: []const TItem,
        index: usize = 0,
        reversed: bool = false,
        completed: bool = false,

        /// Advances the iterator and returns the next item.
        ///
        /// Returns `null` when the sequence is exhausted.
        pub fn next(self: *Self) ?TItem {
            if (self.reversed) {
                if (self.index >= 0 and !self.completed) {
                    const item = self.slice[self.index];
                    if (self.index > 0) {
                        self.index -= 1;
                    } else {
                        self.completed = true;
                    }
                    return item;
                }
            } else {
                if (self.index < self.slice.len) {
                    const item = self.slice[self.index];
                    self.index += 1;
                    return item;
                }
            }

            return null;
        }

        /// Returns a new iterator that iterates over the slice in reverse order.
        pub fn reverse(self: *const Self) SliceIterator(TItem) {
            return .{
                .reversed = true,
                .index = self.slice.len - 1,
                .slice = self.slice,
            };
        }

        test reverse {
            try expectEqualIter("fedcba", from("abcdef").reverse());
        }

        pub usingnamespace enumerable;
        pub usingnamespace enumerable_mutable_and_indexable;
    };
}

/// Returns a mutable iterator for the provided slice.
inline fn fromMutSlice(slice: anytype) MutSliceIterator(std.meta.Elem(@TypeOf(slice))) {
    return .{ .slice = slice };
}

/// A generic mutable iterator for slices.
pub fn MutSliceIterator(comptime TItem: type) type {
    return struct {
        const Self = @This();

        slice: []TItem,
        index: usize = 0,
        reversed: bool = false,
        completed: bool = false,

        /// Advances the iterator and returns the next item.
        ///
        /// Returns `null` when the sequence is exhausted.
        pub fn next(self: *Self) ?TItem {
            if (self.reversed) {
                if (self.index >= 0 and !self.completed) {
                    const item = self.slice[self.index];
                    if (self.index > 0) {
                        self.index -= 1;
                    } else {
                        self.completed = true;
                    }
                    return item;
                }
            } else {
                if (self.index < self.slice.len) {
                    const item = self.slice[self.index];
                    self.index += 1;
                    return item;
                }
            }

            return null;
        }

        pub usingnamespace enumerable;
        pub usingnamespace enumerable_mutable_and_indexable;
    };
}

/// Generates a sequence of numbers from `from_inclusive` to `to_exclusive` with a step size of 1.
pub inline fn sequence(
    /// The type of the numbers in the sequence.
    comptime TNumber: type,
    /// The value of the first number in the sequence (inclusive).
    from_inclusive: TNumber,
    /// The value of the upper bound of the sequence (exclusive).
    to_exclusive: TNumber,
) SequenceIterator(TNumber) {
    return .{
        .from_inclusive = from_inclusive,
        .to_exclusive = to_exclusive,
        .current = from_inclusive,
    };
}

test sequence {
    try expectEqualIter(&[_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }, sequence(u8, 0, 10));
    try expectEqualIter(&[_]u8{ 10, 9, 8, 7, 6, 5, 4, 3, 2, 1 }, sequence(u8, 10, 0));
    try expectEqualIter(&[_]u8{}, sequence(u8, 0, 0));
}

/// An iterator for generating sequences of numbers with a step size of 1.
///
/// TODO: Implement reverse
pub fn SequenceIterator(comptime TNumber: type) type {
    return struct {
        const Self = @This();

        from_inclusive: TNumber,
        to_exclusive: TNumber,
        current: TNumber,
        positive_step: ?bool = null,

        pub fn next(self: *Self) ?TNumber {
            if (self.positive_step == null) {
                self.positive_step = self.to_exclusive > self.from_inclusive;
            }
            if ((self.positive_step.? and self.current < self.to_exclusive) or
                (!self.positive_step.? and self.current > self.to_exclusive))
            {
                const current = self.current;
                if (self.positive_step.?) {
                    self.current += 1;
                } else {
                    self.current -= 1;
                }
                return current;
            }

            return null;
        }

        pub usingnamespace enumerable;
    };
}

/// Generates a sequence of numbers from `from_inclusive` to `to_exclusive` with a specified step size.
pub inline fn sequenceEvery(
    /// The type of the numbers in the sequence.
    comptime TNumber: type,
    /// The value of the first number in the sequence (inclusive).
    from_inclusive: TNumber,
    /// The value of the upper bound of the sequence (exclusive).
    to_exclusive: TNumber,
    /// The size of the step between each element in the sequence.
    step: TNumber,
) SequenceEveryIterator(TNumber) {
    return .{
        .from_inclusive = from_inclusive,
        .to_exclusive = to_exclusive,
        .current = from_inclusive,
        .step = step,
    };
}

test sequenceEvery {
    try expectEqualIter(&[_]u8{ 0, 2, 4, 6, 8 }, sequenceEvery(u8, 0, 10, 2));
}

/// An iterator for generating sequences of numbers with a specified step size.
///
/// This iterator generates a sequence from `from_inclusive` to `to_exclusive` with a step size of `step`.
pub fn SequenceEveryIterator(comptime TNumber: type) type {
    return struct {
        const Self = @This();

        from_inclusive: TNumber,
        to_exclusive: TNumber,
        step: TNumber,
        current: TNumber,

        /// Advances the iterator and returns the next number in the sequence.
        ///
        /// Returns `null` when the sequence is exhausted.
        pub fn next(self: *Self) ?TNumber {
            if (self.current < self.to_exclusive) {
                const current = self.current;
                self.current += self.step;
                return current;
            }

            return null;
        }

        pub usingnamespace enumerable;
    };
}

/// Generates a countdown sequence starting from the given `starting_number`.
pub fn countdown(starting_number: anytype) CountdownIterator(@TypeOf(starting_number)) {
    return .{ .current = starting_number - 1 };
}

test countdown {
    try expectEqualIter(&[_]u8{ 2, 1, 0 }, countdown(@as(u8, 3)));
}

// TODO: Need a better name here
// Or actually need the original function to be typed, but I also need a function with single param?
pub fn countdown2(comptime T: type) fn (T) CountdownIterator(T) {
    return struct {
        fn f(starting_number: T) CountdownIterator(T) {
            return .{ .current = starting_number - 1 };
        }
    }.f;
}

/// An iterator for generating countdown sequences.
///
/// This iterator generates a sequence starting from a given numeric value, decrementing by 1 until reaching 0.
pub fn CountdownIterator(comptime TItem: type) type {
    return struct {
        const Self = @This();

        current: ?TItem,

        /// Advances the iterator and returns the next value in the countdown sequence.
        ///
        /// Returns `null` when the sequence is exhausted.
        pub fn next(self: *Self) ?TItem {
            if (self.current) |current_value| {
                if (current_value > 0) {
                    self.current.? -= 1;
                } else {
                    self.current = null;
                }
                return current_value;
            } else {
                return null;
            }
        }

        pub usingnamespace enumerable;
    };
}

/// Counts the number of items in the sequence.
pub inline fn count(self: anytype) usize {
    var self_copy = self.*;
    var result: usize = 0;
    while (self_copy.next()) |_| {
        result += 1;
    }
    return result;
}

test count {
    try expectEqual(@as(usize, 0), from("").count());
    try expectEqual(@as(usize, 3), from("abc").count());
}

/// Returns the sum of all items in the sequence.
///
/// Items in the sequence are expected to support the `+=` operator.
pub inline fn sum(self: anytype) IteratorItem(@TypeOf(self)) {
    var self_copy = self.*;
    var result: IteratorItem(@TypeOf(self)) = 0;
    while (self_copy.next()) |number| {
        result += number;
    }
    return result;
}

test sum {
    try expectEqual(@as(u8, 0), from(&[_]u8{}).sum());
    try expectEqual(@as(u8, 6), from(&[_]u8{ 1, 2, 3 }).sum());
    try expectEqual(@as(i32, -10), from(&[_]i32{ -30, 5, 15 }).sum());
    try expectEqual(@as(f32, -0.9), from(&[_]f32{ -1.5, 0.2, 0.4 }).sum());
}

/// Checks if the sequence contains at least one item satisfying the provided condition.
///
/// An empty sequence always returns `false`.
pub inline fn any(
    self: anytype,
    condition: anytype,
) bool {
    var self_copy = self.*;
    while (self_copy.next()) |item| {
        if (meta.callCallable(bool, condition, .{item})) {
            return true;
        }
    }
    return false;
}

test any {
    try expectEqual(false, from("").any(std.ascii.isDigit));
    try expectEqual(false, from("abc").any(std.ascii.isDigit));
    try expectEqual(true, from("abc1").any(std.ascii.isDigit));

    const Closure = struct {
        needle: u8,
        pub fn f(self: @This(), item: u8) bool {
            return item == self.needle;
        }
    };
    try expectEqual(true, from("abc_def").any(Closure{ .needle = '_' }));
    try expectEqual(false, from("abc_def").any(Closure{ .needle = '1' }));
}

/// Checks if all items in the sequence satisfy the provided condition.
///
/// An empty sequence always returns `true`.
pub inline fn all(
    self: anytype,
    condition: anytype,
) bool {
    var self_copy = self.*;
    while (self_copy.next()) |item| {
        if (!meta.callCallable(bool, condition, .{item})) {
            return false;
        }
    }
    return true;
}

test all {
    try expectEqual(true, from("").all(std.ascii.isDigit));
    try expectEqual(false, from("abc").all(std.ascii.isDigit));
    try expectEqual(false, from("abc123").all(std.ascii.isDigit));
    try expectEqual(true, from("123").all(std.ascii.isDigit));

    const Closure = struct {
        divider: u8,
        pub fn hasZeroRemainder(self: @This(), item: u8) bool {
            return item % self.divider == 0;
        }
    };
    try expectEqual(true, from(&[_]u8{ 3, 6, 9 }).all(Closure{ .divider = 3 }));
    try expectEqual(false, from(&[_]u8{ 5, 9, 15, 20 }).all(Closure{ .divider = 5 }));
}

/// Returns the first item of the sequence or `null` if the sequence is empty.
pub inline fn first(self: anytype) ?IteratorItem(@TypeOf(self)) {
    var self_copy = self.*;
    return self_copy.next() orelse null;
}

test first {
    try expectEqual(@as(?u8, null), from("").first());
    try expectEqual(@as(?u8, 'a'), from("a").first());
    try expectEqual(@as(?u8, 'a'), from("abc").first());
}

/// Returns the last item of the sequence or `null` if the sequence is empty.
pub inline fn last(self: anytype) ?IteratorItem(@TypeOf(self)) {
    var self_copy = self.*;
    var last_item: ?IteratorItem(@TypeOf(self)) = null;
    while (self_copy.next()) |item| {
        last_item = item;
    }
    return last_item;
}

test last {
    try expectEqual(@as(?u8, null), from("").last());
    try expectEqual(@as(?u8, 'a'), from("a").last());
    try expectEqual(@as(?u8, 'c'), from("abc").last());
}

/// Returns the item at the specified index or `null` if the index is out of bounds.
pub inline fn elementAt(
    self: anytype,
    index: usize,
) ?IteratorItem(@TypeOf(self)) {
    var self_copy = self.*;
    var current_index: usize = 0;
    while (current_index < index and self_copy.next() != null) {
        current_index += 1;
    }
    return self_copy.next();
}

test elementAt {
    try expectEqual(@as(?u8, null), from("").elementAt(0));
    try expectEqual(@as(?u8, 'a'), from("abc").elementAt(0));
    try expectEqual(@as(?u8, 'b'), from("abc").elementAt(1));
    try expectEqual(@as(?u8, 'c'), from("abc").elementAt(2));
    try expectEqual(@as(?u8, null), from("abc").elementAt(3));
}

/// Filters the items in the sequence using the given predicate function.
pub inline fn where(
    self: anytype,
    predicate: anytype,
) WhereIterator(Iterator(@TypeOf(self)), @TypeOf(predicate)) {
    return .{
        .prev_iter = self.*,
        .predicate = predicate,
    };
}

test where {
    try expectEqualIter("123", from("a12bcd3ef").where(std.ascii.isDigit));
    try expectEqualIter("", from("abcd").where(std.ascii.isDigit));
    try expectEqualIter("222", from("a12bcd32e2f").where(struct {
        needle: u8,
        pub fn f(self: @This(), item: u8) bool {
            return self.needle == item;
        }
    }{ .needle = '2' }));
}

pub fn WhereIterator(
    comptime TPrevIter: type,
    comptime TPredicate: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);

        prev_iter: TPrevIter,
        predicate: meta.ConstPtrWhenFn(TPredicate),

        pub fn next(self: *Self) ?Item {
            while (self.prev_iter.next()) |item| {
                if (meta.callCallable(bool, self.predicate, .{item})) {
                    return item;
                }
            }
            return null;
        }

        pub usingnamespace enumerable;
    };
}

/// Transforms the items in the sequence using the given selector function.
pub inline fn select(
    self: anytype,
    selector: anytype,
) SelectIterator(Iterator(@TypeOf(self)), @TypeOf(selector)) {
    return .{
        .prev_iter = self.*,
        .selector = selector,
    };
}

test select {
    try expectEqualIter(&[_]bool{ false, true, true, false, false, true }, from("a12bc3").select(std.ascii.isDigit));
    try expectEqualIter(&[_]bool{}, from("").select(std.ascii.isDigit));
    try expectEqualIter("234", from("123").select(struct {
        state: u8,
        pub fn f(self: @This(), item: u8) u8 {
            return item + self.state;
        }
    }{ .state = 1 }));
}

pub fn SelectIterator(
    comptime TPrevIter: type,
    comptime TSelector: type,
) type {
    return struct {
        const Self = @This();
        const Item = meta.CallableReturnType(TSelector).?;

        prev_iter: TPrevIter,
        selector: meta.ConstPtrWhenFn(TSelector),

        pub fn next(self: *Self) ?Item {
            while (self.prev_iter.next()) |item| {
                return meta.callCallable(Item, self.selector, .{item});
            }
            return null;
        }

        pub usingnamespace enumerable;
    };
}

/// Transforms and flattens the items in the sequence using the given selector function.
pub inline fn selectMany(
    self: anytype,
    selector: anytype,
) SelectManyIterator(Iterator(@TypeOf(self)), @TypeOf(selector)) {
    return .{
        .prev_iter = self.*,
        .slice_iter = null,
        .selector = selector,
    };
}

test selectMany {
    try expectEqualIter(&[_]u8{ 0, 1, 0, 2, 1, 0 }, from(&[_]u8{ 1, 2, 3 }).selectMany(countdown2(u8)));
}

// How to resolve type
pub fn SelectManyIterator(
    comptime TPrevIter: type,
    comptime TSelector: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(Iterator(meta.CallableReturnType(TSelector).?));

        prev_iter: TPrevIter,
        slice_iter: ?Iterator(meta.CallableReturnType(TSelector).?),
        selector: meta.ConstPtrWhenFn(TSelector),

        pub fn next(self: *Self) ?Item {
            if (self.slice_iter == null) {
                if (self.prev_iter.next()) |item| {
                    const slice = meta.callCallable(meta.CallableReturnType(TSelector).?, self.selector, .{item});
                    self.slice_iter = from(slice);
                } else {
                    return null;
                }
            }
            if (self.slice_iter.?.next()) |slice_item| {
                return slice_item;
            } else {
                while (self.prev_iter.next()) |item| {
                    const slice = meta.callCallable(meta.CallableReturnType(TSelector).?, self.selector, .{item});
                    self.slice_iter = from(slice);
                    if (self.slice_iter.?.next()) |slice_item| {
                        return slice_item;
                    }
                }
            }
            return null;
        }

        pub usingnamespace enumerable;
    };
}

/// Yields items in a sliding window of a specified size.
pub inline fn window(
    self: anytype,
    comptime window_size: usize,
) WindowIterator(Iterator(@TypeOf(self)), window_size) {
    return .{
        .prev_iter = self.*,
        .maybe_window = null,
    };
}

test window {
    try expectEqualIter(
        &[_][3]u8{
            .{ 1, 2, 3 },
            .{ 2, 3, 4 },
            .{ 3, 4, 5 },
        },
        from(&[_]u8{ 1, 2, 3, 4, 5 }).window(3),
    );
    try expectEqualIter(
        &[_][1]u8{
            .{1},
            .{2},
            .{3},
            .{4},
            .{5},
        },
        from(&[_]u8{ 1, 2, 3, 4, 5 }).window(1),
    );
    try expectEqualIter(
        &[_][5]u8{
            .{ 1, 2, 3, 4, 5 },
        },
        from(&[_]u8{ 1, 2, 3, 4, 5 }).window(5),
    );
    try expectEqualIter(
        &[_][6]u8{},
        from(&[_]u8{ 1, 2, 3, 4, 5 }).window(6),
    );
}

pub fn WindowIterator(
    comptime TPrevIter: type,
    comptime window_size: usize,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);

        prev_iter: TPrevIter,
        maybe_window: ?[window_size]Item,

        pub fn next(self: *Self) ?[window_size]Item {
            if (self.maybe_window) |*window_buffer| {
                var index: usize = 0;
                while (index < window_size - 1) {
                    window_buffer[index] = window_buffer[index + 1];
                    index += 1;
                }
                if (self.prev_iter.next()) |item| {
                    window_buffer[index] = item;
                    return window_buffer.*;
                } else {
                    return null;
                }
            } else {
                self.maybe_window = .{0} ** window_size;
                var index: usize = 0;
                while (index < window_size) {
                    if (self.prev_iter.next()) |item| {
                        self.maybe_window.?[index] = item;
                    } else {
                        return null;
                    }
                    index += 1;
                }
                return self.maybe_window;
            }
        }

        pub usingnamespace enumerable;
    };
}

/// Aggregates items in the sequence using the given selector function and seed value.
/// Returns an iterator that yields intermediate results.
pub inline fn scan(
    self: anytype,
    selector: anytype,
    seed: meta.CallableReturnType(@TypeOf(selector)).?,
) ScanIterator(Iterator(@TypeOf(self)), @TypeOf(selector)) {
    return .{
        .prev_iter = self.*,
        .selector = selector,
        .state = seed,
    };
}

test scan {
    const add = struct {
        fn f(a: u8, b: u8) u8 {
            return a + b;
        }
    }.f;
    try expectEqualIter(
        &[_]u8{ 1, 3, 6, 10, 15 },
        from(&[_]u8{ 1, 2, 3, 4, 5 }).scan(add, 0),
    );
}

pub fn ScanIterator(
    comptime TPrevIter: type,
    comptime TSelector: type,
) type {
    return struct {
        const Self = @This();
        const Item = meta.CallableReturnType(TSelector).?;

        prev_iter: TPrevIter,
        state: Item,
        selector: meta.ConstPtrWhenFn(TSelector),

        pub fn next(self: *Self) ?Item {
            if (self.prev_iter.next()) |item| {
                self.state = meta.callCallable(Item, self.selector, .{ self.state, item });
                return self.state;
            }
            return null;
        }

        pub usingnamespace enumerable;
    };
}

/// Aggregates items in the sequence using the given selector function and seed value.
/// Finishes iterations immediately and returns the final result.
pub inline fn aggregate(
    self: anytype,
    selector: anytype,
    seed: meta.CallableReturnType(@TypeOf(selector)).?,
) meta.CallableReturnType(@TypeOf(selector)).? {
    const TResult = meta.CallableReturnType(@TypeOf(selector)).?;
    var self_copy = self.*;
    var result = seed;
    while (self_copy.next()) |item| {
        result = meta.callCallable(TResult, selector, .{ result, item });
    }
    return result;
}

test aggregate {
    const add = struct {
        fn f(a: u8, b: u8) u8 {
            return a + b;
        }
    }.f;
    try std.testing.expectEqual(
        @as(u8, 15),
        from(&[_]u8{ 1, 2, 3, 4, 5 }).aggregate(add, 0),
    );
}

/// Determines whether the sequence contains a specified `needle` item.
pub inline fn contains(
    self: anytype,
    needle: IteratorItem(@TypeOf(self)),
) bool {
    var self_copy = self.*;
    while (self_copy.next()) |item| {
        if (item == needle) {
            return true;
        }
    }
    return false;
}
test contains {
    try std.testing.expectEqual(true, from(&[_]u8{ 1, 2, 3 }).contains(2));
    try std.testing.expectEqual(false, from(&[_]u8{ 1, 2, 3 }).contains(4));
}

/// Determines whether the two sequences are equal.
pub inline fn equals(
    self: anytype,
    other_iter: anytype,
) bool {
    var self_copy = self.*;
    var other_copy = other_iter;
    while (true) {
        const first_item = self_copy.next();
        const second_item = other_copy.next();

        if (first_item == null and second_item == null) {
            return true;
        }

        if (first_item != second_item) {
            return false;
        }
    }
}

test equals {
    try std.testing.expect(
        from(&[_]u8{ 1, 2, 3 }).equals(from(&[_]u8{ 1, 2, 3 })),
    );
    try std.testing.expect(
        !from(&[_]u8{ 1, 2, 3 }).equals(from(&[_]u8{ 1, 2, 3, 4 })),
    );
    try std.testing.expect(
        !from(&[_]u8{ 1, 2 }).equals(from(&[_]u8{ 1, 2, 3 })),
    );
    try std.testing.expect(
        !from(&[_]u8{ 1, 2, 3 }).equals(from(&[_]u8{ 1, 2, 4 })),
    );
}

/// Returns the index of the first occurrence of a `needle` value in the sequence
/// or `null` if value is not found.
pub inline fn indexOf(self: anytype, needle: IteratorItem(@TypeOf(self))) ?usize {
    var self_copy = self.*;
    var index: usize = 0;
    while (self_copy.next()) |item| {
        if (item == needle) {
            return index;
        }
        index += 1;
    }
    return null;
}

test indexOf {
    try std.testing.expectEqual(@as(?usize, 0), from(&[_]u8{ 1, 2, 3, 4, 5 }).indexOf(1));
    try std.testing.expectEqual(@as(?usize, 2), from("abcd").indexOf('c'));
    try std.testing.expectEqual(@as(?usize, 4), from(&[_]u8{ 1, 2, 3, 4, 5 }).indexOf(5));
    try std.testing.expectEqual(@as(?usize, null), from(&[_]u8{ 1, 2, 3, 4, 5 }).indexOf(7));
}

/// Concatenates two sequences.
pub inline fn concat(
    self: anytype,
    other: anytype,
) ConcatIterator(@TypeOf(self.*), @TypeOf(from(other))) {
    return .{
        .prev_iter = self.*,
        .next_iter = from(other),
    };
}

test concat {
    try expectEqualIter("abcdef", from("abc").concat(from("def")));
    try expectEqualIter("abcdef", from("abc").concat("def"));
}

pub fn ConcatIterator(
    comptime TPrevIter: type,
    comptime TNextIter: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);

        prev_iter: TPrevIter,
        next_iter: TNextIter,

        pub fn next(self: *Self) ?Item {
            return self.prev_iter.next() orelse self.next_iter.next() orelse null;
        }

        pub usingnamespace enumerable;
    };
}

/// Filters the items in the sequence to exclude all items from the other sequence.
pub inline fn except(
    self: anytype,
    other: anytype,
) ExceptIterator(@TypeOf(self.*), @TypeOf(from(other))) {
    return .{
        .prev_iter = self.*,
        .other_iter = from(other),
    };
}

test except {
    try expectEqualIter("ace", from("abcdef").except("bdf"));
    try expectEqualIter("", from("abc").except("abc"));
    try expectEqualIter("", from("abc").except("cba"));
    try expectEqualIter("abc", from("abc").except("def"));
    try expectEqualIter("", from("").except("abc"));
}

pub fn ExceptIterator(
    comptime TPrevIter: type,
    comptime TOtherIter: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);

        prev_iter: TPrevIter,
        other_iter: TOtherIter,

        pub fn next(self: *Self) ?Item {
            while (self.prev_iter.next()) |item| {
                if (!self.other_iter.contains(item)) {
                    return item;
                }
            }
            return null;
        }

        pub usingnamespace enumerable;
    };
}

/// Combines the items of two sequences into a single sequence of pairs.
///
/// The first element of the pair comes from the first sequence, and the second element comes from the second sequence.
pub inline fn zip(
    self: anytype,
    other_iter: anytype,
) ZipIterator(@TypeOf(self.*), @TypeOf(other_iter)) {
    return .{
        .prev_iter = self.*,
        .other_iter = other_iter,
    };
}

test zip {
    try expectEqualIter(
        &[_]struct { u8, u8 }{ .{ 1, 4 }, .{ 2, 5 }, .{ 3, 6 } },
        from(&[_]u8{ 1, 2, 3 }).zip(from(&[_]u8{ 4, 5, 6 })),
    );
}

pub fn ZipIterator(
    comptime TPrevIter: type,
    comptime TOtherIter: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);
        const OtherItem = IteratorItem(TOtherIter);

        prev_iter: TPrevIter,
        other_iter: TOtherIter,

        pub fn next(self: *Self) ?struct { Item, OtherItem } {
            if (self.prev_iter.next()) |first_item| {
                if (self.other_iter.next()) |second_item| {
                    return .{ first_item, second_item };
                }
            }
            return null;
        }

        pub usingnamespace enumerable;
    };
}

/// Appends an item to the end of the sequence.
pub inline fn append(
    self: anytype,
    item: IteratorItem(@TypeOf(self)),
) AppendIterator(@TypeOf(self.*)) {
    return .{
        .prev_iter = self.*,
        .appended_item = item,
    };
}

test append {
    try expectEqualIter("abc", from("ab").append('c'));
}

pub fn AppendIterator(
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);

        prev_iter: TPrevIter,
        appended_item: ?Item,

        pub fn next(self: *Self) ?Item {
            if (self.prev_iter.next()) |item| {
                return item;
            } else if (self.appended_item) |appended_item| {
                self.appended_item = null;
                return appended_item;
            } else {
                return null;
            }
        }

        pub usingnamespace enumerable;
    };
}

/// Prepends an item to the start of the sequence.
pub inline fn prepend(
    self: anytype,
    item: IteratorItem(@TypeOf(self)),
) PrependIterator(@TypeOf(self.*)) {
    return .{
        .prev_iter = self.*,
        .prepended_item = item,
    };
}

test prepend {
    try expectEqualIter("abc", from("bc").prepend('a'));
}

pub fn PrependIterator(
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);

        prev_iter: TPrevIter,
        prepended_item: ?Item,

        pub fn next(self: *Self) ?Item {
            if (self.prepended_item) |appended_item| {
                self.prepended_item = null;
                return appended_item;
            } else if (self.prev_iter.next()) |item| {
                return item;
            } else {
                return null;
            }
        }

        pub usingnamespace enumerable;
    };
}

/// Adds a separator item between adjacent items of the original sequence.
pub inline fn intersperse(
    self: anytype,
    separator: IteratorItem(@TypeOf(self)),
) IntersperseIterator(@TypeOf(self.*)) {
    return .{
        .prev_iter = self.peekable(),
        .delimiter = separator,
        .next_is_delimiter = false,
    };
}

test intersperse {
    try expectEqualIter("a_b_c_d", from("abcd").intersperse('_'));
}

pub fn IntersperseIterator(
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);

        prev_iter: PeekableIterator(TPrevIter),
        delimiter: ?Item,
        next_is_delimiter: bool,

        pub fn next(self: *Self) ?Item {
            if (self.prev_iter.peek()) |_| {
                if (self.next_is_delimiter) {
                    self.next_is_delimiter = false;
                    return self.delimiter;
                } else {
                    self.next_is_delimiter = true;
                    return self.prev_iter.next();
                }
            }
            return null;
        }

        pub usingnamespace enumerable;
    };
}

/// Returns an iterator, which can peek the next value without advancing the sequence.
pub inline fn peekable(
    self: anytype,
) PeekableIterator(@TypeOf(self.*)) {
    return .{
        .prev_iter = self.*,
        .peeked_item = null,
    };
}

pub fn PeekableIterator(
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);

        prev_iter: TPrevIter,
        peeked_item: ??Item,

        pub fn next(self: *Self) ?Item {
            if (self.peeked_item) |item| {
                self.peeked_item = null;
                return item;
            }
            return self.prev_iter.next();
        }

        pub fn peek(self: *Self) ?Item {
            if (self.peeked_item) |item| {
                return item;
            } else if (self.next()) |item| {
                self.peeked_item = item;
                return item;
            } else {
                return null;
            }
        }

        pub usingnamespace enumerable;
    };
}

/// Return the specified number of items from the start of the sequence,
/// or fewer if the sequence finishes sooner.
pub inline fn take(
    self: anytype,
    item_count: usize,
) TakeIterator(@TypeOf(self.*)) {
    return .{
        .prev_iter = self.*,
        .index = 0,
        .count = item_count,
    };
}

test take {
    try expectEqualIter("abc", from("abcdef").take(3));
    try expectEqualIter("abc", from("abc").take(6));
}

pub fn TakeIterator(
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);

        prev_iter: TPrevIter,
        count: usize,
        index: usize,

        pub fn next(self: *Self) ?Item {
            if (self.index < self.count) {
                self.index += 1;
                return self.prev_iter.next() orelse null;
            }
            return null;
        }

        pub usingnamespace enumerable;
    };
}

/// Return every nth item of the sequence.
pub inline fn takeEvery(
    self: anytype,
    every_nth: usize,
) TakeEveryIterator(@TypeOf(self.*)) {
    return .{
        .prev_iter = self.*,
        .every_nth = every_nth,
    };
}

test takeEvery {
    try expectEqualIter("2468", from("123456789").takeEvery(2));
}

pub fn TakeEveryIterator(
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);

        prev_iter: TPrevIter,
        every_nth: usize,

        pub fn next(self: *Self) ?Item {
            var skipped: usize = 0;
            while (skipped < self.every_nth - 1) {
                _ = self.prev_iter.next();
                skipped += 1;
            }
            return self.prev_iter.next();
        }

        pub usingnamespace enumerable;
    };
}

/// Returns items as long as the condition function returns `true`.
/// Stops when the condition function returns `false` for the first time.
pub inline fn takeWhile(
    self: anytype,
    predicate: anytype,
) TakeWhileIterator(@TypeOf(self.*), @TypeOf(predicate)) {
    return .{
        .prev_iter = self.*,
        .completed = false,
        .predicate = predicate,
    };
}

test takeWhile {
    const even = struct {
        fn f(number: u8) bool {
            return @rem(number, 2) == 0;
        }
    }.f;
    try expectEqualIter(
        &[_]u8{ 2, 4, 6 },
        from(&[_]u8{ 2, 4, 6, 7, 8, 9, 10 }).takeWhile(even),
    );
    try expectEqualIter(
        &[_]u8{ 2, 4, 6, 8, 10 },
        from(&[_]u8{ 2, 4, 6, 8, 10 }).takeWhile(even),
    );
    try expectEqualIter(
        &[_]u8{},
        from(&[_]u8{ 1, 2, 3, 4, 5 }).takeWhile(even),
    );
}

pub fn TakeWhileIterator(
    comptime TPrevIter: type,
    comptime TSelector: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);

        prev_iter: TPrevIter,
        completed: bool,
        predicate: meta.ConstPtrWhenFn(TSelector),

        pub fn next(self: *Self) ?Item {
            if (self.completed) {
                return null;
            } else if (self.prev_iter.next()) |item| {
                if (meta.callCallable(bool, self.predicate, .{item})) {
                    return item;
                } else {
                    self.completed = true;
                    return null;
                }
            } else {
                return null;
            }
        }

        pub usingnamespace enumerable;
    };
}

/// Collects the sequence into an array list.
pub inline fn toArrayList(
    self: anytype,
    allocator: std.mem.Allocator,
) !std.ArrayList(IteratorItem(@TypeOf(self))) {
    var self_copy = self.*;
    var array_list = std.ArrayList(IteratorItem(@TypeOf(self))).init(allocator);
    while (self_copy.next()) |item| {
        try array_list.append(item);
    }
    return array_list;
}

test toArrayList {
    var arrayList = try countdown(@as(u8, 4)).toArrayList(std.testing.allocator);
    defer arrayList.deinit();
    try std.testing.expectEqualSlices(u8, &[_]u8{ 3, 2, 1, 0 }, arrayList.items);
}

/// Skips a specified number of items in the sequence and then returns the remaining items.
pub inline fn skip(
    self: anytype,
    item_count: usize,
) SkipIterator(@TypeOf(self.*)) {
    return .{
        .prev_iter = self.*,
        .index = 0,
        .count = item_count,
    };
}

test skip {
    try expectEqualIter(
        &[_]u8{ 4, 5, 6, 7, 8, 9, 10 },
        from(&[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }).skip(3),
    );
    try expectEqualIter(
        &[_]u8{},
        from(&[_]u8{ 1, 2, 3 }).skip(3),
    );
}

pub fn SkipIterator(
    comptime TPrevIter: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);

        prev_iter: TPrevIter,
        count: usize,
        index: usize,

        pub fn next(self: *Self) ?Item {
            while (self.index < self.count) {
                _ = self.prev_iter.next();
                self.index += 1;
            }
            return self.prev_iter.next() orelse null;
        }

        pub usingnamespace enumerable;
    };
}

/// Skips items while the condition function returns `true` and then returns the remaining items.
pub inline fn skipWhile(
    self: anytype,
    predicate: anytype,
) SkipWhileIterator(@TypeOf(self.*), @TypeOf(predicate)) {
    return .{
        .prev_iter = self.*,
        .skipping_is_done = false,
        .predicate = predicate,
    };
}

test skipWhile {
    const even = struct {
        fn f(number: u8) bool {
            return @rem(number, 2) == 0;
        }
    }.f;
    try expectEqualIter(
        &[_]u8{ 7, 8, 9, 10 },
        from(&[_]u8{ 2, 4, 6, 7, 8, 9, 10 }).skipWhile(even),
    );
    try expectEqualIter(
        &[_]u8{},
        from(&[_]u8{ 2, 4, 6, 8 }).skipWhile(even),
    );
    try expectEqualIter(
        &[_]u8{ 1, 2, 3, 4 },
        from(&[_]u8{ 1, 2, 3, 4 }).skipWhile(even),
    );
}

pub fn SkipWhileIterator(
    comptime TPrevIter: type,
    comptime TPredicate: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);

        prev_iter: TPrevIter,
        skipping_is_done: bool,
        predicate: meta.ConstPtrWhenFn(TPredicate),

        pub fn next(self: *Self) ?Item {
            if (!self.skipping_is_done) {
                while (self.prev_iter.next()) |item| {
                    if (!meta.callCallable(bool, self.predicate, .{item})) {
                        self.skipping_is_done = true;
                        return item;
                    }
                }
            }

            return self.prev_iter.next();
        }

        pub usingnamespace enumerable;
    };
}

/// Calls a function on each item of the sequence.
pub inline fn forEach(
    self: anytype,
    function: anytype,
) void {
    const TFunction = meta.ConstPtrWhenFn(@TypeOf(function));
    const TReturn = meta.CallableReturnType(TFunction).?;
    var self_copy = self.*;
    while (self_copy.next()) |item| {
        _ = meta.callCallable(TReturn, function, .{item});
        function(item);
    }
}
test forEach {
    const printItem = struct {
        fn f(item: u8) void {
            std.debug.print("\n Item: {}", .{item});
        }
    }.f;
    var iter = from(&[_]u8{ 1, 2, 3 });
    iter.forEach(printItem);
}

/// Calls a function on each item of the sequence and yields the item.
///
/// Useful for inspecting a chain of iterators at any particular point.
pub inline fn inspect(
    self: anytype,
    function: anytype,
) InspectIterator(@TypeOf(self.*), @TypeOf(function)) {
    return .{
        .prev_iter = self.*,
        .function = function,
    };
}

test inspect {
    const printItem = struct {
        fn f(item: u8) void {
            std.debug.print("\n Item: {}", .{item});
        }
    }.f;
    _ = from(&[_]u8{ 1, 2, 3 }).inspect(printItem);
}

pub fn InspectIterator(
    comptime TPrevIter: type,
    comptime TFunction: type,
) type {
    return struct {
        const Self = @This();
        const Item = IteratorItem(TPrevIter);

        prev_iter: TPrevIter,
        function: meta.ConstPtrWhenFn(TFunction),

        pub fn next(self: *Self) ?Item {
            if (self.prev_iter.next()) |item| {
                const TReturn = meta.CallableReturnType(@TypeOf(self.function)).?;
                meta.callCallable(TReturn, self.function, .{item});
                return item;
            }
            return null;
        }

        pub usingnamespace enumerable;
    };
}

/// Returns the maximum item in a sequence.
///
/// Returns `null` if the sequence is empty.
pub inline fn max(self: anytype) ?IteratorItem(@TypeOf(self)) {
    var self_copy = self.*;
    var maybe_max_value: ?IteratorItem(@TypeOf(self)) = null;
    while (self_copy.next()) |item| {
        if (maybe_max_value == null or item > maybe_max_value.?) {
            maybe_max_value = item;
        }
    }
    return maybe_max_value;
}

test max {
    try std.testing.expectEqual(@as(?u8, 5), from(&[_]u8{ 1, 2, 3, 4, 5 }).max());
    try std.testing.expectEqual(@as(?u8, 6), from(&[_]u8{ 1, 6, 3, 4, 5 }).max());
    try std.testing.expectEqual(@as(?u8, null), from(&[_]u8{}).max());
}

/// Returns the maximum item of a sequence as determined by the value returned from the selector function.
///
/// Returns `null` if the sequence is empty.
pub inline fn maxBy(
    self: anytype,
    selector: anytype,
) ?IteratorItem(@TypeOf(self)) {
    const TSelectorReturn = meta.CallableReturnType(@TypeOf(selector)).?;
    var self_copy = self.*;
    var maybe_max_item: ?IteratorItem(@TypeOf(self)) = null;
    var maybe_max_value: ?TSelectorReturn = null;
    while (self_copy.next()) |item| {
        const current_value = meta.callCallable(TSelectorReturn, selector, .{item});
        if (maybe_max_value == null or current_value > maybe_max_value.?) {
            maybe_max_item = item;
            maybe_max_value = current_value;
        }
    }
    return maybe_max_item;
}

test maxBy {
    const Person = struct {
        name: []const u8,
        age: u8,
        pub fn getAge(self: @This()) u8 {
            return self.age;
        }
    };
    try std.testing.expectEqual(
        Person{ .name = "John", .age = 5 },
        from(&[_]Person{
            .{ .name = "Marry", .age = 1 },     .{ .name = "Dave", .age = 2 },
            .{ .name = "Gerthrude", .age = 3 }, .{ .name = "Casper", .age = 4 },
            .{ .name = "John", .age = 5 },
        }).maxBy(Person.getAge).?,
    );
}

/// Returns the minimum item of a sequence.
///
/// Returns `null` if the sequence is empty.
pub inline fn min(self: anytype) ?IteratorItem(@TypeOf(self)) {
    const TItem = IteratorItem(@TypeOf(self));
    var self_copy = self.*;
    var maybe_min_value: ?TItem = null;
    while (self_copy.next()) |item| {
        if (maybe_min_value == null or item < maybe_min_value.?) {
            maybe_min_value = item;
        }
    }
    return maybe_min_value;
}

test min {
    try std.testing.expectEqual(@as(?u8, 1), from(&[_]u8{ 3, 4, 2, 1, 5 }).min());
    try std.testing.expectEqual(@as(?u8, null), from(&[_]u8{}).min());
}

/// Returns the minimum item of an sequence as determined by the value returned from the specified function.
///
/// Returns `null` if the sequence is empty.
pub inline fn minBy(
    self: anytype,
    selector: anytype,
) ?IteratorItem(@TypeOf(self)) {
    const TSelectorReturn = meta.CallableReturnType(@TypeOf(selector)).?;
    var self_copy = self.*;
    var maybe_min_item: ?IteratorItem(@TypeOf(self)) = null;
    var maybe_min_value: ?TSelectorReturn = null;
    while (self_copy.next()) |item| {
        const current_value = meta.callCallable(TSelectorReturn, selector, .{item});
        if (maybe_min_value == null or current_value < maybe_min_value.?) {
            maybe_min_item = item;
            maybe_min_value = current_value;
        }
    }
    return maybe_min_item;
}

test minBy {
    const Person = struct {
        name: []const u8,
        age: u8,
        pub fn getAge(self: @This()) u8 {
            return self.age;
        }
    };
    try std.testing.expectEqual(
        Person{ .name = "Marry", .age = 1 },
        from(&[_]Person{
            .{ .name = "Gerthrude", .age = 3 }, .{ .name = "Casper", .age = 4 },
            .{ .name = "Marry", .age = 1 },     .{ .name = "Dave", .age = 2 },
            .{ .name = "John", .age = 5 },
        }).minBy(Person.getAge).?,
    );
    try std.testing.expectEqual(
        @as(?Person, null),
        from(&[_]Person{}).minBy(Person.getAge),
    );
}

/// Namespace for functions that require mutable and indexable iterators.
const enumerable_mutable_and_indexable = struct {
    fn lessThan(_: void, lhs: u8, rhs: u8) bool {
        return lhs < rhs;
    }
    pub inline fn orderAscending(self: anytype) @TypeOf(self.*) {
        std.mem.sort(IteratorItem(@TypeOf(self)), self.slice, {}, lessThan);
        return self.*;
    }
    test orderAscending {
        var input = std.BoundedArray(u8, 8){};
        try input.appendSlice("cbdafghe");
        try expectEqualIter("abcdefgh", enumerable.from(input.slice()).orderAscending());
    }
};

/// Returns whether the items in the sequence are sorted in ascending order.
pub inline fn isSortedAscending(self: anytype) bool {
    var self_copy = self.*;
    var maybe_previous: ?IteratorItem(@TypeOf(self)) = null;
    while (self_copy.next()) |item| {
        if (maybe_previous) |previous| {
            if (previous > item) {
                return false;
            }
        }
        maybe_previous = item;
    }
    return true;
}

test isSortedAscending {
    try std.testing.expectEqual(true, from(&[_]u8{ 1, 2, 3 }).isSortedAscending());
    try std.testing.expectEqual(false, from(&[_]u8{ 1, 3, 2 }).isSortedAscending());
}

/// Returns whether the items in the sequence are sorted in descending order.
pub inline fn isSortedDescending(self: anytype) bool {
    var self_copy = self.*;
    var maybe_previous: ?IteratorItem(@TypeOf(self)) = null;
    while (self_copy.next()) |item| {
        if (maybe_previous) |previous| {
            if (previous < item) {
                return false;
            }
        }
        maybe_previous = item;
    }
    return true;
}

test isSortedDescending {
    try std.testing.expectEqual(true, from(&[_]u8{ 3, 2, 1 }).isSortedDescending());
    try std.testing.expectEqual(false, from(&[_]u8{ 3, 1, 2 }).isSortedDescending());
}

/// Returns whether the items in the sequence are sorted in ascending order
/// based on the values returned from the specified selector.
pub inline fn isSortedAscendingBy(
    self: anytype,
    selector: anytype,
) bool {
    const TSelectorReturn = meta.CallableReturnType(@TypeOf(selector)).?;
    var self_copy = self.*;
    var maybe_previous_value: ?TSelectorReturn = null;
    while (self_copy.next()) |current_item| {
        const current_value = meta.callCallable(TSelectorReturn, selector, .{current_item});
        if (maybe_previous_value) |previous_value| {
            if (previous_value > current_value) {
                return false;
            }
        }
        maybe_previous_value = current_value;
    }
    return true;
}

test isSortedAscendingBy {
    const Person = struct {
        name: []const u8,
        age: u8,
        pub fn getAge(self: @This()) u8 {
            return self.age;
        }
    };
    try std.testing.expectEqual(
        true,
        from(&[_]Person{
            .{ .name = "Marry", .age = 1 },
            .{ .name = "Dave", .age = 2 },
            .{ .name = "Gerthrude", .age = 3 },
            .{ .name = "Casper", .age = 4 },
            .{ .name = "John", .age = 5 },
        }).isSortedAscendingBy(Person.getAge),
    );
    try std.testing.expectEqual(
        false,
        from(&[_]Person{
            .{ .name = "Marry", .age = 1 },
            .{ .name = "Dave", .age = 3 },
            .{ .name = "Gerthrude", .age = 2 },
            .{ .name = "Casper", .age = 1 },
            .{ .name = "John", .age = 5 },
        }).isSortedAscendingBy(Person.getAge),
    );
}

/// Returns whether the items in the sequence are sorted in descending order
/// based on the values returned from the specified selector.
pub inline fn isSortedDescendingBy(
    self: anytype,
    selector: anytype,
) bool {
    const TSelectorReturn = meta.CallableReturnType(@TypeOf(selector)).?;
    var self_copy = self.*;
    var maybe_previous_value: ?TSelectorReturn = null;
    while (self_copy.next()) |current_item| {
        const current_value = meta.callCallable(TSelectorReturn, selector, .{current_item});
        if (maybe_previous_value) |previous_value| {
            if (previous_value < current_value) {
                return false;
            }
        }
        maybe_previous_value = current_value;
    }
    return true;
}

test isSortedDescendingBy {
    const Person = struct {
        name: []const u8,
        age: u8,
        pub fn getAge(self: @This()) u8 {
            return self.age;
        }
    };
    try std.testing.expectEqual(
        true,
        from(&[_]Person{
            .{ .name = "Marry", .age = 5 },
            .{ .name = "Dave", .age = 4 },
            .{ .name = "Gerthrude", .age = 3 },
            .{ .name = "Casper", .age = 2 },
            .{ .name = "John", .age = 1 },
        }).isSortedDescendingBy(Person.getAge),
    );
    try std.testing.expectEqual(
        false,
        from(&[_]Person{
            .{ .name = "Marry", .age = 3 },
            .{ .name = "Dave", .age = 1 },
            .{ .name = "Gerthrude", .age = 2 },
            .{ .name = "Casper", .age = 1 },
            .{ .name = "John", .age = 5 },
        }).isSortedAscendingBy(Person.getAge),
    );
}

/// Returns the average value of all the numbers in the sequence.
pub inline fn average(self: anytype) IteratorItem(@TypeOf(self)) {
    const TItem = IteratorItem(@TypeOf(self));
    var self_copy = self.*;
    var total_sum: TItem = 0;
    var total_count: usize = 0;
    while (self_copy.next()) |item| {
        total_sum += item;
        total_count += 1;
    }
    const item_type_info = @typeInfo(TItem);
    if (item_type_info == .Float) {
        return total_sum / @as(TItem, @floatFromInt(total_count));
    } else if (item_type_info == .Int) {
        if (item_type_info.Int.signedness == .unsigned) {
            return total_sum / @as(TItem, @intCast(total_count));
        } else {
            @compileError("Signed integer type '" ++ @typeName(TItem) ++ "' should be used either with .averageTrunc() or .averageFloor()");
        }
    } else {
        @compileError("Iterators with item type '" ++ @typeName(TItem) ++ "' do not support .average().");
    }
}

test average {
    try std.testing.expectEqual(@as(f32, 2.5), sequence(f32, 1, 5).average());
    try std.testing.expectEqual(@as(u32, 2), sequence(u32, 1, 5).average());
}

/// Returns a truncated average value of all the numbers in the sequence.
///
/// Negative values round towards 0.
pub inline fn averageTrunc(self: anytype) IteratorItem(@TypeOf(self)) {
    const TItem = IteratorItem(@TypeOf(self));
    var self_copy = self.*;
    var total_sum: TItem = 0;
    var total_count: usize = 0;
    while (self_copy.next()) |item| {
        total_sum += item;
        total_count += 1;
    }
    const item_type_info = @typeInfo(TItem);
    if (item_type_info == .Int) {
        return @divTrunc(total_sum, @as(TItem, @intCast(total_count)));
    } else {
        @compileError("Iterators with item type '" ++ @typeName(TItem) ++ "' do not support .averageTrunc().");
    }
}

test averageTrunc {
    try std.testing.expectEqual(@as(i32, -1), from(&[_]i32{ -1, -2, -2 }).averageTrunc());
}

/// Returns a floored average value of all the numbers in the sequence.
///
/// Negative values round towards negative infinity.
pub inline fn averageFloor(self: anytype) IteratorItem(@TypeOf(self)) {
    const TItem = IteratorItem(@TypeOf(self));
    var self_copy = self.*;
    var total_sum: TItem = 0;
    var total_count: usize = 0;
    while (self_copy.next()) |item| {
        total_sum += item;
        total_count += 1;
    }
    const item_type_info = @typeInfo(TItem);
    if (item_type_info == .Int) {
        return @divFloor(total_sum, @as(TItem, @intCast(total_count)));
    } else {
        @compileError("Iterators with item type '" ++ @typeName(TItem) ++ "' do not support .averageFloor().");
    }
}

test averageFloor {
    try std.testing.expectEqual(@as(i32, -2), from(&[_]i32{ -1, -2, -2 }).averageFloor());
}

/// Asserts that the provided `actual_iter` is equal to the `expected_slice`.
inline fn expectEqualIter(expected_slice: anytype, actual_iter: anytype) !void {
    const ItemType = IteratorItem(@TypeOf(actual_iter));
    var actual_array_list = std.ArrayList(ItemType).init(std.testing.allocator);
    defer actual_array_list.deinit();
    const actual_iter_ptr = &actual_iter;
    while (@constCast(actual_iter_ptr).next()) |item| {
        try actual_array_list.append(item);
    }
    const actual_slice = actual_array_list.items;
    try std.testing.expectEqualSlices(ItemType, expected_slice, actual_slice);
}

test "example" {
    try expectEqualIter(
        "(1,2,3)",
        from(std.mem.tokenizeAny(u8, "foo=1;bar=2;baz=3", "=;").buffer)
            .where(std.ascii.isDigit)
            .intersperse(',')
            .prepend('(')
            .append(')'),
    );
}
