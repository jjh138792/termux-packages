TERMUX_PKG_HOMEPAGE=https://github.com/google/gfxstream
TERMUX_PKG_DESCRIPTION="Graphics Streaming Kit (Gfxstream Backend)"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_VERSION=1.0.0
TERMUX_PKG_SRCURL="git+https://github.com/google/gfxstream.git"
TERMUX_PKG_GIT_BRANCH="main"
TERMUX_PKG_DEPENDS="libc++, libdrm, libx11"
TERMUX_PKG_BUILD_DEPENDS="libx11, curl"

TERMUX_PKG_API_LEVEL=29
TERMUX_PKG_EXTRA_CONFIGURE_ARGS=""

termux_step_post_get_source() {
    echo "[*] 启动云端源码重塑，修复 Android NDK 与 X11 的跨界类型冲突..."
    local F1="host/gl/glestranslator/egl/egl_os_api_egl.cpp"
    local F2="host/gl/glestranslator/egl/egl_os_api_glx.cpp"
    local F3="host/vulkan/display_surface_vk.cpp"
    local F4="host/vulkan/vk_decoder_global_state.cpp"
    local F5="host/native_sub_window_x11.cpp"
    local F6="host/testlibs/oswindow/x11/X11Window.cpp"
    
    sed -i 's/mGlxDisplay, win, /mGlxDisplay, (Drawable)(uintptr_t)win, /g' $F1
    sed -i 's/mDisplay, win, /mDisplay, (Drawable)(uintptr_t)win, /g' $F2
    sed -i 's/GlxSurface::drawableFor(win)/(EGLNativeWindowType)(uintptr_t)GlxSurface::drawableFor(win)/g' $F2
    sed -i 's/new GlxSurface(wnd/new GlxSurface((GLXDrawable)(uintptr_t)wnd/g' $F2
    sed -i 's/\.window = window,/.window = (xcb_window_t)(uintptr_t)window,/g' $F3
    sed -i 's/<vndk\/hardware_buffer.h>/<android\/hardware_buffer.h>/g' $F4
    sed -i 's/p_window,/(Window)(uintptr_t)p_window,/g' $F5
    sed -i 's/p_sub_window,/(Window)(uintptr_t)p_sub_window,/g' $F5
    sed -i 's/return win;/return (EGLNativeWindowType)(uintptr_t)win;/g' $F5
    sed -i 's/s_display, win/s_display, (Window)(uintptr_t)win/g' $F5
    sed -i 's/FBNativeWindowType (Window)(uintptr_t)p_window,/FBNativeWindowType p_window,/g' $F5
    sed -i 's/EGLNativeWindowType (Window)(uintptr_t)p_sub_window,/EGLNativeWindowType p_sub_window,/g' $F5
    sed -i 's/return mWindow;/return (EGLNativeWindowType)(uintptr_t)mWindow;/g' $F6
    
    echo "[*] 获取 AOSP 官方 cutils/native_handle.h ..."
    mkdir -p host/include/cutils
    curl -sSL "https://raw.githubusercontent.com/aosp-mirror/platform_system_core/android10-release/libcutils/include/cutils/native_handle.h" -o host/include/cutils/native_handle.h
    
    sed -i '1i include_directories(host/include)' CMakeLists.txt
}

termux_step_pre_configure() {
    # ！！！【听你的，老老实实放到自动寻址的默认目录里！】！！！
    echo "[*] 正在 Termux 默认系统库目录 JIT 锻造 libcutils.so 空壳存根..."
    
    # 直接在默认搜索路径（$TERMUX_PREFIX/lib）里生成伪造库，连 -L 都不用加！
    mkdir -p $TERMUX_PREFIX/lib
    cat << 'EOF' > cutils_stub.c
#include <stddef.h>
void* native_handle_create(int numFds, int numInts) { return NULL; }
int native_handle_delete(void* h) { return 0; }
int native_handle_close(const void* h) { return 0; }
EOF

    # 编译并物理塞入默认寻找路径
    $CC $CFLAGS -shared -fPIC cutils_stub.c -o $TERMUX_PREFIX/lib/libcutils.so
    echo "[*] 启动祖宗级修复：在 CMake 源码列表中强行替换 Udmabuf 核心..."
    local BASE_CMAKE="common/base/CMakeLists.txt"
    sed -i 's/UdmabufCreator_stub.cpp/UdmabufCreator_linux.cpp/g' "$BASE_CMAKE"
    echo "[*] 存根库归位！注入最干净的原生链接参数..."
    # 只有单纯的 -l 参数，让链接器自己去默认路径里抓！
    export LDFLAGS="${LDFLAGS:-} -lcutils -lnativewindow -landroid -lsync -llog -lEGL -lGLESv2"
    sed -i '1i add_compile_definitions(VK_USE_PLATFORM_ANDROID_KHR=1 ANDROID=1 __ANDROID__=1)' CMakeLists.txt
}

termux_step_make_install() {
    echo "[*] 启动部署..."
    local SO_FILE=$(find . -name "libgfxstream_backend.so" | head -n 1)
    if [ -z "$SO_FILE" ]; then
        echo "[!] 致命错误：找不到 libgfxstream_backend.so！"
        exit 1
    fi
    echo "[*] 成功捕获目标：$SO_FILE"
    
    install -Dm755 "$SO_FILE" $TERMUX_PREFIX/lib/libgfxstream_backend.so
    
    # 安装完顺手把我们伪造的空壳库删掉，避免污染以后的其他编译环境
    rm -f $TERMUX_PREFIX/lib/libcutils.so
    
    mkdir -p $TERMUX_PREFIX/lib/pkgconfig
    cat << PC_EOF > $TERMUX_PREFIX/lib/pkgconfig/gfxstream_backend.pc
Name: gfxstream_backend
Description: Graphics Streaming Kit (Gfxstream Backend)
Version: 1.0.0
Libs: -L${TERMUX_PREFIX}/lib -lgfxstream_backend
Cflags: -I${TERMUX_PREFIX}/include
PC_EOF
}
