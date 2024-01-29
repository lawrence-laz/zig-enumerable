pub fn ConstPtrWhenFn(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .Fn => *const T,
        else => T,
    };
}

pub inline fn CallableReturnType(comptime TCallable: type) ?type {
    return switch (@typeInfo(TCallable)) {
        .Fn => |info| info.return_type,
        .Pointer => |info| switch (@typeInfo(info.child)) {
            .Fn => |child_info| child_info.return_type,
            .Struct => ClosureReturnType(TCallable),
            else => @compileError("Unable to use '" ++ @typeName(TCallable) ++ "' as a function."),
        },
        .Struct => ClosureReturnType(TCallable),
        else => @compileError("Unable to use '" ++ @typeName(TCallable) ++ "' as a function."),
    };
}

pub inline fn ClosureReturnType(comptime TClosure: type) ?type {
    const type_info = @typeInfo(TClosure);
    if (type_info.Struct.decls.len != 1) {
        @compileError("Unable to use '" ++ @typeName(TClosure) ++ "' as a function. " ++
            "To use struct as a closure make sure it has a single public function accepting " ++
            "`@This()` and `TItem` as parameters.");
    }
    const decl_name = type_info.Struct.decls[0].name;
    const decl = @field(TClosure, decl_name);
    const decl_info = @typeInfo(@TypeOf(decl));
    return decl_info.Fn.return_type;
}

pub inline fn callCallable(comptime TReturn: type, callable: anytype, arguments: anytype) TReturn {
    return switch (@typeInfo(@TypeOf(callable))) {
        .Fn => return @call(.auto, callable, arguments),
        .Pointer => |info| switch (@typeInfo(info.child)) {
            .Fn => return @call(.auto, callable, arguments),
            .Struct => callClosure(TReturn, callable.*, arguments),
            else => @compileError("Unable to use '" ++ @typeName(@TypeOf(callable)) ++ "' as a function."),
        },
        .Struct => callClosure(TReturn, callable, arguments),
        else => @compileError("Unable to use '" ++ @typeName(@TypeOf(callable)) ++ "' as a function."),
    };
}

pub inline fn callClosure(
    comptime TReturn: type,
    closure: anytype,
    arguments: anytype,
) TReturn {
    const type_info = @typeInfo(@TypeOf(closure));
    if (type_info.Struct.decls.len != 1) {
        @compileError("Unable to use '" ++ @typeName(@TypeOf(closure)) ++ "' as a function. " ++
            "To use struct as a closure make sure it has a single public function accepting " ++
            "`@This()` and `TItem` as parameters.");
    }
    const function_name = type_info.Struct.decls[0].name;
    const field = @field(@TypeOf(closure), function_name);
    return @call(.auto, field, .{closure} ++ arguments);
}
