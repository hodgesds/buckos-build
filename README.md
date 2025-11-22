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
│   ├── platform_defs.bzl # Platform targeting helpers
│   ├── use_flags.bzl     # USE flag system
│   ├── package_sets.bzl  # Package set definitions (like profiles)
│   ├── registry.bzl      # Package version registry
│   ├── versions.bzl      # Multi-version and subslot support
│   ├── eclasses.bzl      # Eclass inheritance system
│   ├── licenses.bzl      # License tracking and validation
│   ├── eapi.bzl          # EAPI versioning system
│   ├── vdb.bzl           # Installed package database (VDB)
│   ├── overlays.bzl      # Overlay/repository system
│   ├── config_protect.bzl # Configuration protection
│   ├── use_expand.bzl    # USE_EXPAND variables
│   └── advanced_deps.bzl # Blockers, SRC_URI, REQUIRED_USE, pkg env
├── docs/
│   ├── USE_FLAGS.md      # USE flag documentation
│   ├── PACKAGE_SETS.md   # Package set documentation
│   ├── VERSIONING.md     # Version management docs
│   └── PATCHES.md        # Patch system documentation
├── patches/              # Patch files for packages
│   ├── global/           # Global patches (security, etc.)
│   ├── profiles/         # Profile-specific patches
│   └── packages/         # Per-package patches
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

## Multi-Version Package Support

BuckOs supports maintaining multiple versions of the same package simultaneously, similar to Gentoo's SLOT system. This enables legacy compatibility, gradual migrations, and supporting different dependency requirements.

### Key Concepts

- **Slots**: Logical groupings of package versions (e.g., `openssl:3` vs `openssl:1.1`)
- **Default Version**: The version used when no specific version is requested
- **Version Status**: `stable`, `testing`, `deprecated`, or `masked`

### Defining Multi-Version Packages

Use `multi_version_package()` for packages with multiple versions:

```python
load("//defs:versions.bzl", "multi_version_package")

multi_version_package(
    name = "openssl",
    versions = {
        "3.2.0": {
            "slot": "3",
            "keywords": ["stable"],
            "src_uri": "https://www.openssl.org/source/openssl-3.2.0.tar.gz",
            "sha256": "...",
            "configure_args": ["--prefix=/usr"],
        },
        "1.1.1w": {
            "slot": "1.1",
            "keywords": ["stable"],
            "src_uri": "https://www.openssl.org/source/openssl-1.1.1w.tar.gz",
            "sha256": "...",
            "configure_args": ["--prefix=/usr/lib/openssl-1.1"],
        },
    },
    default_version = "3.2.0",  # Main tagged target
)
```

This automatically creates:
- Versioned targets: `openssl-3.2.0`, `openssl-1.1.1w`
- Slot aliases: `openssl:3`, `openssl:1.1`
- Default alias: `openssl` → `openssl-3.2.0`

### Main Tagged Target (Default Version)

When a package has multiple versions, the `default_version` specifies which version is used when building without an explicit version:

```bash
# Build default version (3.2.0)
buck2 build //packages/linux/dev-libs:openssl

# Build specific version
buck2 build //packages/linux/dev-libs:openssl-1.1.1w

# Build by slot
buck2 build //packages/linux/dev-libs:openssl:1.1
```

If `default_version` is not specified, the system selects the newest stable version automatically.

### Specifying Version Dependencies

Packages can depend on specific versions using several methods:

#### Method 1: Slot Dependencies (Recommended)

Reference a slot to depend on any version within that slot:

```python
configure_make_package(
    name = "nginx",
    deps = [
        "//packages/linux/dev-libs/openssl:3",      # Any OpenSSL 3.x
        "//packages/linux/lang/python:3.11",        # Python 3.11.x
    ],
)
```

#### Method 2: Version Constraints

Use `version_dep()` for flexible version requirements:

```python
load("//defs:versions.bzl", "version_dep")

configure_make_package(
    name = "myapp",
    deps = [
        version_dep("//packages/linux/dev-libs/openssl", ">=3.0"),
        version_dep("//packages/linux/core/zlib", "~>1.2"),
        version_dep("//packages/linux/lang/python", ">=3.10 <4.0"),
    ],
)
```

Supported constraint operators:

| Operator | Example | Meaning |
|----------|---------|---------|
| (none) | `1.2.3` | Exact match |
| `>=` | `>=1.2.3` | Greater than or equal |
| `>` | `>1.2.3` | Greater than |
| `<=` | `<=1.2.3` | Less than or equal |
| `<` | `<1.2.3` | Less than |
| `~>` | `~>1.2` | Pessimistic (>=1.2.0, <2.0.0) |
| `*` | `1.2.*` | Wildcard match |

#### Method 3: Exact Version

For pinned dependencies:

```python
configure_make_package(
    name = "legacy-app",
    deps = [
        "//packages/linux/dev-libs/openssl:openssl-1.1.1w",
    ],
)
```

### Version Registry

For large codebases, use the central registry to manage versions:

```python
load("//defs:registry.bzl", "get_default_version", "get_stable_versions")

# Get default version for a package
default = get_default_version("core/openssl")  # Returns "3.2.0"

# Get all stable versions
stable = get_stable_versions("lang/python")  # Returns ["3.12.1", "3.11.7", ...]
```

### Best Practices

1. **Use slots for major versions**: Group compatible versions (e.g., `python:3.11`, `python:3.12`)

2. **Prefer slot dependencies**: Use `//pkg:slot` over exact versions for flexibility

3. **Set explicit defaults**: Always specify `default_version` to ensure predictable builds

4. **Mark legacy versions**: Use `masked` status for security-deprecated versions:
   ```python
   "1.0.2u": {
       "slot": "1.0",
       "keywords": ["masked"],  # Prevents accidental use
   },
   ```

5. **Use different install prefixes**: Allow co-installation of multiple versions:
   ```python
   "3.2.0": {"configure_args": ["--prefix=/usr"]},
   "1.1.1w": {"configure_args": ["--prefix=/usr/lib/openssl-1.1"]},
   ```

See [docs/VERSIONING.md](docs/VERSIONING.md) for complete documentation including version comparison algorithms, migration guides, and advanced registry functions.

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

## Package Sets

Package sets allow you to build complete systems by selecting predefined collections of packages, similar to Gentoo's system profiles.

### Available Profiles

| Profile | Description |
|---------|-------------|
| `minimal` | Bare essentials for bootable system |
| `server` | Headless server configuration |
| `desktop` | Full desktop with multimedia |
| `developer` | Development tools and languages |
| `hardened` | Security-focused configuration |
| `embedded` | Minimal footprint for IoT |
| `container` | Container base image |

### Using Package Sets

```python
load("//defs:package_sets.bzl", "system_set")

# Create a customized server
system_set(
    name = "my-server",
    profile = "server",
    additions = [
        "//packages/linux/net-vpn:wireguard-tools",
        "//packages/linux/www-servers:nginx",
    ],
    removals = [
        "//packages/linux/editors:emacs",
    ],
)
```

### Task-Specific Sets

Pre-configured sets for common use cases:

- `web-server` - Web server packages
- `database-server` - Database packages
- `container-host` - Container runtime and tools
- `virtualization-host` - VM hypervisor setup
- `vpn-server` - VPN server packages
- `monitoring` - System monitoring tools

### Desktop Environments

- `gnome-desktop` - GNOME
- `kde-desktop` - KDE Plasma
- `xfce-desktop` - XFCE
- `sway-desktop` - Sway (Wayland)
- `i3-desktop` - i3 (X11)

### Combining Sets

```python
load("//defs:package_sets.bzl", "combined_set")

combined_set(
    name = "full-stack-server",
    sets = ["@web-server", "@database-server", "@monitoring"],
)
```

See [docs/PACKAGE_SETS.md](docs/PACKAGE_SETS.md) for complete documentation.

## USE Flags

BuckOs includes a USE flag system similar to Gentoo for conditional package features:

```python
load("//defs:use_flags.bzl", "use_package")

use_package(
    name = "curl",
    version = "8.5.0",
    src_uri = "https://curl.se/download/curl-8.5.0.tar.xz",
    sha256 = "...",
    iuse = ["ssl", "http2", "zstd", "ipv6"],
    use_defaults = ["ssl", "ipv6"],
    use_deps = {
        "ssl": ["//packages/linux/dev-libs/openssl"],
        "http2": ["//packages/linux/net-libs/nghttp2"],
    },
    use_configure = {
        "ssl": "--with-ssl",
        "-ssl": "--without-ssl",
        "http2": "--with-nghttp2",
    },
)
```

See [docs/USE_FLAGS.md](docs/USE_FLAGS.md) for complete documentation.

## Patch System

BuckOs includes a comprehensive patch system for customizing package builds, similar to Gentoo's `/etc/portage/patches` and ebuild patch management.

### Patch Sources

Patches can come from multiple sources with clear precedence:
1. **Package patches** - Bundled with the package definition
2. **Distribution patches** - Applied by overlays/distributions
3. **Profile patches** - Applied based on build profile (hardened, musl, etc.)
4. **USE flag patches** - Applied conditionally based on USE flags
5. **User patches** - Applied from user configuration

### Using Patches in Packages

```python
load("//defs:package_defs.bzl", "configure_make_package", "epatch")

configure_make_package(
    name = "mypackage",
    source = ":mypackage-src",
    version = "1.0",
    pre_configure = epatch([
        "fix-build.patch",
        "security-fix.patch",
    ]),
)
```

### USE-Conditional Patches

```python
load("//defs:use_flags.bzl", "use_package")

use_package(
    name = "openssl",
    version = "3.2.0",
    src_uri = "...",
    sha256 = "...",
    iuse = ["bindist", "ktls"],
    use_patches = {
        "bindist": ["//patches/packages/dev-libs/openssl:ec-curves.patch"],
        "ktls": ["//patches/packages/dev-libs/openssl:ktls-support.patch"],
    },
)
```

### Profile-Based Patches

Apply patches based on build profile:

```python
load("//defs:package_customize.bzl", "package_config")

HARDENED_CONFIG = package_config(
    profile = "hardened",
    package_patches = {
        "glibc": ["//patches/profiles/hardened/glibc:ssp-all.patch"],
        "gcc": ["//patches/profiles/hardened/gcc:stack-clash.patch"],
    },
)
```

### User Patches

User patches are automatically applied from `/etc/portage/patches/<category>/<package>/`:

```bash
# Create user patch directory
mkdir -p /etc/portage/patches/dev-libs/openssl

# Add custom patch
cp my-custom-fix.patch /etc/portage/patches/dev-libs/openssl/
```

See [docs/PATCHES.md](docs/PATCHES.md) for complete documentation.

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

BuckOs provides automated QEMU boot scripts for easy testing.

#### Quick Start

```bash
# Build the complete QEMU testing environment
buck2 build //packages/linux/system:qemu-boot

# Run the generated boot script
./buck-out/v2/gen/root/<hash>/__qemu-boot__/qemu-boot.sh

# Or build and run in one step (find the output path)
buck2 build //packages/linux/system:qemu-boot --show-output
```

#### Available QEMU Targets

| Target | Description |
|--------|-------------|
| `//packages/linux/system:qemu-boot` | Basic QEMU boot (512MB RAM, 2 CPUs) |
| `//packages/linux/system:qemu-boot-dev` | Development mode (2GB RAM, 4 CPUs, KVM) |
| `//packages/linux/system:qemu-boot-full` | Full bootable system with dracut |
| `//packages/linux/system:qemu-boot-net` | With network (SSH on port 2222) |

### ISO Image Generation

Build bootable ISO images for distribution or installation:

```bash
# Build a hybrid (BIOS+EFI) bootable ISO
buck2 build //packages/linux/system:buckos-iso

# Find the output ISO file
buck2 build //packages/linux/system:buckos-iso --show-output
```

#### Available ISO Targets

| Target | Description |
|--------|-------------|
| `//packages/linux/system:buckos-iso` | Minimal hybrid ISO (BIOS+EFI) |
| `//packages/linux/system:buckos-iso-bios` | BIOS-only boot (for older systems) |
| `//packages/linux/system:buckos-iso-efi` | EFI-only boot (for modern systems) |
| `//packages/linux/system:buckos-live-iso` | Live ISO with squashfs rootfs |
| `//packages/linux/system:buckos-full-iso` | Full system with dracut initramfs |
| `//packages/linux/system:buckos-iso-dev` | Development ISO with verbose boot |

#### Writing ISO to USB

```bash
# Find the built ISO
ISO=$(buck2 build //packages/linux/system:buckos-iso --show-output | awk '{print $2}')

# Write to USB drive (replace /dev/sdX with your device)
sudo dd if="$ISO" of=/dev/sdX bs=4M status=progress conv=fsync
```

#### Building Individual Components

```bash
# Build the kernel
buck2 build //packages/linux/kernel:linux

# Build the root filesystem
buck2 build //packages/linux/system:buckos-rootfs

# Build the initramfs image
buck2 build //packages/linux/system:buckos-initramfs

# Build bootable system with more packages
buck2 build //packages/linux/system:buckos-bootable-initramfs
```

#### Manual QEMU Boot

If you prefer to run QEMU manually:

```bash
# Build required components
buck2 build //packages/linux/kernel:linux
buck2 build //packages/linux/system:buckos-initramfs

# Find the output paths
KERNEL=$(buck2 build //packages/linux/kernel:linux --show-output | awk '{print $2}')
INITRAMFS=$(buck2 build //packages/linux/system:buckos-initramfs --show-output | awk '{print $2}')

# Boot with QEMU
qemu-system-x86_64 \
    -machine q35 \
    -m 512M \
    -smp 2 \
    -kernel "$KERNEL/boot/vmlinuz-6.6.10" \
    -initrd "$INITRAMFS" \
    -append "console=ttyS0 init=/sbin/init" \
    -nographic \
    -no-reboot
```

#### QEMU Boot Options

**Basic boot (serial console):**
```bash
qemu-system-x86_64 \
    -kernel $KERNEL/boot/vmlinuz-6.6.10 \
    -initrd $INITRAMFS \
    -append "console=ttyS0 init=/sbin/init" \
    -nographic
```

**With KVM acceleration (requires /dev/kvm):**
```bash
qemu-system-x86_64 \
    -enable-kvm \
    -kernel $KERNEL/boot/vmlinuz-6.6.10 \
    -initrd $INITRAMFS \
    -append "console=ttyS0 init=/sbin/init" \
    -nographic
```

**With networking (SSH access):**
```bash
qemu-system-x86_64 \
    -kernel $KERNEL/boot/vmlinuz-6.6.10 \
    -initrd $INITRAMFS \
    -append "console=ttyS0 init=/sbin/init" \
    -nographic \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=net0
```

**With a virtual disk:**
```bash
# Create a disk image
qemu-img create -f qcow2 disk.qcow2 8G

qemu-system-x86_64 \
    -kernel $KERNEL/boot/vmlinuz-6.6.10 \
    -initrd $INITRAMFS \
    -append "console=ttyS0 init=/sbin/init root=/dev/vda" \
    -nographic \
    -drive file=disk.qcow2,if=virtio,format=qcow2
```

#### Exiting QEMU

- Press `Ctrl-A X` to exit QEMU
- Or type `poweroff` in the shell

#### Troubleshooting

**Kernel panic - not syncing: No init found:**
- Ensure the initramfs contains `/sbin/init` or BusyBox
- Check kernel args include `init=/sbin/init`

**Cannot find kernel image:**
- Verify the kernel build completed: `buck2 build //packages/linux/kernel:linux`
- Check the output path with `--show-output`

**Slow boot without KVM:**
- Enable KVM with `-enable-kvm` if your system supports it
- Check with: `ls /dev/kvm`

**Network not working:**
- Ensure kernel has VirtIO network support (included in default config)
- Verify dhcpcd is included in rootfs for DHCP

## Security Features

BuckOs implements several security features inspired by Gentoo's build system to ensure package integrity and prevent supply chain attacks.

### Enhanced Checksum Verification

When downloading source packages, BuckOs verifies checksums and provides detailed feedback on mismatches:

```
✗ Checksum verification FAILED
  Expected: 7c26c04df547877ebc3df71ab8fecb011b5f75f5c8b9c35e8423e69ba1a1ce88
  Actual:   8a9b2e3f4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f
  File:     package-1.0.tar.gz
```

This makes it easy to identify and fix checksum mismatches - simply copy the actual checksum from the build log and update your BUCK file. The system also validates that checksums are properly formatted (64 hex characters for SHA256, 128 for SHA512).

**Implementation:** `defs/package_defs.bzl` lines 45-64

### Network Isolation During Build

Following Gentoo's sandbox approach, BuckOs enforces network isolation during the compile phase to prevent packages from downloading files during the build process.

**How it works:**
- Uses Linux namespaces (`unshare --net`) to create a network-isolated environment
- All build phases run without internet access:
  - `src_prepare` (patches, autoreconf)
  - `pre_configure`
  - `src_configure` (CMake/Meson/autotools)
  - `src_compile` (compilation)
  - `src_test` (testing)
  - `src_install` (installation)

**Example output:**
```
🔒 Running build phases in network-isolated environment (no internet access)
📦 Phase: src_configure
📦 Phase: src_compile
📦 Phase: src_install
```

If a package attempts network access during build, it fails with "Network is unreachable", making it easy to identify packages that need additional dependencies declared.

**Benefits:**
- **Security**: Prevents malicious build scripts from exfiltrating data or downloading malware
- **Reproducibility**: Ensures all dependencies are explicitly declared in BUCK files
- **Build correctness**: Forces proper dependency management (can't secretly download files)
- **Supply chain security**: Prevents unauthorized code execution during builds

**Exceptions:**
- Download phase (`download_source`) still has network access to fetch sources
- Gracefully falls back if `unshare` is not available (with warning)

**Implementation:** `defs/package_defs.bzl` lines 2158-2223

### Intelligent Error Detection and Reporting

BuckOs automatically detects common build errors and provides actionable fixes, making it easier to debug and fix build failures - especially useful for automation.

**Automatic error detection for:**
- Missing pkg-config dependencies
- CMake compatibility issues
- Meson unknown options
- Meson boolean format errors (Meson 1.0+)

**Example error output:**
```
✗ Build phase 'src_configure' FAILED (exit code: 1)
  Package: pulseaudio-17.0
  Category: audio/daemons
  Phase: src_configure
  Working directory: /path/to/build

Analyzing error log...

DETECTED: Meson boolean format error (Meson 1.0+)
  Fix: Replace true/false with enabled/disabled/auto in meson_args

Common fixes for src_configure:
  - Check if all dependencies are installed
  - Review configure_args in BUCK file
  - For CMake: Check cmake_args
  - For Meson: Ensure options use enabled/disabled/auto format
```

**Features:**
- Each build phase logs output to `$T/<phase>.log` for analysis
- Errors are detected using pattern matching
- Suggested fixes are specific to the error type
- Machine-parseable output for automation tools

**Implementation:** `defs/package_defs.bzl` lines 2215-2320

### GPG Signature Verification

Packages can optionally verify GPG signatures during download:

```python
download_source(
    name = "package-src",
    src_uri = "https://example.com/package-1.0.tar.gz",
    sha256 = "...",
    signature_uri = "https://example.com/package-1.0.tar.gz.asc",
    gpg_key = "ABCD1234...",  # GPG key fingerprint
    auto_detect_signature = True,  # Auto-detect .asc/.sig/.sign files
)
```

The system automatically:
- Downloads and verifies GPG signatures
- Imports trusted GPG keys
- Detects and rejects invalid signature files (HTML error pages, etc.)
- Reports verification status with detailed error messages

**Enhanced GPG error messages:**
```
✗ Signature verification FAILED
  File:         package-1.0.tar.gz
  Signature:    package-1.0.tar.gz.asc
  Signature URL: https://example.com/package-1.0.tar.gz.asc
  Expected Key: ABCD1234EF567890

GPG output:
gpg: Signature made ...
gpg: BAD signature from ...

Fix options:
  1. Disable GPG verification: Set auto_detect_signature=False in BUCK file
  2. Import the correct key: gpg --recv-keys <KEY_ID>
  3. Check if signature URL is correct
```

This makes it easy to:
- Identify which file/signature failed
- See what key was expected
- Get actionable steps to fix the issue
- Disable verification if needed for testing

## Comparison to Gentoo

| Gentoo | BuckOs |
|--------|---------|
| ebuild | BUCK file |
| eclass | eclasses.bzl, inherit() |
| emerge | buck2 build |
| PORTDIR | packages/ |
| USE flags | use_flags.bzl |
| DEPEND | deps |
| BDEPEND | bdepend |
| RDEPEND | rdepend |
| LICENSE | licenses.bzl |
| EAPI | eapi.bzl |
| make.profile | package_sets.bzl profiles |
| @system | SYSTEM_PACKAGES |
| @world | custom package_set() |
| /etc/portage/package.use | package_use() |
| SLOT | versions.bzl slots |
| SUBSLOT | versions.bzl subslots |
| package.mask | registry status: masked |
| /etc/portage/patches | patches/, user/patches |
| epatch | epatch(), eapply() |
| inherit | inherit() from eclasses.bzl |
| @FREE license group | @FREE from licenses.bzl |

For detailed comparison, see [docs/gentoo-comparison.md](docs/gentoo-comparison.md).

## License

MIT License - See individual packages for their respective licenses.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add your packages following the existing patterns
4. Submit a pull request

## Roadmap

- [x] Platform targeting support (Linux, BSD, macOS, Windows)
- [x] Add more packages (openssl, openssh, networking tools)
- [x] Implement USE flag-like configuration
- [x] Add package versioning and slots
- [x] Implement system profiles and package sets
- [x] Create initramfs generation target
- [x] Add QEMU testing infrastructure
- [x] Add ISO image generation
- [x] Implement patch system for package customization
- [x] Implement eclass inheritance system (11 eclasses)
- [x] Add license tracking with license groups
- [x] Implement EAPI versioning (EAPI 6-8)
- [x] Add subslot support for ABI compatibility
- [x] Implement VDB (installed package database)
- [x] Implement overlay system for local customizations
- [x] Add configuration protection (CONFIG_PROTECT)
- [x] Implement USE_EXPAND (PYTHON_TARGETS, CPU_FLAGS_X86, etc.)
- [x] Add advanced dependencies (blockers, SRC_URI features, REQUIRED_USE)
- [ ] Create package manager for installed systems
- [ ] Add packages for BSD, macOS, and Windows platforms
