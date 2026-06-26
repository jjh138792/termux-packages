TERMUX_PKG_HOMEPAGE=https://github.com/google/gfxstream
TERMUX_PKG_DESCRIPTION="Graphics Streaming Kit (Gfxstream Backend)"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_VERSION=1.0.0
TERMUX_PKG_SRCURL="git+https://github.com/google/gfxstream.git"
TERMUX_PKG_GIT_BRANCH="main"
TERMUX_PKG_DEPENDS="libc++, libdrm, libx11"
TERMUX_PKG_BUILD_DEPENDS="libx11"

# 强开 API 28，解锁现代 Android API
TERMUX_PKG_API_LEVEL=28
TERMUX_PKG_EXTRA_CONFIGURE_ARGS=""

termux_step_post_get_source() {
    echo "[*] 启动云端源码重塑，修复 Android NDK 与 X11 的跨界类型冲突..."
    local F1="host/gl/glestranslator/egl/egl_os_api_egl.cpp"
    local F2="host/gl/glestranslator/egl/egl_os_api_glx.cpp"
    local F3="host/vulkan/display_surface_vk.cpp"
    local F4="host/vulkan/vk_decoder_global_state.cpp"
    local F5="host/native_sub_window_x11.cpp"
    
    # OpenGL GLX 冲突清洗
    sed -i 's/mGlxDisplay, win, /mGlxDisplay, (Drawable)(uintptr_t)win, /g' $F1
    sed -i 's/mDisplay, win, /mDisplay, (Drawable)(uintptr_t)win, /g' $F2
    sed -i 's/GlxSurface::drawableFor(win)/(EGLNativeWindowType)(uintptr_t)GlxSurface::drawableFor(win)/g' $F2
    sed -i 's/new GlxSurface(wnd/new GlxSurface((GLXDrawable)(uintptr_t)wnd/g' $F2
    
    # Vulkan XCB 冲突清洗
    sed -i 's/\.window = window,/.window = (xcb_window_t)(uintptr_t)window,/g' $F3
    
    # VNDK 私有库依赖清洗
    sed -i 's/<vndk\/hardware_buffer.h>/<android\/hardware_buffer.h>/g' $F4

    # ！！！【最后的清剿：强转原生子窗口的 X11 冲突】！！！
    sed -i 's/p_window,/(Window)(uintptr_t)p_window,/g' $F5
    sed -i 's/return win;/return (EGLNativeWindowType)(uintptr_t)win;/g' $F5
    sed -i 's/(s_display, win)/(s_display, (Window)(uintptr_t)win)/g' $F5
    sed -i 's/s_display, p_sub_window/s_display, (Window)(uintptr_t)p_sub_window/g' $F5
    sed -i 's/p_sub_window,/(Window)(uintptr_t)p_sub_window,/g' $F5
    
    echo "[*] 强行烙印安卓 Vulkan 上帝宏！"
    sed -i '1i add_compile_definitions(VK_USE_PLATFORM_ANDROID_KHR=1)' CMakeLists.txt
}
