TERMUX_PKG_HOMEPAGE=https://github.com/google/gfxstream
TERMUX_PKG_DESCRIPTION="Graphics Streaming Kit (Gfxstream Backend)"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_VERSION=0.1.2
TERMUX_PKG_DEPENDS="libc++, libdrm"
TERMUX_PKG_BUILD_DEPENDS="meson, ninja"

termux_step_make() {
    termux_setup_meson
    
    echo "[*] 直连 Google 官方独立仓库拉取 Gfxstream..."
    git clone https://github.com/google/gfxstream.git $TERMUX_PKG_SRCDIR/gfxstream_src
    cd $TERMUX_PKG_SRCDIR/gfxstream_src
    
    meson setup build \
        --cross-file $TERMUX_MESON_CROSSFILE \
        --prefix $TERMUX_PREFIX \
        --libdir lib \
        -Ddefault_library=shared
        
    ninja -C build install
}
