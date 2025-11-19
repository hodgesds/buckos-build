# Sideros Linux Distribution - Root Build File
# A Buck2-based Linux distribution similar to Gentoo's ebuild system

load("//defs:package_defs.bzl", "rootfs")

# =============================================================================
# Main build targets
# =============================================================================

# Minimal bootable system
alias(
    name = "minimal",
    actual = "//packages/system:sideros-rootfs",
    visibility = ["PUBLIC"],
)

# Complete system with kernel
alias(
    name = "complete",
    actual = "//packages/system:sideros-complete",
    visibility = ["PUBLIC"],
)

# Individual component aliases
alias(
    name = "kernel",
    actual = "//packages/kernel:linux",
    visibility = ["PUBLIC"],
)

alias(
    name = "bootloader",
    actual = "//packages/boot:grub",
    visibility = ["PUBLIC"],
)

# Default shell
alias(
    name = "shell",
    actual = "//packages/shells:bash",
    visibility = ["PUBLIC"],
)

# Default terminal
alias(
    name = "terminal",
    actual = "//packages/terminals:st",
    visibility = ["PUBLIC"],
)

# =============================================================================
# Package groups for convenience
# =============================================================================

filegroup(
    name = "core-packages",
    srcs = [
        "//packages/core:musl",
        "//packages/core:busybox",
        "//packages/core:util-linux",
        "//packages/core:zlib",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "filesystem-packages",
    srcs = [
        "//packages/core:e2fsprogs",
    ],
    visibility = ["PUBLIC"],
)

# Networking packages
filegroup(
    name = "net-packages",
    srcs = [
        "//packages/net:openssl",
        "//packages/net:curl",
        "//packages/net:openssh",
        "//packages/net:iproute2",
        "//packages/net:dhcpcd",
    ],
    visibility = ["PUBLIC"],
)

# Editor packages
filegroup(
    name = "editor-packages",
    srcs = [
        "//packages/editors:vim",
        "//packages/editors:neovim",
        "//packages/editors:emacs",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "shell-packages",
    srcs = [
        "//packages/shells:bash",
        "//packages/shells:zsh",
        "//packages/shells:dash",
    ],
    visibility = ["PUBLIC"],
)

# Terminal packages
filegroup(
    name = "terminal-packages",
    srcs = [
        "//packages/terminals:st",
        "//packages/terminals:alacritty",
        "//packages/terminals:foot",
    ],
    visibility = ["PUBLIC"],
)

# Terminal/shell libraries
filegroup(
    name = "shell-libs",
    srcs = [
        "//packages/core:readline",
        "//packages/core:ncurses",
        "//packages/core:less",
    ],
    visibility = ["PUBLIC"],
)

# Compression utilities
filegroup(
    name = "compression-packages",
    srcs = [
        "//packages/core:zlib",
        "//packages/core:bzip2",
        "//packages/core:xz",
    ],
    visibility = ["PUBLIC"],
)

# System monitoring utilities
filegroup(
    name = "system-packages",
    srcs = [
        "//packages/core:procps-ng",
        "//packages/core:file",
    ],
    visibility = ["PUBLIC"],
)

# Development libraries
filegroup(
    name = "dev-libraries",
    srcs = [
        "//packages/core:libffi",
        "//packages/core:expat",
        "//packages/core:libnl",
    ],
    visibility = ["PUBLIC"],
)

# =============================================================================
# Desktop environment aliases
# =============================================================================

# Full desktop environments
alias(
    name = "gnome",
    actual = "//packages/desktop:gnome",
    visibility = ["PUBLIC"],
)

alias(
    name = "kde-plasma",
    actual = "//packages/desktop:kde-plasma",
    visibility = ["PUBLIC"],
)

alias(
    name = "xfce",
    actual = "//packages/desktop:xfce",
    visibility = ["PUBLIC"],
)

alias(
    name = "lxqt",
    actual = "//packages/desktop:lxqt",
    visibility = ["PUBLIC"],
)

alias(
    name = "cinnamon",
    actual = "//packages/desktop:cinnamon-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "mate",
    actual = "//packages/desktop:mate",
    visibility = ["PUBLIC"],
)

alias(
    name = "budgie",
    actual = "//packages/desktop:budgie",
    visibility = ["PUBLIC"],
)

# Wayland compositors
alias(
    name = "sway",
    actual = "//packages/desktop:sway-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "hyprland",
    actual = "//packages/desktop:hyprland-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "wayfire",
    actual = "//packages/desktop:wayfire-desktop",
    visibility = ["PUBLIC"],
)

# X11 window managers
alias(
    name = "i3",
    actual = "//packages/desktop:i3-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "bspwm",
    actual = "//packages/desktop:bspwm-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "openbox",
    actual = "//packages/desktop:openbox-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "awesome",
    actual = "//packages/desktop:awesome-desktop",
    visibility = ["PUBLIC"],
)

# =============================================================================
# Desktop package groups
# =============================================================================

filegroup(
    name = "desktop-foundation",
    srcs = [
        "//packages/desktop:desktop-foundation",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "all-desktops",
    srcs = [
        "//packages/desktop:all-desktops",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "wayland-compositors",
    srcs = [
        "//packages/desktop:wayland-compositors",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "tiling-desktops",
    srcs = [
        "//packages/desktop:tiling-desktops",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "lightweight-desktops",
    srcs = [
        "//packages/desktop:lightweight-desktops",
    ],
    visibility = ["PUBLIC"],
)
