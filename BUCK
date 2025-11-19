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

# Default cron
alias(
    name = "cron",
    actual = "//packages/sys-apps:cronie",
    visibility = ["PUBLIC"],
)

# Default privilege escalation
alias(
    name = "sudo",
    actual = "//packages/sys-apps:sudo",
    visibility = ["PUBLIC"],
)

# Default terminal multiplexer
alias(
    name = "multiplexer",
    actual = "//packages/sys-apps:tmux",
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

filegroup(
    name = "shell-packages",
    srcs = [
        "//packages/shells:bash",
        "//packages/shells:zsh",
        "//packages/shells:dash",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "terminal-packages",
    srcs = [
        "//packages/terminals:st",
        "//packages/terminals:alacritty",
        "//packages/terminals:foot",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "sys-apps-packages",
    srcs = [
        "//packages/sys-apps:cronie",
        "//packages/sys-apps:sudo",
        "//packages/sys-apps:tmux",
        "//packages/sys-apps:htop",
        "//packages/sys-apps:rsync",
        "//packages/sys-apps:logrotate",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "monitoring-packages",
    srcs = [
        "//packages/sys-apps:htop",
        "//packages/sys-apps:lsof",
        "//packages/sys-apps:strace",
        "//packages/sys-apps:procps-ng",
    ],
    visibility = ["PUBLIC"],
)
