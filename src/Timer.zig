const std = @import("std");
const c = @import("c.zig");
const errors = @import("errors.zig");
const Allocator = std.mem.Allocator;
const Loop = @import("Loop.zig").Loop;

pub const Timer = struct {
    handle: *c.uv_timer_t,

    pub fn init(alloc: Allocator, loop: Loop) !Timer {
        const handle = try alloc.create(c.uv_timer_t);
        try errors.convertErr(c.uv_timer_init(loop.loop, handle));

        return Timer{ .handle = handle };
    }

    pub fn deinit(self: Timer, alloc: Allocator) void {
        alloc.destroy(self.handle);
    }

    pub fn start(self: Timer, comptime cb: fn (*Timer) void, timeout: u64, repeat: u64) !void {
        // wrapper is used to hide implementation details related to c_uv_timer_start
        const Wrapper = struct {
            // callconv(.C) c style call convention
            // callback is a c style function which matches uv_timer_start param signature
            pub fn callback(handle: [*c]c.uv_timer_t) callconv(.C) void {
                // uv_tiemr_start will call callback with timer,
                // then we need to override the struct timer field and call the user's cb function
                var newTimer: Timer = .{ .handle = handle };
                @call(.always_inline, cb, .{&newTimer});
            }
        };

        try errors.convertErr(c.uv_timer_start(
            self.handle,
            Wrapper.callback,
            timeout,
            repeat,
        ));
    }

    pub fn stop(self: Timer) !void {
        try errors.convertErr(c.uv_timer_stop(self.handle));
    }
};

// test "Timer" {
//     const alloc = std.testing.allocator;
//
//     const loop = try Loop.init(alloc);
//     defer loop.deinit(alloc);
//
//     const timer = try Timer.init(alloc, loop);
//     defer timer.deinit(alloc);
//
//     var isTimerCalled: bool = false;
//
//     try timer.start((struct {
//         fn cb(t: *Timer) void {
//             _ = t;
//             std.debug.print("hello from c \n", .{});
//         }
//     }).cb, 200, 1000);
//
//     try loop.run();
// }
