const std = @import("std");
const c = @import("c.zig");
const errors = @import("errors.zig");
const Loop = @import("Loop.zig").Loop;
const Timer = @import("Timer.zig").Timer;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    const alloc = std.heap.c_allocator;

    const loop = try Loop.init(alloc);
    defer loop.deinit(alloc);

    const timer = try Timer.init(alloc, loop);
    defer timer.deinit(alloc);

    try timer.start((struct {
        fn cb(t: *Timer) void {
            _ = t;
            std.debug.print("hello from c \n", .{});
        }
    }).cb, 200, 1000);

    try loop.run(.default);
}
