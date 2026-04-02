pub const abi = @import("abi.zig");
const tracy = @import("tracy.zig");

pub const Api = abi.Api;
pub const PlatformMemory = abi.PlatformMemory;
pub const TickContext = abi.TickContext;
pub const Frame = abi.Frame;
pub const Input = abi.Input;

pub fn Runtime(comptime App: type) type {
    comptime {
        switch (@typeInfo(App)) {
            .@"struct" => {},
            else => @compileError("work_runtime.Runtime expects a struct type"),
        }

        if (@alignOf(App) > abi.module_state_alignment) {
            @compileError("App alignment exceeds abi.module_state_alignment");
        }
    }

    return struct {
        fn state(memory: *PlatformMemory) *App {
            return @ptrCast(@alignCast(memory.permanent_storage));
        }

        fn init(memory: *PlatformMemory) callconv(.c) void {
            const app = state(memory);
            app.* = .{};

            if (@hasDecl(App, "init")) {
                App.init(app, memory);
            }
        }

        fn onReload(memory: *PlatformMemory) callconv(.c) void {
            if (@hasDecl(App, "onReload")) {
                App.onReload(state(memory), memory);
            }
        }

        fn update(memory: *PlatformMemory, ctx: TickContext) callconv(.c) void {
            var zone = tracy.zoneN("work_update");
            defer zone.end();

            if (@hasDecl(App, "update")) {
                App.update(state(memory), memory, ctx);
            }
        }

        fn render(memory: *PlatformMemory, ctx: TickContext, frame: *Frame) callconv(.c) void {
            var zone = tracy.zoneN("work_render");
            defer zone.end();

            if (@hasDecl(App, "render")) {
                App.render(state(memory), memory, ctx, frame);
            }
        }

        const api_value = Api{
            .abi_version = abi.abi_version,
            .required_permanent_storage_size = @sizeOf(App),
            .required_transient_storage_size = if (@hasDecl(App, "required_transient_storage_size"))
                @as(u64, App.required_transient_storage_size)
            else
                0,
            .init = &init,
            .on_reload = &onReload,
            .update = &update,
            .render = &render,
        };

        pub fn api() *const Api {
            return &api_value;
        }
    };
}

