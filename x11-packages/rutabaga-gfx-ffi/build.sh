TERMUX_PKG_HOMEPAGE=https://github.com/magma-gpu/rutabaga_gfx
TERMUX_PKG_DESCRIPTION="Rutabaga GFX FFI (Trinity Edition)"
TERMUX_PKG_LICENSE="BSD"
TERMUX_PKG_VERSION=0.1.76
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

    # ！！！【终极心肺复苏：以标准合规 FFI 补全 AHardwareBuffer 底层封装】！！！
    echo "[*] 启动神级 Polyfill 注入：通过 NDK 合规链接 AHardwareBuffer..."
    GFXSTREAM_RS=$(find $TERMUX_PKG_SRCDIR/repo -name "gfxstream.rs" | head -n 1)
    
    if [ -n "$GFXSTREAM_RS" ]; then
        # 1. 抹除导致报错的残废 import
        sed -i 's/use nativewindow::AhbInfo as NativeAhbInfo;//g' "$GFXSTREAM_RS"
        sed -i 's/use nativewindow::HardwareBuffer;//g' "$GFXSTREAM_RS"
        
        # 2. 注入合规替身：使用标准 FFI 静态链接 Android 底层库
        cat << 'EOF' > "$GFXSTREAM_RS.tmp"
#[cfg(target_os = "android")]
pub mod nativewindow {
    use std::os::fd::{IntoRawFd, RawFd};
    
    #[repr(C)]
    pub struct native_handle_t {
        pub version: libc::c_int,
        pub numFds: libc::c_int,
        pub numInts: libc::c_int,
    }

    #[link(name = "android")]
    #[link(name = "nativewindow")]
    extern "C" {
        pub fn AHardwareBuffer_getNativeHandle(
            buffer: *mut std::ffi::c_void,
        ) -> *const native_handle_t;
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
        pub unsafe fn clone_from_raw(ptr: *mut std::ffi::c_void) -> Self {
            Self { ptr }
        }
    }

    impl std::convert::TryInto<AhbInfo> for HardwareBuffer {
        type Error = &'static str;
        fn try_into(self) -> Result<AhbInfo, Self::Error> {
            unsafe {
                let native_handle = AHardwareBuffer_getNativeHandle(self.ptr);
                
                if native_handle.is_null() {
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
        # 将原文件内容追加到替身下方，完成天衣无缝的拼接
        cat "$GFXSTREAM_RS" >> "$GFXSTREAM_RS.tmp"
        mv "$GFXSTREAM_RS.tmp" "$GFXSTREAM_RS"
        echo "[*] AHardwareBuffer (AHB) 封装层注入完毕，合规且满血！"
    fi

    cd $TERMUX_PKG_SRCDIR/repo/ffi
    
    echo "[*] 启动 Cargo 编译，三神装全开！"
    cargo build --release --target $CARGO_TARGET_NAME --features="rutabaga_gfx/virgl_renderer,rutabaga_gfx/gfxstream"
}

termux_step_make_install() {
    cd $TERMUX_PKG_SRCDIR/repo/ffi
    
    install -Dm755 target/${CARGO_TARGET_NAME}/release/librutabaga_gfx_ffi.so $TERMUX_PREFIX/lib/librutabaga_gfx_ffi.so
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
