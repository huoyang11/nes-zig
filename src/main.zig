const std = @import("std");
const glfw = @import("zglfw");
const gl = @import("zopengl");
const zgui = @import("zgui");

const core = @import("core/root.zig");

pub fn main11() !void {
    // 1. 初始化 GLFW
    try glfw.init();
    defer glfw.terminate();

    const gl_binding = gl.bindings;

    // 2. 创建窗口 + OpenGL 3.3 Core 上下文
    glfw.windowHint(.context_version_major, 3);
    glfw.windowHint(.context_version_minor, 3);
    glfw.windowHint(.opengl_forward_compat, true);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    glfw.windowHint(.client_api, .opengl_api);

    // 注意：glfw.Window.create 在不同版本可能需要 4 或 5 个参数，根据你的报错调整
    const window = try glfw.Window.create(1280, 720, "Zig + ImGui + OpenGL3", null, null);
    defer window.destroy();

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1); // vsync

    // 3. 加载 OpenGL 函数指针
    // 注意：zopengl 的 loadCoreProfile 签名可能因版本而异，如果报错请检查 zopengl 文档
    gl.loadCoreProfile(glfw.getProcAddress, 3, 3) catch @panic("failed to load OpenGL");

    // 4. 初始化 zgui (Dear ImGui)
    const allocator = std.heap.c_allocator;
    zgui.init(allocator);
    defer zgui.deinit();

    // 5. 绑定 GLFW + OpenGL3 后端
    // 因为我们在 build.zig 里指定了 .glfw_opengl3，这里 zgui.backend 就是 opengl3 后端
    zgui.backend.init(window);
    defer zgui.backend.deinit();

    // 6. 主循环
    var clear_color = [3]f32{ 0.15, 0.20, 0.30 }; // RGB，跨帧保留颜色选择
    var show_demo_window = true;

    while (!window.shouldClose()) {
        glfw.pollEvents();

        // 获取 framebuffer 大小 (处理高分屏 Retina)
        const fb_size = window.getFramebufferSize();
        const fb_width: u32 = @intCast(fb_size[0]);
        const fb_height: u32 = @intCast(fb_size[1]);

        // 开始新的一帧 (新版 zgui 需要传入宽高)
        zgui.backend.newFrame(fb_width, fb_height);

        // ---------- ImGui 内容 ----------

        // 内置 Demo 窗口 (需要传入 ?*bool)
        if (show_demo_window) {
            zgui.showDemoWindow(&show_demo_window);
        }

        // 自定义窗口：颜色选择器
        zgui.setNextWindowPos(.{ .x = 20, .y = 20, .cond = .once });
        zgui.setNextWindowSize(.{ .w = 350, .h = 150, .cond = .once });

        if (zgui.begin("Hello Zig!", .{})) {
            zgui.text("Hello from Zig + Dear ImGui + OpenGL3", .{});

            // 获取 FPS (注意 io 的访问方式)
            const io = zgui.io;
            zgui.text("FPS: {d:.1}", .{io.getFramerate()});

            _ = zgui.colorEdit3("Clear Color", .{ .col = &clear_color });

            _ = zgui.checkbox("Show Demo Window", .{ .v = &show_demo_window });
        }
        zgui.end();
        // --------------------------------

        // 7. 清屏
        gl_binding.viewport(0, 0, @intCast(fb_size[0]), @intCast(fb_size[1]));
        gl_binding.clearColor(clear_color[0], clear_color[1], clear_color[2], 1.0);
        gl_binding.clear(gl_binding.COLOR_BUFFER_BIT);

        // 8. 绘制 ImGui (新版不需要传参，内部会自动获取 DrawData)
        zgui.backend.draw();

        // 9. 交换缓冲
        window.swapBuffers();
    }
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var cartridge = try core.card.create(allocator, io, "res/maliao.nes");

    std.debug.print("{}\n", .{cartridge.header});

    defer cartridge.destroy();
}
