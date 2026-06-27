TERMUX_PKG_HOMEPAGE=https://github.com/magma-gpu/rutabaga_gfx
TERMUX_PKG_DESCRIPTION="Rutabaga GFX FFI (Trinity Edition)"
TERMUX_PKG_LICENSE="BSD"
TERMUX_PKG_VERSION=0.1.76
TERMUX_PKG_SKIP_SRC_EXTRACT=true

TERMUX_PKG_DEPENDS="gfxstream, virglrenderer"
TERMUX_PKG_BUILD_DEPENDS="gfxstream, virglrenderer"

termux_step_make() {
    # ！！！核心修正：只用 Termux 的神级环境配置，绝对不要碰 rustup！！！
    termux_setup_rust
    
    echo "[*] 从 Github 官方源拉取最新版 Rutabaga GFX (带完整子模块)..."
    # 加个判断，防止重复拉取报错
    if [ ! -d "$TERMUX_PKG_SRCDIR/repo" ]; then
        git clone --recurse-submodules https://github.com/magma-gpu/rutabaga_gfx.git $TERMUX_PKG_SRCDIR/repo
    fi
    
    cd $TERMUX_PKG_SRCDIR/repo/ffi
    
    echo "[*] 启动 Cargo 编译，三神装全开！"
    # 使用官方变量 $CARGO_TARGET_NAME 完美适配架构，路由穿透传导 Features！
    cargo build --release --target $CARGO_TARGET_NAME --features="rutabaga_gfx/virgl_renderer,rutabaga_gfx/gfxstream"
}

termux_step_make_install() {
    cd $TERMUX_PKG_SRCDIR/repo/ffi
    
    # ！！！安装路径同样使用官方变量适配 ！！！
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
