TERMUX_PKG_HOMEPAGE=https://github.com/google/gfxstream
TERMUX_PKG_DESCRIPTION="Graphics Streaming Kit (Gfxstream Backend)"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_VERSION=1.0.0
TERMUX_PKG_SRCURL="git+https://github.com/google/gfxstream.git"
TERMUX_PKG_GIT_BRANCH="main"
TERMUX_PKG_DEPENDS="libc++, libdrm"

# ！！！【核心调教 Termux】！！！
# 强制废弃水土不服的 CMake，启用 Termux 云端容器深度定制的 Meson 交叉构建器！
TERMUX_PKG_BUILDER="meson"

# 传递给 Meson 的标准参数
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="-Ddefault_library=shared"
