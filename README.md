# BuckOs Linux

A Buck2-based Linux distribution build system, inspired by Gentoo's ebuild system.

## Overview

BuckOs uses Buck2 to define and build Linux packages as reproducible build targets. Each package is defined similarly to a Gentoo ebuild, with source downloads, build configuration, and dependencies clearly specified.

## Project Structure

```
buckos-build/
├── .buckconfig          # Buck2 configuration
├── BUCK                  # Root build targets
├── defs/
│   ├── package_defs.bzl  # Package build rules (like eclass)
│   └── platform_defs.bzl # Platform targeting helpers
├── platforms/
│   └── BUCK              # Platform definitions and constraints
├── toolchains/
│   └── BUCK              # Toolchain configurations
└── packages/
    ├── core/             # Core system libraries
    │   └── BUCK          # musl, busybox, zlib, util-linux, e2fsprogs
    ├── kernel/           # Linux kernel
    │   ├── BUCK
    │   └── kernel.config
    ├── boot/             # Bootloaders
    │   └── BUCK          # GRUB, syslinux
    └── system/           # System configuration
        └── BUCK          # init scripts, baselayout, rootfs assembly
```

## Requirements

- Buck2 (https://buck2.build)
- Standard build toolchain (gcc, make, etc.)
- curl (for downloading sources)

## Quick Start

### Install Buck2

```bash
# Download Buck2
curl -LO https://github.com/facebook/buck2/releases/latest/download/buck2-x86_64-unknown-linux-gnu.zst
zstd -d buck2-x86_64-unknown-linux-gnu.zst -o buck2
chmod +x buck2
sudo mv buck2 /usr/local/bin/
```

### Build Packages

```bash
# Build individual packages
buck2 build //packages/core:musl
buck2 build //packages/core:busybox
buck2 build //packages/kernel:linux

# Build complete rootfs
buck2 build //packages/system:buckos-rootfs

# Build everything
buck2 build //:complete
```

### List Available Targets

```bash
buck2 targets //...
```

## Package System

### Package Types

BuckOs provides several package build rules similar to Gentoo's eclasses:

#### `download_source`
Downloads and extracts source tarballs:
```python
download_source(
    name = "musl-src",
    src_uri = "https://musl.libc.org/releases/musl-1.2.4.tar.gz",
    sha256 = "...",
)
```

#### `configure_make_package`
Standard configure/make/make install workflow:
```python
configure_make_package(
    name = "musl",
    source = ":musl-src",
    version = "1.2.4",
    description = "Lightweight C library",
    configure_args = ["--disable-static"],
    deps = [...],
)
```

#### `kernel_build`
Linux kernel builds:
```python
kernel_build(
    name = "linux",
    source = ":linux-src",
    version = "6.6.10",
    config = "kernel.config",
)
```

#### `rootfs`
Assembles packages into a root filesystem:
```python
rootfs(
    name = "buckos-rootfs",
    packages = [
        "//packages/linux/core:busybox",
        "//packages/linux/core:musl",
        ...
    ],
)
```

### Adding New Packages

1. Create a directory in `packages/` for your category
2. Create a `BUCK` file with package definitions
3. Define source download and build rules
4. Add dependencies

Example new package:
```python
load("//defs:package_defs.bzl", "download_source", "configure_make_package")

download_source(
    name = "newpkg-src",
    src_uri = "https://example.com/newpkg-1.0.tar.gz",
    sha256 = "checksum...",
)

configure_make_package(
    name = "newpkg",
    source = ":newpkg-src",
    version = "1.0",
    description = "My new package",
    deps = ["//packages/linux/core:musl"],
)
```

## Platform Targeting

BuckOs supports tagging packages by their target platform, enabling future support for BSD, macOS, and Windows alongside Linux.

### Supported Platforms

- `linux` - Linux distributions
- `bsd` - BSD variants (FreeBSD, OpenBSD, NetBSD)
- `macos` - macOS / Darwin
- `windows` - Windows

### Using Platform Helpers

Import the platform helpers:
```python
load("//defs:platform_defs.bzl",
    "PLATFORM_LINUX",
    "PLATFORM_BSD",
    "platform_filegroup",
    "platform_select",
)
```

### Tagging Packages by Platform

Use `platform_filegroup` to tag targets with their supported platforms:
```python
platform_filegroup(
    name = "my-linux-package",
    srcs = [":my-package-build"],
    platforms = [PLATFORM_LINUX],
    visibility = ["PUBLIC"],
)

# Package supporting multiple platforms
platform_filegroup(
    name = "my-portable-package",
    srcs = [":portable-build"],
    platforms = [PLATFORM_LINUX, PLATFORM_BSD, PLATFORM_MACOS],
    visibility = ["PUBLIC"],
)
```

### Platform-Specific Configuration

Use `platform_select` for platform-specific build options:
```python
configure_make_package(
    name = "mypackage",
    configure_args = select(platform_select({
        PLATFORM_LINUX: ["--enable-linux-specific"],
        PLATFORM_BSD: ["--enable-bsd-specific"],
    }, default = [])),
)
```

### Querying Targets by Platform

Find all targets for a specific platform using Buck2 query:
```bash
# Find all Linux targets
buck2 query 'attrfilter(labels, "platform:linux", //...)'

# Find all BSD targets
buck2 query 'attrfilter(labels, "platform:bsd", //...)'

# Find all macOS targets
buck2 query 'attrfilter(labels, "platform:macos", //...)'

# Find all Windows targets
buck2 query 'attrfilter(labels, "platform:windows", //...)'
```

### Platform Constants

The following constants are available in `platform_defs.bzl`:

| Constant | Value | Description |
|----------|-------|-------------|
| `PLATFORM_LINUX` | `"linux"` | Linux platform |
| `PLATFORM_BSD` | `"bsd"` | BSD platform |
| `PLATFORM_MACOS` | `"macos"` | macOS platform |
| `PLATFORM_WINDOWS` | `"windows"` | Windows platform |
| `ALL_PLATFORMS` | List | All supported platforms |
| `UNIX_PLATFORMS` | List | Linux, BSD, macOS |
| `POSIX_PLATFORMS` | List | Linux, BSD, macOS |

## Core Packages

### Currently Included

- **musl** (1.2.4) - Lightweight C library
- **busybox** (1.36.1) - Essential UNIX utilities
- **zlib** (1.3.1) - Compression library
- **util-linux** (2.39) - System utilities
- **e2fsprogs** (1.47.0) - Ext filesystem utilities
- **linux** (6.6.10) - Linux kernel
- **grub** (2.12) - Bootloader

### System Components

- **baselayout** - FHS directory structure
- **init-scripts** - BusyBox init configuration

## Boot Configuration

The kernel config includes support for:
- x86_64 architecture
- VirtIO devices (for VM testing)
- Ext4 filesystem
- Basic networking (e1000, virtio-net)
- Serial console

## Testing

### Boot in QEMU

```bash
# Build the system
buck2 build //packages/system:buckos-rootfs
buck2 build //packages/kernel:linux-defconfig

# Create a disk image (manual step)
# Then boot with QEMU:
qemu-system-x86_64 \
    -kernel buck-out/.../linux/boot/vmlinuz \
    -initrd initramfs.cpio.gz \
    -append "console=ttyS0" \
    -nographic
```

## Comparison to Gentoo

| Gentoo | BuckOs |
|--------|---------|
| ebuild | BUCK file |
| eclass | package_defs.bzl |
| emerge | buck2 build |
| PORTDIR | packages/ |
| USE flags | Buck select() |
| DEPEND | deps |
| BDEPEND | build_deps |

## License

MIT License - See individual packages for their respective licenses.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add your packages following the existing patterns
4. Submit a pull request

## Roadmap

- [x] Platform targeting support (Linux, BSD, macOS, Windows)
- [ ] Add more packages (openssl, openssh, networking tools)
- [ ] Create initramfs generation target
- [ ] Add ISO image generation
- [ ] Implement USE flag-like configuration
- [ ] Add package versioning and slots
- [ ] Create package manager for installed systems
- [ ] Add packages for BSD, macOS, and Windows platforms
