TERMUX_PKG_HOMEPAGE=https://github.com/google/gfxstream
TERMUX_PKG_DESCRIPTION="Graphics Streaming Kit (Gfxstream Backend)"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_VERSION=1.0.0
# ！！！神级魔法：直接用 git+ 协议，Termux 会自动拉取并处理子模块！
TERMUX_PKG_SRCURL="git+https://github.com/google/gfxstream.git"
TERMUX_PKG_GIT_BRANCH="main"
TERMUX_PKG_DEPENDS="libc++, libdrm"

# 告诉系统以共享动态库的方式编译，其他的全交给 Termux 自动处理！
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="-Ddefault_library=shared"
