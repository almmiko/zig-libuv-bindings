const std = @import("std");
const c = @import("c.zig");

pub const Error = error{EACCES};

pub fn convertErr(r: c_int) Error!void {
    if (r >= 0) return;

    return switch (r) {
        c.UV_EACCES => Error.EACCES,
        else => unreachable,
    };
}
