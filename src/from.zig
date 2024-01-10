const std = @import("std");
const Iterator = @import("iterator.zig").Iterator;
const SliceIterator = @import("from/slice_iterator.zig").SliceIterator;
const RangeIterator = @import("from/range_iterator.zig").RangeIterator;
const RangeEveryIterator = @import("from/range_every_iterator.zig").RangeEveryIterator;

pub inline fn tokenIterator(comptime TItem: type, token_iterator: anytype) Iterator(TItem, @TypeOf(token_iterator)) {
    const TokenIteratorType = @TypeOf(token_iterator);
    const token_iterator_type_info = @typeInfo(TokenIteratorType);
    if (token_iterator_type_info != .Pointer) @compileError("must be a pointer");
    if (token_iterator_type_info.Pointer.size != .One) @compileError("must be a single item pointer");
    return .{ .impl = token_iterator };
}

pub inline fn slice(sliceArg: anytype) Iterator(std.meta.Elem(@TypeOf(sliceArg)), SliceIterator(std.meta.Elem(@TypeOf(sliceArg)))) {
    return .{ .impl = .{ .slice = sliceArg } };
}

/// Generates a sequence of numbers within a specified range.
///
/// Ex.: `enumerable.from.range(i32, 5, 10)` produces `{ 5, 6, 7, 8, 9 }`.
pub inline fn range(
    /// The type of the numbers in the sequence.
    comptime TNumber: type,
    /// The value of the first number in the sequence (inclusive).
    from_inclusive: TNumber,
    /// The value of the upper bound of the sequence (exclusive).
    to_exclusive: TNumber,
) Iterator(TNumber, RangeIterator(TNumber)) {
    return .{ .impl = RangeIterator(TNumber){
        .from_inclusive = from_inclusive,
        .to_exclusive = to_exclusive,
        .current = from_inclusive,
    } };
}

pub inline fn rangeEvery(
    comptime TNumber: type,
    from_inclusive: TNumber,
    to_exclusive: TNumber,
    step: TNumber,
) Iterator(TNumber, RangeEveryIterator(TNumber)) {
    return .{ .impl = RangeEveryIterator(TNumber){
        .from_inclusive = from_inclusive,
        .to_exclusive = to_exclusive,
        .current = from_inclusive,
        .step = step,
    } };
}

test "range(u8, ...)" {
    // Act
    var actual = range(u8, 0, 10);

    // Assert
    var expected = &[_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    var index: usize = 0;
    while (actual.next()) |actual_number| {
        try std.testing.expectEqual(expected[index], actual_number);
        index += 1;
    }
    try std.testing.expectEqual(@as(usize, 10), index);
}

test "rangeEvery(u8, ...)" {
    // Act
    var actual = rangeEvery(u8, 0, 10, 2);

    // Assert
    var expected = &[_]u8{ 0, 2, 4, 6, 8 };
    var index: usize = 0;
    while (actual.next()) |actual_number| {
        try std.testing.expectEqual(expected[index], actual_number);
        index += 1;
    }
    try std.testing.expectEqual(@as(usize, 5), index);
}
