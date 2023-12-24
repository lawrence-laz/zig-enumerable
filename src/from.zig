const std = @import("std");
const Iterator = @import("iterator.zig").Iterator;
const SliceIterator = @import("from/slice_iterator.zig").SliceIterator;
const RangeIterator = @import("from/range_iterator.zig").RangeIterator;

pub inline fn tokenIterator(comptime TItem: type, token_iterator: anytype) Iterator(TItem, @TypeOf(token_iterator)) {
    const TokenIteratorType = @TypeOf(token_iterator);
    const token_iterator_type_info = @typeInfo(TokenIteratorType);
    if (token_iterator_type_info != .Pointer) @compileError("must be a pointer");
    if (token_iterator_type_info.Pointer.size != .One) @compileError("must be a single item pointer");
    return .{ .impl = token_iterator };
}

pub inline fn slice(comptime TItem: type, sliceArg: []const TItem) Iterator(TItem, SliceIterator(TItem)) {
    return .{ .impl = SliceIterator(TItem){ .slice = sliceArg } };
}

pub inline fn range(
    comptime TNumber: type,
    from_inclusive: TNumber,
    to_exclusive: TNumber,
) Iterator(TNumber, RangeIterator(TNumber)) {
    return .{ .impl = RangeIterator(TNumber){
        .from_inclusive = from_inclusive,
        .to_exclusive = to_exclusive,
        .current = from_inclusive,
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
