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
    
    # 基础类型冲突清洗
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
    
    # ！！！【致敬 Rust 神级 Polyfill：C++ 版运行时动态解构】！！！
    echo "[*] 启动神级 Polyfill 注入：运行时动态抓取 libcutils.so..."
    mkdir -p host/include/cutils
    cat << 'EOF' > host/include/cutils/native_handle.h
#ifndef NATIVE_HANDLE_H_
#define NATIVE_HANDLE_H_

#include <dlfcn.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* 结构体绝对保真，这是 AOSP 雷打不动的 ABI */
typedef struct native_handle {
    int version;
    int numFds;
    int numInts;
    int data[0];
} native_handle_t;

/* 运行时暴力拉起真机系统库，无视编译期 NDK 隔离！ */
static inline native_handle_t* native_handle_create(int numFds, int numInts) {
    void* handle = dlopen("libcutils.so", RTLD_NOW);
    if (!handle) return NULL;
    native_handle_t* (*fn)(int, int) = (native_handle_t* (*)(int, int))dlsym(handle, "native_handle_create");
    return fn ? fn(numFds, numInts) : NULL;
}

static inline int native_handle_delete(native_handle_t* h) {
    void* handle = dlopen("libcutils.so", RTLD_NOW);
    if (!handle) return -1;
    int (*fn)(native_handle_t*) = (int (*)(native_handle_t*))dlsym(handle, "native_handle_delete");
    return fn ? fn(h) : -1;
}

static inline int native_handle_close(const native_handle_t* h) {
    void* handle = dlopen("libcutils.so", RTLD_NOW);
    if (!handle) return -1;
    int (*fn)(const native_handle_t*) = (int (*)(const native_handle_t*))dlsym(handle, "native_handle_close");
    return fn ? fn(h) : -1;
}

#ifdef __cplusplus
}
#endif
#endif /* NATIVE_HANDLE_H_ */
EOF
    
    # 确保 Gfxstream 优先吃下我们的魔法头文件
    sed -i '1i include_directories(host/include)' CMakeLists.txt
    
    # ！！！【绝杀：唤醒内核检测代码，让它去踩咱们的探针】！！！
    echo "[*] 强行烙印安卓纯血上帝宏！"
    sed -i '1i add_compile_definitions(VK_USE_PLATFORM_ANDROID_KHR=1 ANDROID=1 __ANDROID__=1)' CMakeLists.txt
}

termux_step_pre_configure() {
    echo "[*] 准备链接配置..."
    # ！！！【吸取教训：绝对不在 LDFLAGS 里放任何编译环境没有的库】！！！
    # 剔除 -lcutils，剩下的库只要 NDK sysroot 里有就能过 CMake 编译器测试！
    export LDFLAGS="${LDFLAGS:-} -lcutils -lnativewindow -landroid -lsync -llog -lEGL -lGLESv2"
}

termux_step_make_install() {
    echo "[*] 启动手动安装劫持..."
    local SO_FILE=$(find . -name "libgfxstream_backend.so" | head -n 1)
    if [ -z "$SO_FILE" ]; then
        echo "[!] 致命错误：找不到 libgfxstream_backend.so！"
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
    
    echo "[*] Gfxstream 动态劫持终极版部署完毕！"
}
