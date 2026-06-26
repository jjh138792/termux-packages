TERMUX_PKG_HOMEPAGE=https://github.com/google/gfxstream
TERMUX_PKG_DESCRIPTION="Graphics Streaming Kit (Gfxstream Backend)"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_VERSION=1.0.0
TERMUX_PKG_SRCURL="git+https://github.com/google/gfxstream.git"
TERMUX_PKG_GIT_BRANCH="main"
TERMUX_PKG_DEPENDS="libc++, libdrm, libx11"
TERMUX_PKG_BUILD_DEPENDS="libx11"

# ！！！【核心修正：删除全局 BUILD_SHARED_LIBS=ON，让内部辅助模块安全编译为静态库】！！！
# 保持 Termux 最纯净的默认 CMake 环境
TERMUX_PKG_EXTRA_CONFIGURE_ARGS=""

# ！！！【真正的云端调教：执行物理级 C++ 指针强转手术】！！！
termux_step_post_get_source() {
    echo "[*] 启动云端源码重塑，修复 Android NDK 与 X11 的跨界类型冲突..."
    local F1="host/gl/glestranslator/egl/egl_os_api_egl.cpp"
    local F2="host/gl/glestranslator/egl/egl_os_api_glx.cpp"
    
    # 精准强转 XGetGeometry 的 Window 参数，彻底斩断指针与整数的撕裂
    sed -i 's/mGlxDisplay, win, /mGlxDisplay, (Drawable)(uintptr_t)win, /g' $F1
    sed -i 's/mDisplay, win, /mDisplay, (Drawable)(uintptr_t)win, /g' $F2
    
    # 精准强转 isValidNativeWin 和 GlxSurface 的构造入参
    sed -i 's/GlxSurface::drawableFor(win)/(EGLNativeWindowType)(uintptr_t)GlxSurface::drawableFor(win)/g' $F2
    sed -i 's/new GlxSurface(wnd/new GlxSurface((GLXDrawable)(uintptr_t)wnd/g' $F2
}
