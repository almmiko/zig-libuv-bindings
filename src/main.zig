const std = @import("std");
const c = @import("c.zig");
const errors = @import("errors.zig");
const Allocator = std.mem.Allocator;

pub const Loop = struct {
    loop: *c.uv_loop_t,

    pub fn init(alloc: Allocator) !Loop {
        const loop = try alloc.create(c.uv_loop_t);
        try errors.convertErr(c.uv_loop_init(loop));

        return Loop{ .loop = loop };
    }

    pub fn deinit(self: Loop, alloc: Allocator) void {
        // todo: better error handling
        errors.convertErr(c.uv_loop_close(self.loop)) catch unreachable;
        alloc.destroy(self.loop);
    }

    pub fn createTimer(self: Loop, delay: u64, repeat: u64) !void {
        const alloc = std.heap.c_allocator;

        const Wrapper = struct {
            pub fn callback(handle: [*c]c.uv_timer_t) callconv(.C) void {
                _ = handle;
                std.debug.print("hello from c\n", .{});
            }
        };

        var timer = try alloc.create(c.uv_timer_t);
        _ = c.uv_timer_init(self.loop, timer);

        _ = c.uv_timer_start(timer, Wrapper.callback, delay, repeat);
        _ = c.uv_run(self.loop, c.UV_RUN_DEFAULT);
    }
};

/// Initialize a new uv_loop.
pub fn init(alloc: Allocator) !void {
    // std.debug.print("{}", .{c.UV_RUN_DEFAULT});
    const loop = try alloc.create(c.uv_loop_t);

    // std.debug.print("{}", .{loop});
    _ = c.uv_loop_init(loop);

    defer _ = c.uv_loop_close(loop);
    defer alloc.destroy(loop);

    const Wrapper = struct {
        pub fn callback(handle: [*c]c.uv_timer_t) callconv(.C) void {
            _ = handle;
            std.debug.print("hello from c\n", .{});
        }
    };

    var timer = try alloc.create(c.uv_timer_t);
    _ = c.uv_timer_init(loop, timer);

    _ = c.uv_timer_start(timer, Wrapper.callback, 100, 1000);

    _ = c.uv_run(loop, c.UV_RUN_DEFAULT);
    // const loop = c.uv_default_loop();
    // _ = loop;
    //
    // std.debug.print("default loop", .{});

    // _ = c.uv_run(loop, c.UV_RUN_DEFAULT);
    //
    // _ = c.uv_loop_close(loop);

    // uv_loop_t *loop = uv_default_loop();
    //
    // printf("Default loop.\n");
    // uv_run(loop, UV_RUN_DEFAULT);
    //
    // uv_loop_close(loop);
}

pub fn main() !void {
    //   uv_loop_t *loop = malloc(sizeof(uv_loop_t));
    // uv_loop_init(loop);
    //
    // printf("Now quitting.\n");
    // uv_run(loop, UV_RUN_DEFAULT);
    //
    // uv_loop_close(loop);
    // free(loop);

    const alloc = std.heap.c_allocator;

    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    //
    // const allocator = arena.allocator();

    const loop = try Loop.init(alloc);

    _ = try loop.createTimer(200, 1000);
    defer loop.deinit(alloc);

    // _ = try init(alloc);
}
