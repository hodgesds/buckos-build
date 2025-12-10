#!/bin/bash
# ebuild-bootstrap-stage2.sh - Bootstrap Stage 2: Core System Utilities
#
# PURPOSE: Build core system utilities and tools using the cross-compilation toolchain
#
# USES:
#   - Stage 1 cross-gcc-pass2 (from /tools/bin)
#   - Stage 1 cross-glibc (from /tools or sysroot)
#   - Stage 1 cross-libstdc++ (from /tools or sysroot)
#   - NO host compiler or libraries
#
# BUILDS:
#   - ncurses, readline (terminal libraries)
#   - bash, coreutils, make (core shell/utilities)
#   - sed, gawk, grep, findutils, diffutils (text processing)
#   - tar, gzip, xz, bzip2 (compression)
#   - perl, python3 (build tool dependencies)
#   - pkg-config, m4, autoconf, automake (build tools)
#   - file, patch (utilities)
#
# OUTPUT: /tools directory with complete userland utilities
#
# ISOLATION LEVEL: STRONG
#   - Uses ONLY cross-compiler from Stage 1
#   - Links ONLY against Stage 1 libraries
#   - NO host PATH fallback
#   - NO host library paths
#   - Strict cross-compilation mode
#
# This script is SOURCED by the wrapper, not executed directly.
# Changes to this script invalidate packages that use ebuild_package with bootstrap_stage="stage2".
#
# Environment variables (set by wrapper):
#   _EBUILD_DESTDIR, _EBUILD_SRCDIR, _EBUILD_PKG_CONFIG_WRAPPER - paths
#   _EBUILD_DEP_DIRS - space-separated dependency directories
#   PN, PV, CATEGORY, SLOT, USE - package info
#   BOOTSTRAP_STAGE - should be "stage2"
#   PHASES_CONTENT - the build phases to execute

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

echo "========================================================================="
echo "BOOTSTRAP STAGE 2: Building Core System Utilities"
echo "========================================================================="
echo "Package: ${PN}-${PV}"
echo "Target: x86_64-buckos-linux-gnu"
echo "Stage: Building with Stage 1 cross-compiler"
echo "Isolation: STRONG (no host compiler/libraries)"
echo "========================================================================="

# Installation directories (from wrapper environment)
mkdir -p "$_EBUILD_DESTDIR"
export DESTDIR="$(cd "$_EBUILD_DESTDIR" && pwd)"
export OUT="$DESTDIR"  # Alias for compatibility
export S="$(cd "$_EBUILD_SRCDIR" && pwd)"
export WORKDIR="$(dirname "$S")"
export T="$WORKDIR/temp"
mkdir -p "$T"
PKG_CONFIG_WRAPPER_SCRIPT="$_EBUILD_PKG_CONFIG_WRAPPER"

# Convert dep dirs from space-separated to array
read -ra DEP_DIRS_ARRAY <<< "$_EBUILD_DEP_DIRS"

# Package variables are already exported by wrapper
export PACKAGE_NAME="$PN"

# Bootstrap configuration
BUCKOS_TARGET="x86_64-buckos-linux-gnu"
export BUCKOS_TARGET

# =============================================================================
# Stage 2: Dependency Path Setup
# =============================================================================
# Collect paths from Stage 1 dependencies

DEP_PATH=""
DEP_PYTHONPATH=""
DEP_BASE_DIRS=""
TOOLCHAIN_PATH=""
TOOLCHAIN_LIBPATH=""
TOOLCHAIN_INCLUDE=""
TOOLCHAIN_ROOT=""

for dep_dir in "${DEP_DIRS_ARRAY[@]}"; do
    # Convert to absolute path if relative
    if [[ "$dep_dir" != /* ]]; then
        dep_dir="$(cd "$dep_dir" 2>/dev/null && pwd)" || continue
    fi

    # Store base directory for packages that need direct access
    DEP_BASE_DIRS="${DEP_BASE_DIRS:+$DEP_BASE_DIRS:}$dep_dir"

    # Check if this is the bootstrap toolchain from Stage 1
    if [ -d "$dep_dir/tools/bin" ]; then
        TOOLCHAIN_PATH="${TOOLCHAIN_PATH:+$TOOLCHAIN_PATH:}$dep_dir/tools/bin"
        if [ -z "$BOOTSTRAP_SYSROOT" ] && [ -d "$dep_dir/tools" ]; then
            BOOTSTRAP_SYSROOT="$dep_dir/tools"
        fi
    fi

    # Collect toolchain library paths for runtime (bash, etc)
    if [ -d "$dep_dir/tools/lib" ]; then
        TOOLCHAIN_LIBPATH="${TOOLCHAIN_LIBPATH:+$TOOLCHAIN_LIBPATH:}$dep_dir/tools/lib"
    fi

    # Capture the full toolchain root directory (for glibc, etc)
    if [ -d "$dep_dir/usr/lib64" ] || [ -d "$dep_dir/usr/lib" ]; then
        TOOLCHAIN_ROOT="${TOOLCHAIN_ROOT:+$TOOLCHAIN_ROOT:}$dep_dir"
    fi

    # Capture include directory from toolchain dependencies
    if [ -d "$dep_dir/usr/include" ]; then
        TOOLCHAIN_INCLUDE="${TOOLCHAIN_INCLUDE:+$TOOLCHAIN_INCLUDE:}$dep_dir"
    fi

    # Regular dependency paths (other Stage 2 packages)
    if [ -d "$dep_dir/tools/bin" ]; then
        DEP_PATH="${DEP_PATH:+$DEP_PATH:}$dep_dir/tools/bin"
    fi
    if [ -d "$dep_dir/usr/bin" ]; then
        DEP_PATH="${DEP_PATH:+$DEP_PATH:}$dep_dir/usr/bin"
    fi
    if [ -d "$dep_dir/bin" ]; then
        DEP_PATH="${DEP_PATH:+$DEP_PATH:}$dep_dir/bin"
    fi

    # Add Python package paths
    for pypath in "$dep_dir/usr/lib/python"*/dist-packages "$dep_dir/usr/lib/python"*/site-packages; do
        if [ -d "$pypath" ]; then
            DEP_PYTHONPATH="${DEP_PYTHONPATH:+$DEP_PYTHONPATH:}$pypath"
        fi
    done
done

# Export toolchain paths for scripts that need them
export TOOLCHAIN_INCLUDE
export TOOLCHAIN_ROOT
export DEP_BASE_DIRS

# =============================================================================
# Stage 2: STRICT PATH Setup - NO HOST FALLBACK
# =============================================================================
# CRITICAL: Stage 2 uses ONLY bootstrap tools, NO host system fallback
# This ensures we're building with our own toolchain, not accidentally
# using host tools

if [ -z "$TOOLCHAIN_PATH" ]; then
    echo "========================================================================="
    echo "ERROR: TOOLCHAIN_PATH is empty!"
    echo "Stage 2 requires Stage 1 cross-compiler in dependencies."
    echo "========================================================================="
    exit 1
fi

# Verify cross-compiler exists before continuing
if ! command -v ${BUCKOS_TARGET}-gcc >/dev/null 2>&1; then
    # Try looking in TOOLCHAIN_PATH explicitly
    if [ -f "$TOOLCHAIN_PATH/${BUCKOS_TARGET}-gcc" ]; then
        export PATH="$TOOLCHAIN_PATH:$DEP_PATH"
    else
        echo "========================================================================="
        echo "ERROR: Cross-compiler ${BUCKOS_TARGET}-gcc not found!"
        echo "TOOLCHAIN_PATH: $TOOLCHAIN_PATH"
        echo "Available in TOOLCHAIN_PATH:"
        ls -la "$TOOLCHAIN_PATH" 2>/dev/null || echo "(directory not found)"
        echo "========================================================================="
        exit 1
    fi
else
    # STRICT: Only toolchain and dep paths, NO host PATH
    export PATH="$TOOLCHAIN_PATH:$DEP_PATH"
fi

echo "PATH (STRICT, no host): $PATH"

# Set up PYTHONPATH for Python-based build tools
if [ -n "$DEP_PYTHONPATH" ]; then
    export PYTHONPATH="${DEP_PYTHONPATH}${PYTHONPATH:+:$PYTHONPATH}"
fi

# =============================================================================
# Stage 2: Clear ALL Host Environment Variables
# =============================================================================
# CRITICAL: Prevent ANY host system contamination

unset LD_LIBRARY_PATH
unset LIBRARY_PATH
unset CPATH
unset C_INCLUDE_PATH
unset CPLUS_INCLUDE_PATH
unset PKG_CONFIG_PATH

# Also clear any lingering flags that might reference host paths
unset CFLAGS
unset CXXFLAGS
unset LDFLAGS
unset CPPFLAGS

# =============================================================================
# Stage 2: Cross-Compilation Setup
# =============================================================================
# Use cross-compiler from Stage 1 to build Stage 2 utilities

echo ""
echo "=== Stage 2 Cross-Compilation Configuration ==="
echo "Using Stage 1 cross-compiler: ${BUCKOS_TARGET}-gcc"

# Verify cross-compiler is accessible
if ! command -v ${BUCKOS_TARGET}-gcc >/dev/null 2>&1; then
    echo "ERROR: Cross-compiler not found in PATH"
    echo "PATH=$PATH"
    exit 1
fi

echo "Cross-compiler found at: $(command -v ${BUCKOS_TARGET}-gcc)"

# Set cross-compilation toolchain
export CC="${BUCKOS_TARGET}-gcc"
export CXX="${BUCKOS_TARGET}-g++"
export AR="${BUCKOS_TARGET}-ar"
export AS="${BUCKOS_TARGET}-as"
export LD="${BUCKOS_TARGET}-ld"
export NM="${BUCKOS_TARGET}-nm"
export RANLIB="${BUCKOS_TARGET}-ranlib"
export STRIP="${BUCKOS_TARGET}-strip"
export OBJCOPY="${BUCKOS_TARGET}-objcopy"
export OBJDUMP="${BUCKOS_TARGET}-objdump"
export READELF="${BUCKOS_TARGET}-readelf"

# Set sysroot for compilation if available
if [ -n "$BOOTSTRAP_SYSROOT" ]; then
    SYSROOT_FLAGS="--sysroot=$BOOTSTRAP_SYSROOT"
    export CFLAGS="-O2 $SYSROOT_FLAGS"
    export CXXFLAGS="-O2 $SYSROOT_FLAGS"
    export LDFLAGS="$SYSROOT_FLAGS"

    echo "Using sysroot: $BOOTSTRAP_SYSROOT"

    # Set pkg-config to use sysroot
    export PKG_CONFIG_SYSROOT_DIR="$BOOTSTRAP_SYSROOT"
    export PKG_CONFIG_PATH="$BOOTSTRAP_SYSROOT/usr/lib/pkgconfig:$BOOTSTRAP_SYSROOT/usr/share/pkgconfig"
else
    export CFLAGS="-O2"
    export CXXFLAGS="-O2"
    export LDFLAGS=""
fi

echo "CC=$CC"
echo "CXX=$CXX"
echo "CFLAGS=$CFLAGS"
echo "CXXFLAGS=$CXXFLAGS"
echo "LDFLAGS=$LDFLAGS"

# Set build/host triplets for autotools
export BUILD_TRIPLET="$(gcc -dumpmachine 2>/dev/null || echo "x86_64-pc-linux-gnu")"
export HOST_TRIPLET="$BUCKOS_TARGET"

echo "BUILD_TRIPLET=$BUILD_TRIPLET (host system)"
echo "HOST_TRIPLET=$HOST_TRIPLET (target system)"

# =============================================================================
# Stage 2: FOR_BUILD Variables
# =============================================================================
# Some packages need to build helper programs that run on the BUILD (host)
# system during compilation. These use HOST compiler with C17/C++17.
#
# Example: bash's mkbuiltins program
#
# IMPORTANT: These tools run on the host but shouldn't link against host
# libraries where possible. We use clean flags.

export CC_FOR_BUILD="${CC_FOR_BUILD:-gcc -std=gnu17}"
export CXX_FOR_BUILD="${CXX_FOR_BUILD:-g++ -std=gnu++17}"
export CFLAGS_FOR_BUILD="${CFLAGS_FOR_BUILD:--O2 -std=gnu17}"
export CXXFLAGS_FOR_BUILD="${CXXFLAGS_FOR_BUILD:--O2 -std=gnu++17}"
export LDFLAGS_FOR_BUILD="${LDFLAGS_FOR_BUILD:-}"
export CPPFLAGS_FOR_BUILD="${CPPFLAGS_FOR_BUILD:-}"

echo "CC_FOR_BUILD=$CC_FOR_BUILD (for build-time helper tools)"
echo "CXX_FOR_BUILD=$CXX_FOR_BUILD"

# =============================================================================
# Stage 2: Library Path Setup
# =============================================================================
# Set up library paths from Stage 1 and other Stage 2 dependencies

DEP_LIBPATH=""
DEP_PKG_CONFIG_PATH=""

for dep_dir_raw in "${DEP_DIRS_ARRAY[@]}"; do
    # Convert to absolute path
    if [[ "$dep_dir_raw" = /* ]]; then
        dep_dir="$dep_dir_raw"
    else
        dep_dir="$(cd "$dep_dir_raw" 2>/dev/null && pwd)" || dep_dir="$(pwd)/$dep_dir_raw"
    fi

    # Collect library paths (priority: tools/lib, lib64, lib)
    if [ -d "$dep_dir/tools/lib64" ]; then
        DEP_LIBPATH="${DEP_LIBPATH:+$DEP_LIBPATH:}$dep_dir/tools/lib64"
    fi
    if [ -d "$dep_dir/tools/lib" ]; then
        DEP_LIBPATH="${DEP_LIBPATH:+$DEP_LIBPATH:}$dep_dir/tools/lib"
    fi
    if [ -d "$dep_dir/usr/lib64" ]; then
        DEP_LIBPATH="${DEP_LIBPATH:+$DEP_LIBPATH:}$dep_dir/usr/lib64"
    fi
    if [ -d "$dep_dir/usr/lib" ]; then
        DEP_LIBPATH="${DEP_LIBPATH:+$DEP_LIBPATH:}$dep_dir/usr/lib"
    fi
    if [ -d "$dep_dir/lib64" ]; then
        DEP_LIBPATH="${DEP_LIBPATH:+$DEP_LIBPATH:}$dep_dir/lib64"
    fi
    if [ -d "$dep_dir/lib" ]; then
        DEP_LIBPATH="${DEP_LIBPATH:+$DEP_LIBPATH:}$dep_dir/lib"
    fi

    # Collect pkg-config paths
    if [ -d "$dep_dir/tools/lib/pkgconfig" ]; then
        DEP_PKG_CONFIG_PATH="${DEP_PKG_CONFIG_PATH:+$DEP_PKG_CONFIG_PATH:}$dep_dir/tools/lib/pkgconfig"
    fi
    if [ -d "$dep_dir/usr/lib64/pkgconfig" ]; then
        DEP_PKG_CONFIG_PATH="${DEP_PKG_CONFIG_PATH:+$DEP_PKG_CONFIG_PATH:}$dep_dir/usr/lib64/pkgconfig"
    fi
    if [ -d "$dep_dir/usr/lib/pkgconfig" ]; then
        DEP_PKG_CONFIG_PATH="${DEP_PKG_CONFIG_PATH:+$DEP_PKG_CONFIG_PATH:}$dep_dir/usr/lib/pkgconfig"
    fi
    if [ -d "$dep_dir/usr/share/pkgconfig" ]; then
        DEP_PKG_CONFIG_PATH="${DEP_PKG_CONFIG_PATH:+$DEP_PKG_CONFIG_PATH:}$dep_dir/usr/share/pkgconfig"
    fi
done

# Add library paths to LDFLAGS (in addition to sysroot)
if [ -n "$DEP_LIBPATH" ]; then
    for lib_dir in ${DEP_LIBPATH//:/ }; do
        export LDFLAGS="$LDFLAGS -L$lib_dir"
    done
fi

# Set up pkg-config
if [ -n "$DEP_PKG_CONFIG_PATH" ]; then
    if [ -n "$PKG_CONFIG_PATH" ]; then
        export PKG_CONFIG_PATH="$DEP_PKG_CONFIG_PATH:$PKG_CONFIG_PATH"
    else
        export PKG_CONFIG_PATH="$DEP_PKG_CONFIG_PATH"
    fi
fi

# Use our pkg-config wrapper if available
if [ -f "$PKG_CONFIG_WRAPPER_SCRIPT" ]; then
    export PKG_CONFIG="$PKG_CONFIG_WRAPPER_SCRIPT"
    echo "Using pkg-config wrapper: $PKG_CONFIG_WRAPPER_SCRIPT"
fi

echo "=== End Stage 2 Setup ==="
echo ""

# =============================================================================
# Execute Build Phases
# =============================================================================
cd "$S"

# Source the phases content
eval "$PHASES_CONTENT"

# Run the phases in order
echo ""
echo "=== Running src_prepare ==="
src_prepare || true  # Optional phase

echo ""
echo "=== Running src_configure ==="
src_configure

echo ""
echo "=== Running src_compile ==="
src_compile

echo ""
echo "=== Running src_install ==="
src_install

# =============================================================================
# Stage 2: Post-Install Verification
# =============================================================================
echo ""
echo "=== Stage 2 Post-Install Verification ==="

# Check that binaries were actually built
BINARY_COUNT=$(find "$DESTDIR" -type f -executable 2>/dev/null | wc -l)
LIBRARY_COUNT=$(find "$DESTDIR" -type f -name '*.so*' 2>/dev/null | wc -l)

echo "Installed: $BINARY_COUNT executables, $LIBRARY_COUNT shared libraries"

# Sample check for host library contamination (quick check)
if command -v ldd >/dev/null 2>&1; then
    echo ""
    echo "Checking for host library dependencies (sample)..."
    SAMPLE_BINARY=$(find "$DESTDIR" -type f -executable | head -1)
    if [ -n "$SAMPLE_BINARY" ] && file "$SAMPLE_BINARY" 2>/dev/null | grep -q "ELF"; then
        echo "Sample binary: $SAMPLE_BINARY"
        if ldd "$SAMPLE_BINARY" 2>/dev/null | grep -E "(/lib64/|/usr/lib/)" | grep -v "buckos" | grep -v "/tools/"; then
            echo "WARNING: Binary may link to host libraries!"
            echo "Full ldd output:"
            ldd "$SAMPLE_BINARY" || true
        else
            echo "OK: No obvious host library dependencies detected"
        fi
    fi
fi

echo "=== End Stage 2 Verification ==="
echo ""

echo "========================================================================="
echo "BOOTSTRAP STAGE 2 COMPLETE: Core utilities built successfully"
echo "========================================================================="
