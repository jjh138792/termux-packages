TERMUX_PKG_HOMEPAGE=https://github.com/google/gfxstream
TERMUX_PKG_DESCRIPTION="Graphics Streaming Kit (Gfxstream Backend)"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_VERSION=1.0.0
TERMUX_PKG_SRCURL="git+https://github.com/google/gfxstream.git"
TERMUX_PKG_GIT_BRANCH="main"
TERMUX_PKG_DEPENDS="libc++, libdrm, libx11"
TERMUX_PKG_BUILD_DEPENDS="libx11"

# ！！！【核心破局：强行提升 NDK 编译基线，解锁现代 Android API】！！！
# 只有 API 28 才能原生支持 aligned_alloc 和完整的 AHardwareBuffer！
TERMUX_PKG_API_LEVEL=28

TERMUX_PKG_EXTRA_CONFIGURE_ARGS=""

# ！！！【云端重塑：执行物理级强转与依赖清洗】！！！
termux_step_post_get_source() {
    echo "[*] 启动云端源码重塑，修复 Android NDK 与 X11 的跨界类型冲突..."
    local F1="host/gl/glestranslator/egl/egl_os_api_egl.cpp"
    local F2="host/gl/glestranslator/egl/egl_os_api_glx.cpp"
    local F3="host/vulkan/display_surface_vk.cpp"
    local F4="host/vulkan/vk_decoder_global_state.cpp"
    
    # 精准强转 XGetGeometry 的 Window 参数
    sed -i 's/mGlxDisplay, win, /mGlxDisplay, (Drawable)(uintptr_t)win, /g' $F1
    sed -i 's/mDisplay, win, /mDisplay, (Drawable)(uintptr_t)win, /g' $F2
    
    # 精准强转 isValidNativeWin 和 GlxSurface 的构造入参
    sed -i 's/GlxSurface::drawableFor(win)/(EGLNativeWindowType)(uintptr_t)GlxSurface::drawableFor(win)/g' $F2
    sed -i 's/new GlxSurface(wnd/new GlxSurface((GLXDrawable)(uintptr_t)wnd/g' $F2
    
    # 强转 Vulkan XCB 的窗口参数
    sed -i 's/\.window = window,/.window = (xcb_window_t)(uintptr_t)window,/g' $F3
    
    # ！！！新加的致命一击：将私有 VNDK 头文件强行桥接到公开 NDK 头文件 ！！！
    sed -i 's/<vndk\/hardware_buffer.h>/<android\/hardware_buffer.h>/g' $F4
    
    echo "[*] 强行烙印安卓 Vulkan 上帝宏，彻底解锁跨平台结构体屏蔽！"
    sed -i '1i add_compile_definitions(VK_USE_PLATFORM_ANDROID_KHR=1)' CMakeLists.txt
}
