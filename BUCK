# BuckOs Linux Distribution - Root Build File
# A Buck2-based Linux distribution similar to Gentoo's ebuild system

load("//defs:package_defs.bzl", "rootfs")

# =============================================================================
# Main build targets
# =============================================================================

# Minimal bootable system
alias(
    name = "minimal",
    actual = "//packages/linux/system:buckos-rootfs",
    visibility = ["PUBLIC"],
)

# Complete system with kernel
alias(
    name = "complete",
    actual = "//packages/linux/system:buckos-complete",
    visibility = ["PUBLIC"],
)

# Individual component aliases
alias(
    name = "kernel",
    actual = "//packages/linux/kernel:linux",
    visibility = ["PUBLIC"],
)

alias(
    name = "bootloader",
    actual = "//packages/linux/boot:grub",
    visibility = ["PUBLIC"],
)

# Default shell
alias(
    name = "shell",
    actual = "//packages/linux/shells:bash",
    visibility = ["PUBLIC"],
)

# Default terminal
alias(
    name = "terminal",
    actual = "//packages/linux/terminals:st",
    visibility = ["PUBLIC"],
)

# Default cron
alias(
    name = "cron",
    actual = "//packages/linux/system/apps:cronie",
    visibility = ["PUBLIC"],
)

# Essential utilities from sys-apps
alias(
    name = "tar",
    actual = "//packages/linux/system/apps/tar:tar",
    visibility = ["PUBLIC"],
)

alias(
    name = "gzip",
    actual = "//packages/linux/system/libs/compression/gzip:gzip",
    visibility = ["PUBLIC"],
)

alias(
    name = "shadow",
    actual = "//packages/linux/system/apps/shadow:shadow",
    visibility = ["PUBLIC"],
)

alias(
    name = "man-db",
    actual = "//packages/linux/system/docs:man-db",
    visibility = ["PUBLIC"],
)

alias(
    name = "texinfo",
    actual = "//packages/linux/system/docs:texinfo",
    visibility = ["PUBLIC"],
)

alias(
    name = "gettext",
    actual = "//packages/linux/dev-libs/misc/gettext:gettext",
    visibility = ["PUBLIC"],
)

# Default privilege escalation
alias(
    name = "sudo",
    actual = "//packages/linux/system/apps:sudo",
    visibility = ["PUBLIC"],
)

# Default terminal multiplexer
alias(
    name = "multiplexer",
    actual = "//packages/linux/system/apps:tmux",
    visibility = ["PUBLIC"],
)

# VPN solutions
alias(
    name = "wireguard",
    actual = "//packages/linux/net-vpn:wireguard-tools",
    visibility = ["PUBLIC"],
)

alias(
    name = "openvpn",
    actual = "//packages/linux/net-vpn:openvpn",
    visibility = ["PUBLIC"],
)

alias(
    name = "strongswan",
    actual = "//packages/linux/net-vpn:strongswan",
    visibility = ["PUBLIC"],
)

# Benchmarking tools
alias(
    name = "benchmarks",
    actual = "//packages/linux/benchmarks:all-benchmarks",
    visibility = ["PUBLIC"],
)

# Default init system
alias(
    name = "init",
    actual = "//packages/linux/system/init:systemd",
    visibility = ["PUBLIC"],
)

# Alternative init systems
alias(
    name = "init-openrc",
    actual = "//packages/linux/system/init:openrc",
    visibility = ["PUBLIC"],
)

alias(
    name = "init-s6",
    actual = "//packages/linux/system/init:s6",
    visibility = ["PUBLIC"],
)

alias(
    name = "init-runit",
    actual = "//packages/linux/system/init:runit",
    visibility = ["PUBLIC"],
)

alias(
    name = "init-dinit",
    actual = "//packages/linux/system/init:dinit",
    visibility = ["PUBLIC"],
)

# =============================================================================
# Package groups for convenience
# =============================================================================

filegroup(
    name = "core-packages",
    srcs = [
        "//packages/linux/core:musl",
        "//packages/linux/core:busybox",
        "//packages/linux/core:util-linux",
        "//packages/linux/core:zlib",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "filesystem-packages",
    srcs = [
        "//packages/linux/core:e2fsprogs",
    ],
    visibility = ["PUBLIC"],
)

# Networking packages
filegroup(
    name = "net-packages",
    srcs = [
        "//packages/linux/network:openssl",
        "//packages/linux/network:curl",
        "//packages/linux/network:openssh",
        "//packages/linux/network:iproute2",
        "//packages/linux/network:dhcpcd",
    ],
    visibility = ["PUBLIC"],
)

# VPN packages
filegroup(
    name = "vpn-packages",
    srcs = [
        "//packages/linux/net-vpn:wireguard-tools",
        "//packages/linux/net-vpn:openvpn",
        "//packages/linux/net-vpn:strongswan",
        "//packages/linux/net-vpn:libreswan",
        "//packages/linux/net-vpn:openconnect",
        "//packages/linux/net-vpn:tinc",
        "//packages/linux/net-vpn:zerotier",
        "//packages/linux/net-vpn:nebula",
    ],
    visibility = ["PUBLIC"],
)

# Modern VPN solutions
filegroup(
    name = "vpn-modern",
    srcs = [
        "//packages/linux/net-vpn:wireguard-tools",
        "//packages/linux/net-vpn:openvpn",
        "//packages/linux/net-vpn:strongswan",
    ],
    visibility = ["PUBLIC"],
)

# Mesh VPN solutions
filegroup(
    name = "vpn-mesh",
    srcs = [
        "//packages/linux/net-vpn:tinc",
        "//packages/linux/net-vpn:zerotier",
        "//packages/linux/net-vpn:nebula",
        "//packages/linux/net-vpn:tailscale",
    ],
    visibility = ["PUBLIC"],
)

# Editor packages
filegroup(
    name = "editor-packages",
    srcs = [
        "//packages/linux/editors:vim",
        "//packages/linux/editors:neovim",
        "//packages/linux/editors:emacs",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "shell-packages",
    srcs = [
        "//packages/linux/shells:bash",
        "//packages/linux/shells:zsh",
        "//packages/linux/shells:dash",
    ],
    visibility = ["PUBLIC"],
)

# Terminal packages
filegroup(
    name = "terminal-packages",
    srcs = [
        "//packages/linux/terminals:st",
        "//packages/linux/terminals:alacritty",
        "//packages/linux/terminals:foot",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "sys-apps-packages",
    srcs = [
        "//packages/linux/system/apps:coreutils",
        "//packages/linux/system/apps:findutils",
        "//packages/linux/system/apps:cronie",
        "//packages/linux/system/apps:sudo",
        "//packages/linux/system/apps:tmux",
        "//packages/linux/system/apps:htop",
        "//packages/linux/system/apps:rsync",
        "//packages/linux/system/apps:logrotate",
        "//packages/linux/system/apps/tar:tar",
        "//packages/linux/system/apps/shadow:shadow",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "benchmark-packages",
    srcs = [
        "//packages/linux/benchmarks:stress-ng",
        "//packages/linux/benchmarks:fio",
        "//packages/linux/benchmarks:sysbench",
        "//packages/linux/benchmarks:iperf3",
        "//packages/linux/benchmarks:hackbench",
        "//packages/linux/benchmarks:memtester",
    ],
    visibility = ["PUBLIC"],
)

# Terminal/shell libraries
filegroup(
    name = "shell-libs",
    srcs = [
        "//packages/linux/core:readline",
        "//packages/linux/core:ncurses",
        "//packages/linux/core:less",
    ],
    visibility = ["PUBLIC"],
)

# Compression utilities
filegroup(
    name = "compression-packages",
    srcs = [
        "//packages/linux/core:zlib",
        "//packages/linux/core:bzip2",
        "//packages/linux/core:xz",
        "//packages/linux/system/libs/compression/gzip:gzip",
        "//packages/linux/system/apps/tar:tar",
    ],
    visibility = ["PUBLIC"],
)

# Documentation packages
filegroup(
    name = "docs-packages",
    srcs = [
        "//packages/linux/system/docs:man-db",
        "//packages/linux/system/docs:texinfo",
        "//packages/linux/system/docs:man-pages",
        "//packages/linux/system/docs:groff",
    ],
    visibility = ["PUBLIC"],
)

# Internationalization packages
filegroup(
    name = "i18n-packages",
    srcs = [
        "//packages/linux/dev-libs/misc/gettext:gettext",
    ],
    visibility = ["PUBLIC"],
)

# System monitoring utilities
filegroup(
    name = "system-packages",
    srcs = [
        "//packages/linux/core:procps-ng",
        "//packages/linux/core:file",
    ],
    visibility = ["PUBLIC"],
)

# Development libraries
filegroup(
    name = "dev-libraries",
    srcs = [
        "//packages/linux/core:libffi",
        "//packages/linux/core:expat",
        "//packages/linux/core:libnl",
    ],
    visibility = ["PUBLIC"],
)

# Init system packages
filegroup(
    name = "init-packages",
    srcs = [
        "//packages/linux/system/init:systemd",
        "//packages/linux/system/init:openrc",
        "//packages/linux/system/init:runit",
        "//packages/linux/system/init:dinit",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "init-lightweight",
    srcs = [
        "//packages/linux/system/init:openrc",
        "//packages/linux/system/init:runit",
        "//packages/linux/system/init:dinit",
    ],
    visibility = ["PUBLIC"],
)

# =============================================================================
# Desktop environment aliases
# =============================================================================

# Full desktop environments
alias(
    name = "gnome",
    actual = "//packages/linux/desktop:gnome",
    visibility = ["PUBLIC"],
)

alias(
    name = "kde-plasma",
    actual = "//packages/linux/desktop:kde-plasma",
    visibility = ["PUBLIC"],
)

alias(
    name = "xfce",
    actual = "//packages/linux/desktop:xfce",
    visibility = ["PUBLIC"],
)

alias(
    name = "lxqt",
    actual = "//packages/linux/desktop:lxqt",
    visibility = ["PUBLIC"],
)

alias(
    name = "cinnamon",
    actual = "//packages/linux/desktop:cinnamon-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "mate",
    actual = "//packages/linux/desktop:mate",
    visibility = ["PUBLIC"],
)

alias(
    name = "budgie",
    actual = "//packages/linux/desktop:budgie",
    visibility = ["PUBLIC"],
)

# Wayland compositors
alias(
    name = "sway",
    actual = "//packages/linux/desktop:sway-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "hyprland",
    actual = "//packages/linux/desktop:hyprland-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "wayfire",
    actual = "//packages/linux/desktop:wayfire-desktop",
    visibility = ["PUBLIC"],
)

# X11 window managers
alias(
    name = "i3",
    actual = "//packages/linux/desktop:i3-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "bspwm",
    actual = "//packages/linux/desktop:bspwm-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "openbox",
    actual = "//packages/linux/desktop:openbox-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "awesome",
    actual = "//packages/linux/desktop:awesome-desktop",
    visibility = ["PUBLIC"],
)

# =============================================================================
# Desktop package groups
# =============================================================================

filegroup(
    name = "desktop-foundation",
    srcs = [
        "//packages/linux/desktop:desktop-foundation",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "all-desktops",
    srcs = [
        "//packages/linux/desktop:all-desktops",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "wayland-compositors",
    srcs = [
        "//packages/linux/desktop:wayland-compositors",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "tiling-desktops",
    srcs = [
        "//packages/linux/desktop:tiling-desktops",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "monitoring-packages",
    srcs = [
        "//packages/linux/system/apps:htop",
        "//packages/linux/system/apps:lsof",
        "//packages/linux/system/apps:strace",
        "//packages/linux/system/apps:procps-ng",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "lightweight-desktops",
    srcs = [
        "//packages/linux/desktop:lightweight-desktops",
    ],
    visibility = ["PUBLIC"],
)

# =============================================================================
# Emulation and Virtualization aliases
# =============================================================================

# QEMU - Full system emulator
alias(
    name = "qemu",
    actual = "//packages/linux/emulation/hypervisors/qemu:qemu",
    visibility = ["PUBLIC"],
)

# libvirt - Virtualization API
alias(
    name = "libvirt",
    actual = "//packages/linux/emulation/virtualization/libvirt:libvirt",
    visibility = ["PUBLIC"],
)

# virt-manager - VM management GUI
alias(
    name = "virt-manager",
    actual = "//packages/linux/emulation/virtualization/virt-manager:virt-manager",
    visibility = ["PUBLIC"],
)

# VirtualBox - Desktop virtualization
alias(
    name = "virtualbox",
    actual = "//packages/linux/emulation/virtualization/virtualbox:virtualbox",
    visibility = ["PUBLIC"],
)

# Docker
alias(
    name = "docker",
    actual = "//packages/linux/emulation/containers:docker-full",
    visibility = ["PUBLIC"],
)

# Podman
alias(
    name = "podman",
    actual = "//packages/linux/emulation/containers:podman-full",
    visibility = ["PUBLIC"],
)

# containerd
alias(
    name = "containerd",
    actual = "//packages/linux/emulation/containers/containerd:containerd",
    visibility = ["PUBLIC"],
)

# Firecracker - Secure microVMs
alias(
    name = "firecracker",
    actual = "//packages/linux/emulation/utilities/firecracker:firecracker",
    visibility = ["PUBLIC"],
)

# Cloud Hypervisor
alias(
    name = "cloud-hypervisor",
    actual = "//packages/linux/emulation/utilities/cloud-hypervisor:cloud-hypervisor",
    visibility = ["PUBLIC"],
)

# crosvm - Chrome OS VMM
alias(
    name = "crosvm",
    actual = "//packages/linux/emulation/utilities/crosvm:crosvm",
    visibility = ["PUBLIC"],
)

# virtme-ng - Fast kernel testing
alias(
    name = "virtme-ng",
    actual = "//packages/linux/emulation/kernel/virtme-ng:virtme-ng",
# Container aliases
# =============================================================================

# Main container tool
alias(
    name = "podman",
    actual = "//packages/linux/system/containers:podman",
    visibility = ["PUBLIC"],
)

alias(
    name = "buildah",
    actual = "//packages/linux/system/containers:buildah",
    visibility = ["PUBLIC"],
)

alias(
    name = "skopeo",
    actual = "//packages/linux/system/containers:skopeo",
    visibility = ["PUBLIC"],
)

# Container orchestration
alias(
    name = "podman-compose",
    actual = "//packages/linux/system/containers:podman-compose",
    visibility = ["PUBLIC"],
)

# Container security
alias(
    name = "trivy",
    actual = "//packages/linux/system/containers:trivy",
    visibility = ["PUBLIC"],
)

# =============================================================================
# Emulation package groups
# =============================================================================

# Essential virtualization (QEMU + libvirt + virt-manager)
filegroup(
    name = "emulation-essential",
    srcs = [
        "//packages/linux/emulation:essential",
# Container package groups
# =============================================================================

# Core container runtime
filegroup(
    name = "container-runtime",
    srcs = [
        "//packages/linux/system/containers:container-runtime",
    ],
    visibility = ["PUBLIC"],
)

# Server virtualization
filegroup(
    name = "emulation-server",
    srcs = [
        "//packages/linux/emulation:server",
# Container networking
filegroup(
    name = "container-networking",
    srcs = [
        "//packages/linux/system/containers:container-networking",
    ],
    visibility = ["PUBLIC"],
)

# Desktop virtualization (with GUI)
filegroup(
    name = "emulation-desktop",
    srcs = [
        "//packages/linux/emulation:desktop",
# Podman ecosystem tools
filegroup(
    name = "podman-tools",
    srcs = [
        "//packages/linux/system/containers:podman-tools",
    ],
    visibility = ["PUBLIC"],
)

# Cloud/microVM hypervisors
filegroup(
    name = "emulation-cloud",
    srcs = [
        "//packages/linux/emulation:cloud",
# Container utilities and monitoring
filegroup(
    name = "container-utilities",
    srcs = [
        "//packages/linux/system/containers:container-utilities",
    ],
    visibility = ["PUBLIC"],
)

# Development tools for kernel testing
filegroup(
    name = "emulation-development",
    srcs = [
        "//packages/linux/emulation:development",
# Container security tools
filegroup(
    name = "container-security",
    srcs = [
        "//packages/linux/system/containers:container-security",
    ],
    visibility = ["PUBLIC"],
)

# Container runtimes
filegroup(
    name = "container-packages",
    srcs = [
        "//packages/linux/emulation/containers:all-containers",
    ],
    visibility = ["PUBLIC"],
)

# All emulation packages
filegroup(
    name = "emulation-all",
    srcs = [
        "//packages/linux/emulation:all",
# Complete container stack
filegroup(
    name = "container-packages",
    srcs = [
        "//packages/linux/system/containers:all-containers",
    ],
    visibility = ["PUBLIC"],
)
