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

    # 原生子窗口的 X11 冲突清洗
    sed -i 's/p_window,/(Window)(uintptr_t)p_window,/g' $F5
    sed -i 's/p_sub_window,/(Window)(uintptr_t)p_sub_window,/g' $F5
    sed -i 's/return win;/return (EGLNativeWindowType)(uintptr_t)win;/g' $F5
    sed -i 's/s_display, win/s_display, (Window)(uintptr_t)win/g' $F5
    sed -i 's/FBNativeWindowType (Window)(uintptr_t)p_window,/FBNativeWindowType p_window,/g' $F5
    sed -i 's/EGLNativeWindowType (Window)(uintptr_t)p_sub_window,/EGLNativeWindowType p_sub_window,/g' $F5
    
    sed -i 's/return mWindow;/return (EGLNativeWindowType)(uintptr_t)mWindow;/g' $F6
    
    # ！！！【举一反三：直接秒杀 cutils/native_handle.h 缺失报错】！！！
    # 既然它是 AOSP 私有库，我们直接用 sed 把这个 #include 替换成一个标准的 native_handle_t 结构体定义！
    echo "[*] 正在执行举一反三：注入 native_handle_t 结构体..."
	sed -i 's|#include <cutils/native_handle.h>|typedef struct native_handle { int version; int numFds; int numInts; int data[0]; } native_handle_t;|g' host/vulkan/vk_android_native_buffer_gfxstream.h
	
    # ！！！【坚守底线：强行烙印安卓纯血上帝宏，唤醒内核检测代码】！！！
    echo "[*] 强行烙印安卓纯血上帝宏，让它的检测逻辑完全复活！"
    sed -i '1i add_compile_definitions(VK_USE_PLATFORM_ANDROID_KHR=1 ANDROID=1 __ANDROID__=1)' CMakeLists.txt
}

termux_step_pre_configure() {
    echo "[*] 在编译器初始化后，强行给交叉编译链注入 Android 物理驱动库及宏依赖！"
    export LDFLAGS="${LDFLAGS:-} -lnativewindow -landroid -lsync -llog -lEGL -lGLESv2"
    
    # 双保险：强迫所有 C/C++ 源码承认自己运行在 Android 躯体上
    export CFLAGS="${CFLAGS:-} -D__ANDROID__=1 -DANDROID=1"
    export CXXFLAGS="${CXXFLAGS:-} -D__ANDROID__=1 -DANDROID=1"
}

termux_step_make_install() {
    echo "[*] 启动手动安装劫持，全盘搜捕野生 libgfxstream_backend.so..."

	
    local SO_FILE=$(find . -name "libgfxstream_backend.so" | head -n 1)
    
    if [ -z "$SO_FILE" ]; then
        echo "[!] 致命错误：找不到 libgfxstream_backend.so，前面的编译可能暗中失败了！"
        exit 1
    fi
    
    echo "[*] 成功捕获目标：$SO_FILE"
    
    install -Dm755 "$SO_FILE" $TERMUX_PREFIX/lib/libgfxstream_backend.so
    
    mkdir -p $TERMUX_PREFIX/lib/pkgconfig
    cat << PC_EOF > $TERMUX_PREFIX/lib/pkgconfig/gfxstream_backend.pc
Name: gfxstream_backend
Description: Graphics Streaming Kit (Gfxstream Backend)
Version: 1.0.0
Libs: -L${TERMUX_PREFIX}/lib -lgfxstream_backend
Cflags: -I${TERMUX_PREFIX}/include
PC_EOF
    
    echo "[*] Gfxstream 原汁原味 Android 逻辑复活版部署完毕！"
}
