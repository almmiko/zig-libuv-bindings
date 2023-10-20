const std = @import("std");
const c = @import("c.zig");
const errors = @import("errors.zig");
const Allocator = std.mem.Allocator;
const Loop = @import("Loop.zig").Loop;

pub const Timer = struct {
    timer: *c.uv_timer_t,

    pub fn init(alloc: Allocator, loop: Loop) !Timer {
        const timer = try alloc.create(c.uv_timer_t);
        try errors.convertErr(c.uv_timer_init(loop.loop, timer));

        return Timer{ .timer = timer };
    }

    pub fn deinit(self: Timer, alloc: Allocator) void {
        alloc.destroy(self.timer);
    }

    pub fn start(self: Timer, comptime cb: fn (*Timer) void, timeout: u64, repeat: u64) !void {
        const Wrapper = struct {
            pub fn callback(timer: [*c]c.uv_timer_t) callconv(.C) void {
                var newSelf: Timer = .{ .timer = timer };
                @call(.always_inline, cb, .{&newSelf});
            }
        };

        try errors.convertErr(c.uv_timer_start(
            self.timer,
            Wrapper.callback,
            timeout,
            repeat,
        ));
    }
};
