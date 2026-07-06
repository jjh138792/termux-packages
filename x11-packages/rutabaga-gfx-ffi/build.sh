TERMUX_PKG_HOMEPAGE=https://github.com/magma-gpu/rutabaga_gfx
TERMUX_PKG_DESCRIPTION="Rutabaga GFX FFI (Trinity Edition)"
TERMUX_PKG_LICENSE="BSD"
# ！！！【文书修复：给打包系统指明 License 文件的位置】！！！
TERMUX_PKG_LICENSE_FILE="repo/LICENSE"
TERMUX_PKG_VERSION=0.1.76
TERMUX_DEBUG_BUILD=ture
TERMUX_PKG_SKIP_SRC_EXTRACT=true

TERMUX_PKG_DEPENDS="gfxstream, virglrenderer"
TERMUX_PKG_BUILD_DEPENDS="gfxstream, virglrenderer"

termux_step_make() {
    termux_setup_rust
    
    echo "[*] 从 Github 官方源拉取最新版 Rutabaga GFX (带完整子模块)..."
    if [ ! -d "$TERMUX_PKG_SRCDIR/repo" ]; then
        git clone --recurse-submodules https://github.com/magma-gpu/rutabaga_gfx.git $TERMUX_PKG_SRCDIR/repo
    fi
    
    echo "[*] 物理粉碎上游自带的 rust-toolchain 劫持文件..."
    rm -f $TERMUX_PKG_SRCDIR/repo/rust-toolchain
    rm -f $TERMUX_PKG_SRCDIR/repo/rust-toolchain.toml
    
    echo "[*] 批量下发 aemu 系列子模块的虚假 pkg-config 证明..."
    mkdir -p $TERMUX_PREFIX/lib/pkgconfig
    for libname in aemu_base aemu_logging aemu_host_common aemu_snapshot gfxstream_host_common; do
        cat << PC_EOF > $TERMUX_PREFIX/lib/pkgconfig/${libname}.pc
Name: ${libname}
Description: Fake ${libname} for rutabaga build bypass
Version: 1.0.0
Libs: -L${TERMUX_PREFIX}/lib -lgfxstream_backend
Cflags: -I${TERMUX_PREFIX}/include
PC_EOF
    done

    # ！！！【终极心肺复苏：以 dlopen 动态劫持突破 VNDK 禁区，死保 AHardwareBuffer】！！！
    echo "[*] 启动神级 Polyfill 注入：运行时动态解构 AHardwareBuffer..."
    GFXSTREAM_RS=$(find $TERMUX_PKG_SRCDIR/repo -name "gfxstream.rs" | head -n 1)
    
    if [ -n "$GFXSTREAM_RS" ]; then
        sed -i 's/use nativewindow::AhbInfo as NativeAhbInfo;//g' "$GFXSTREAM_RS"
        sed -i 's/use nativewindow::HardwareBuffer;//g' "$GFXSTREAM_RS"
        
        cat << 'EOF' >> "$GFXSTREAM_RS"

#[cfg(target_os = "android")]
pub mod nativewindow {
    use std::os::fd::{IntoRawFd, RawFd};
    
    #[repr(C)]
    pub struct native_handle_t {
        pub version: libc::c_int,
        pub numFds: libc::c_int,
        pub numInts: libc::c_int,
    }

    pub struct MockFd(pub RawFd);
    impl IntoRawFd for MockFd {
        fn into_raw_fd(self) -> RawFd { self.0 }
    }

    pub struct AhbInfo {
        pub fds: Vec<MockFd>,
        pub data: Vec<u8>,
    }

    pub struct HardwareBuffer {
        pub ptr: *mut std::ffi::c_void,
    }

    impl HardwareBuffer {
        pub unsafe fn clone_from_raw(ptr: std::ptr::NonNull<std::ffi::c_void>) -> Self {
            Self { ptr: ptr.as_ptr() }
        }
    }

    impl std::convert::TryInto<AhbInfo> for HardwareBuffer {
        type Error = &'static str;
        fn try_into(self) -> Result<AhbInfo, Self::Error> {
            unsafe {
                // 运行时暴力拉起系统库，无视编译期 NDK 隔离！绕过 LD_LIBRARY_PATH 的干扰，直捣黄龙！
                let handle = libc::dlopen(b"libnativewindow.so\0".as_ptr() as *const libc::c_char, libc::RTLD_NOW);
                if handle.is_null() { return Err("Failed to dlopen libnativewindow.so"); }
                
                let sym = libc::dlsym(handle, b"AHardwareBuffer_getNativeHandle\0".as_ptr() as *const libc::c_char);
                if sym.is_null() {
                    libc::dlclose(handle);
                    return Err("Failed to dlsym AHardwareBuffer_getNativeHandle");
                }
                
                let get_native_handle: extern "C" fn(*mut std::ffi::c_void) -> *const native_handle_t = std::mem::transmute(sym);
                let native_handle = get_native_handle(self.ptr);
                
                if native_handle.is_null() {
                    libc::dlclose(handle);
                    return Err("Native handle returned null");
                }
                
                let num_fds = (*native_handle).numFds as usize;
                let num_ints = (*native_handle).numInts as usize;
                
                let data_ptr = (native_handle as *const u8).add(std::mem::size_of::<native_handle_t>()) as *const i32;
                
                let mut fds = Vec::with_capacity(num_fds);
                for i in 0..num_fds {
                    let raw_fd = *data_ptr.add(i);
                    let dup_fd = libc::dup(raw_fd);
                    if dup_fd >= 0 { fds.push(MockFd(dup_fd)); }
                }
                
                let mut data = Vec::with_capacity(num_ints * 4);
                let ints_ptr = data_ptr.add(num_fds);
                for i in 0..num_ints {
                    let int_val = *ints_ptr.add(i);
                    data.extend_from_slice(&int_val.to_ne_bytes());
                }
                
                libc::dlclose(handle);
                Ok(AhbInfo { fds, data })
            }
        }
    }
}
#[cfg(target_os = "android")]
use nativewindow::AhbInfo as NativeAhbInfo;
#[cfg(target_os = "android")]
use nativewindow::HardwareBuffer;

EOF
        echo "[*] AHardwareBuffer 动态解构封装层追加完毕！"
    fi

    cd $TERMUX_PKG_SRCDIR/repo/ffi
    
    echo "[*] 启动 Cargo 编译，三神装全开！"
    cargo build --release --target $CARGO_TARGET_NAME --features="rutabaga_gfx/virgl_renderer,rutabaga_gfx/gfxstream"
}

termux_step_make_install() {
    cd $TERMUX_PKG_SRCDIR/repo/ffi
    
    # ！！！【路径修复：向上一级去 Workspace 的 target 捞取战利品】！！！
    install -Dm755 ../target/${CARGO_TARGET_NAME}/release/librutabaga_gfx_ffi.so $TERMUX_PREFIX/lib/librutabaga_gfx_ffi.so
    install -Dm644 src/include/rutabaga_gfx_ffi.h $TERMUX_PREFIX/include/rutabaga_gfx/rutabaga_gfx_ffi.h
    
    mkdir -p $TERMUX_PREFIX/lib/pkgconfig
    cat << PC_EOF > $TERMUX_PREFIX/lib/pkgconfig/rutabaga_gfx_ffi.pc
Name: rutabaga_gfx_ffi
Description: Rutabaga GFX FFI
Version: 0.1.76
Libs: -L${TERMUX_PREFIX}/lib -lrutabaga_gfx_ffi
Cflags: -I${TERMUX_PREFIX}/include
PC_EOF
}
