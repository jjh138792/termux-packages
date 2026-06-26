TERMUX_PKG_HOMEPAGE=https://github.com/google/gfxstream
TERMUX_PKG_DESCRIPTION="Graphics Streaming Kit (Gfxstream Backend)"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_VERSION=1.0.0
TERMUX_PKG_SRCURL="git+https://github.com/google/gfxstream.git"
TERMUX_PKG_GIT_BRANCH="main"
TERMUX_PKG_DEPENDS="libc++, libdrm, libx11"
TERMUX_PKG_BUILD_DEPENDS="libx11"

TERMUX_PKG_API_LEVEL=28
TERMUX_PKG_EXTRA_CONFIGURE_ARGS=""

termux_step_post_get_source() {
    echo "[*] 启动云端源码重塑，修复 Android NDK 与 X11 的跨界类型冲突..."
    local F1="host/gl/glestranslator/egl/egl_os_api_egl.cpp"
    local F2="host/gl/glestranslator/egl/egl_os_api_glx.cpp"
    local F3="host/vulkan/display_surface_vk.cpp"
    local F4="host/vulkan/vk_decoder_global_state.cpp"
    local F5="host/native_sub_window_x11.cpp"
    local F6="host/testlibs/oswindow/x11/X11Window.cpp"
    
    # OpenGL GLX 冲突清洗
    sed -i 's/mGlxDisplay, win, /mGlxDisplay, (Drawable)(uintptr_t)win, /g' $F1
    sed -i 's/mDisplay, win, /mDisplay, (Drawable)(uintptr_t)win, /g' $F2
    sed -i 's/GlxSurface::drawableFor(win)/(EGLNativeWindowType)(uintptr_t)GlxSurface::drawableFor(win)/g' $F2
    sed -i 's/new GlxSurface(wnd/new GlxSurface((GLXDrawable)(uintptr_t)wnd/g' $F2
    
    # Vulkan XCB 冲突清洗
    sed -i 's/\.window = window,/.window = (xcb_window_t)(uintptr_t)window,/g' $F3
    
    # VNDK 私有库依赖清洗
    sed -i 's/<vndk\/hardware_buffer.h>/<android\/hardware_buffer.h>/g' $F4

    # 原生子窗口的 X11 冲突清洗（先斩后奏战术）
    sed -i 's/p_window,/(Window)(uintptr_t)p_window,/g' $F5
    sed -i 's/p_sub_window,/(Window)(uintptr_t)p_sub_window,/g' $F5
    sed -i 's/return win;/return (EGLNativeWindowType)(uintptr_t)win;/g' $F5
    sed -i 's/s_display, win/s_display, (Window)(uintptr_t)win/g' $F5
    sed -i 's/FBNativeWindowType (Window)(uintptr_t)p_window,/FBNativeWindowType p_window,/g' $F5
    sed -i 's/EGLNativeWindowType (Window)(uintptr_t)p_sub_window,/EGLNativeWindowType p_sub_window,/g' $F5
    
    # ！！！【黎明前最后的绝杀：测试组件的返回值强转】！！！
    sed -i 's/return mWindow;/return (EGLNativeWindowType)(uintptr_t)mWindow;/g' $F6
    
    echo "[*] 强行烙印安卓 Vulkan 上帝宏！"
    sed -i '1i add_compile_definitions(VK_USE_PLATFORM_ANDROID_KHR=1)' CMakeLists.txt
}
# ！！！【胜利的收尾：手动接管文件安装与注册】！！！
termux_step_make_install() {
    echo "[*] 启动手动安装劫持，捕获野生 libgfxstream_backend.so..."
    
    # 1. 强行把 CMake 乱放的动态库抓回来，塞进 Termux 的标准系统库目录
    install -Dm755 distribution/libgfxstream_backend.so $TERMUX_PREFIX/lib/libgfxstream_backend.so
    
    # 2. 伪造 pkg-config 身份证！这是打通 Rust (Rutabaga) 和 C++ (Gfxstream) 的终极桥梁！
    mkdir -p $TERMUX_PREFIX/lib/pkgconfig
    cat << PC_EOF > $TERMUX_PREFIX/lib/pkgconfig/gfxstream_backend.pc
Name: gfxstream_backend
Description: Graphics Streaming Kit (Gfxstream Backend)
Version: 1.0.0
Libs: -L${TERMUX_PREFIX}/lib -lgfxstream_backend
Cflags: -I${TERMUX_PREFIX}/include
PC_EOF
    
    echo "[*] Gfxstream 满血版部署完毕！"
}
