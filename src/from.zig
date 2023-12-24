const Iterator = @import("iterator.zig").Iterator;

pub fn tokenIterator(comptime TItem: type, token_iterator: anytype) Iterator(TItem, @TypeOf(token_iterator)) {
    const TokenIteratorType = @TypeOf(token_iterator);
    const token_iterator_type_info = @typeInfo(TokenIteratorType);
    if (token_iterator_type_info != .Pointer) @compileError("must be a pointer");
    if (token_iterator_type_info.Pointer.size != .One) @compileError("must be a single item pointer");
    return .{ .impl = token_iterator };
}
