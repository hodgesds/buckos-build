"""
Package build rules for BuckOs Linux Distribution.
Similar to Gentoo's ebuild system but using Buck2.
"""

load("//defs:eclasses.bzl", "ECLASSES", "inherit")
load("//defs:use_flags.bzl",
     "get_effective_use",
     "use_dep",
     "use_cmake_options",
     "use_meson_options",
     "use_configure_args",
     "use_cargo_args",
     "use_go_build_args")

# Package metadata structure
PackageInfo = provider(fields = [
    "name",
    "version",
    "description",
    "homepage",
    "license",
    "src_uri",
    "checksum",
    "dependencies",
    "build_dependencies",
    "maintainers",  # List of maintainer IDs for package support contacts
])

def _download_source_impl(ctx: AnalysisContext) -> list[Provider]:
    """Download and extract source tarball."""
    out_dir = ctx.actions.declare_output(ctx.attrs.name, dir = True)

    # Build signature verification parameters
    sig_uri = ctx.attrs.signature_uri if ctx.attrs.signature_uri else ""
    gpg_key = ctx.attrs.gpg_key if ctx.attrs.gpg_key else ""
    gpg_keyring = ctx.attrs.gpg_keyring if ctx.attrs.gpg_keyring else ""
    auto_detect = "1" if ctx.attrs.auto_detect_signature else ""

    # Build exclude patterns for tar
    exclude_args = " ".join(["--exclude='{}'".format(pattern) for pattern in ctx.attrs.exclude_patterns])

    # Script to download and extract
    script = ctx.actions.write(
        "download.sh",
        """#!/bin/bash
set -e
mkdir -p "$1"
cd "$1"

# Download with original filename
URL="$2"
FILENAME="${URL##*/}"
curl -L -o "$FILENAME" "$URL"

# Verify checksum
EXPECTED_CHECKSUM="$3"
if [ -z "$EXPECTED_CHECKSUM" ]; then
    echo "✗ ERROR: No checksum provided" >&2
    exit 1
fi

# Compute actual checksum
ACTUAL_CHECKSUM=$(sha256sum "$FILENAME" | awk '{print $1}')

# Compare checksums
if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
    echo "✗ Checksum verification FAILED" >&2
    echo "  Expected: $EXPECTED_CHECKSUM" >&2
    echo "  Actual:   $ACTUAL_CHECKSUM" >&2
    echo "  File:     $FILENAME" >&2
    exit 1
else
    echo "✓ Checksum verification passed: $EXPECTED_CHECKSUM"
fi

# Verify GPG signature if provided
SIGNATURE_URI="$4"
GPG_KEY="$5"
GPG_KEYRING="$6"
AUTO_DETECT="$7"
EXCLUDE_ARGS="$8"

# Function to try signature verification
verify_signature() {
    local SIG_URL="$1"
    local SIG_FILENAME="${SIG_URL##*/}"

    # Try to download signature file
    if curl -L -f -o "$SIG_FILENAME" "$SIG_URL" 2>/dev/null; then
        echo "Found signature file: $SIG_URL"

        # Check if the downloaded file is actually a GPG signature
        # GPG signatures start with specific bytes or patterns
        FILETYPE=$(file -b "$SIG_FILENAME")
        if [[ "$FILETYPE" == *"HTML"* ]] || [[ "$FILETYPE" == *"ASCII text"* && ! "$FILETYPE" =~ "PGP" ]]; then
            # Check if it's HTML or non-PGP text (likely an error page)
            if head -1 "$SIG_FILENAME" | grep -q -i '<!DOCTYPE\|<html\|<head'; then
                echo "ℹ Signature file is HTML (likely 404/redirect), skipping verification"
                rm "$SIG_FILENAME"
                return 1
            fi
        fi

        # Verify the signature is valid OpenPGP data
        if ! gpg --batch --list-packets "$SIG_FILENAME" >/dev/null 2>&1; then
            echo "ℹ Downloaded file is not a valid GPG signature, skipping verification"
            rm "$SIG_FILENAME"
            return 1
        fi

        # Setup GPG options
        GPG_OPTS="--batch --no-default-keyring"

        if [ -n "$GPG_KEYRING" ]; then
            echo "Using keyring: $GPG_KEYRING"
            GPG_OPTS="$GPG_OPTS --keyring $GPG_KEYRING"
        fi

        # Import key if specified
        if [ -n "$GPG_KEY" ]; then
            echo "Importing GPG key: $GPG_KEY"
            # Try to import from keyserver (will fail gracefully if key already exists)
            gpg $GPG_OPTS --keyserver hkps://keys.openpgp.org --recv-keys "$GPG_KEY" 2>&1 | grep -v "already in keyring" || true
        fi

        # Verify the signature
        echo "Verifying GPG signature..."
        GPG_OUTPUT=$(gpg $GPG_OPTS --verify "$SIG_FILENAME" "$FILENAME" 2>&1)
        GPG_EXIT=$?

        if [ $GPG_EXIT -eq 0 ]; then
            echo "✓ Signature verification PASSED"
            rm "$SIG_FILENAME"
            return 0
        else
            echo "✗ Signature verification FAILED" >&2
            echo "  File:         $FILENAME" >&2
            echo "  Signature:    $SIG_FILENAME" >&2
            echo "  Signature URL: $SIG_URL" >&2
            if [ -n "$GPG_KEY" ]; then
                echo "  Expected Key: $GPG_KEY" >&2
            fi
            echo "" >&2
            echo "GPG output:" >&2
            echo "$GPG_OUTPUT" >&2
            echo "" >&2
            echo "Fix options:" >&2
            echo "  1. Disable GPG verification: Set auto_detect_signature=False in BUCK file" >&2
            echo "  2. Import the correct key: gpg --recv-keys <KEY_ID>" >&2
            echo "  3. Check if signature URL is correct" >&2
            rm "$SIG_FILENAME"
            exit 1
        fi
    fi
    return 1
}

# Try signature verification
if [ -n "$SIGNATURE_URI" ]; then
    # Explicit signature URI provided
    verify_signature "$SIGNATURE_URI" || exit 1
elif [ -n "$AUTO_DETECT" ]; then
    # Auto-detect: try common signature file extensions
    echo "Auto-detecting signature file..."
    TRIED=0
    for ext in .asc .sig .sign; do
        if verify_signature "${URL}${ext}"; then
            TRIED=1
            break
        fi
    done
    if [ $TRIED -eq 0 ]; then
        echo "ℹ No signature file found (tried .asc, .sig, .sign extensions)"
    fi
fi

# Detect actual file type (not just extension)
FILETYPE=$(file -b "$FILENAME")

# Extract based on actual file type
# Use --transform to decode hex escapes in filenames (Buck2 doesn't allow backslashes)
# Replace \x2d with - (dash), \x5c with nothing (backslash itself), etc.
if [[ "$FILETYPE" == *"gzip compressed"* ]]; then
    echo "Detected: gzip compressed tarball"
    tar xzf "$FILENAME" --strip-components=1 --transform 's/\\\\x2d/-/g' --transform 's/\\\\x5c//g' --transform 's/\\\\/-/g' $EXCLUDE_ARGS
    rm "$FILENAME"
elif [[ "$FILETYPE" == *"XZ compressed"* ]]; then
    echo "Detected: XZ compressed tarball"
    tar xJf "$FILENAME" --strip-components=1 --transform 's/\\\\x2d/-/g' --transform 's/\\\\x5c//g' --transform 's/\\\\/-/g' $EXCLUDE_ARGS
    rm "$FILENAME"
elif [[ "$FILETYPE" == *"bzip2 compressed"* ]]; then
    echo "Detected: bzip2 compressed tarball"
    tar xjf "$FILENAME" --strip-components=1 --transform 's/\\\\x2d/-/g' --transform 's/\\\\x5c//g' --transform 's/\\\\/-/g' $EXCLUDE_ARGS
    rm "$FILENAME"
elif [[ "$FILETYPE" == *"POSIX tar archive"* ]]; then
    echo "Detected: uncompressed tar archive"
    tar xf "$FILENAME" --strip-components=1 --transform 's/\\\\x2d/-/g' --transform 's/\\\\x5c//g' --transform 's/\\\\/-/g' $EXCLUDE_ARGS
    rm "$FILENAME"
elif [[ "$FILETYPE" == *"Zip archive"* ]]; then
    echo "Detected: Zip archive"
    unzip -q "$FILENAME"
    # For zip files, find the top-level dir and move contents up
    if [ $(ls -1 | wc -l) -eq 1 ] && [ -d "$(ls -1)" ]; then
        mv "$(ls -1)"/* . && rmdir "$(ls -1)"
    fi
    rm "$FILENAME"
elif [[ "$FILETYPE" == *"HTML"* ]]; then
    echo "Error: Downloaded file appears to be HTML, not an archive!" >&2
    echo "File type: $FILETYPE" >&2
    echo "This usually means the URL returned an error page instead of the file." >&2
    head -20 "$FILENAME" >&2
    exit 1
elif [[ "$FILETYPE" == *"ASCII text"* ]] || [[ "$FILETYPE" == *"C source"* ]] || [[ "$FILETYPE" == *"source"* ]] || [[ "$FILETYPE" == *"Unicode text"* ]]; then
    # Check if this is a valid source file (not an error page)
    # Valid source files have common extensions like .c, .h, .cpp, .py, .sh, etc.
    # Also handle certificate and key files like .pem, .crt, .key
    if [[ "$FILENAME" =~ \.(c|h|cpp|hpp|cc|cxx|py|sh|pl|rb|java|rs|go|js|ts|pem|crt|key)$ ]]; then
        echo "Detected: Single source file - $FILENAME"
        echo "Keeping file as-is (no extraction needed)"
        # Don't remove the file - we need to keep it
    else
        echo "Error: Downloaded file appears to be ASCII text, not an archive!" >&2
        echo "File type: $FILETYPE" >&2
        echo "Filename: $FILENAME" >&2
        echo "This usually means the URL returned an error page instead of the file." >&2
        head -20 "$FILENAME" >&2
        exit 1
    fi
else
    # Fallback: try tar with auto-detect
    echo "Unknown file type: $FILETYPE"
    echo "Attempting tar with auto-compression detection..."
    if tar xaf "$FILENAME" --strip-components=1 --transform 's/\\\\x2d/-/g' --transform 's/\\\\x5c//g' --transform 's/\\\\/-/g' 2>/dev/null; then
        echo "Successfully extracted with tar auto-detect"
        rm "$FILENAME"
    else
        echo "Error: Could not extract archive" >&2
        echo "File type: $FILETYPE" >&2
        exit 1
    fi
fi
""",
    )

    ctx.actions.run(
        cmd_args([
            "bash",
            script,
            out_dir.as_output(),
            ctx.attrs.src_uri,
            ctx.attrs.sha256,
            sig_uri,
            gpg_key,
            gpg_keyring,
            auto_detect,
            exclude_args,
        ]),
        category = "download",
        identifier = ctx.attrs.name,
    )

    return [DefaultInfo(default_output = out_dir)]

download_source = rule(
    impl = _download_source_impl,
    attrs = {
        "src_uri": attrs.string(),
        "sha256": attrs.string(),
        "signature_uri": attrs.option(attrs.string(), default = None),
        "gpg_key": attrs.option(attrs.string(), default = None),
        "gpg_keyring": attrs.option(attrs.string(), default = None),
        "auto_detect_signature": attrs.bool(default = True),
        "exclude_patterns": attrs.list(attrs.string(), default = []),
    },
)


def _kernel_config_impl(ctx: AnalysisContext) -> list[Provider]:
    """Merge kernel configuration fragments into a single .config file."""
    output = ctx.actions.declare_output(ctx.attrs.name + ".config")

    # Collect all config fragments
    config_files = []
    for frag in ctx.attrs.fragments:
        config_files.append(frag)

    script = ctx.actions.write(
        "merge_config.sh",
        """#!/bin/bash
set -e
OUTPUT="$1"
shift

# Start with empty config
> "$OUTPUT"

# Merge all config fragments
# Later fragments override earlier ones
for config in "$@"; do
    if [ -f "$config" ]; then
        # Read each line from the fragment
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip empty lines and comments for processing
            if [[ -z "$line" ]] || [[ "$line" =~ ^# ]]; then
                echo "$line" >> "$OUTPUT"
                continue
            fi

            # Extract config option name
            if [[ "$line" =~ ^(CONFIG_[A-Za-z0-9_]+)= ]]; then
                opt="${BASH_REMATCH[1]}"
                # Remove any existing setting for this option
                sed -i "/^$opt=/d" "$OUTPUT"
                sed -i "/^# $opt is not set/d" "$OUTPUT"
            elif [[ "$line" =~ ^#[[:space:]]*(CONFIG_[A-Za-z0-9_]+)[[:space:]]is[[:space:]]not[[:space:]]set ]]; then
                opt="${BASH_REMATCH[1]}"
                # Remove any existing setting for this option
                sed -i "/^$opt=/d" "$OUTPUT"
                sed -i "/^# $opt is not set/d" "$OUTPUT"
            fi

            echo "$line" >> "$OUTPUT"
        done < "$config"
    fi
done
""",
    )

    ctx.actions.run(
        cmd_args([
            "bash",
            script,
            output.as_output(),
        ] + config_files),
        category = "kernel_config",
        identifier = ctx.attrs.name,
    )

    return [DefaultInfo(default_output = output)]

kernel_config = rule(
    impl = _kernel_config_impl,
    attrs = {
        "fragments": attrs.list(attrs.source()),
    },
)

def _kernel_build_impl(ctx: AnalysisContext) -> list[Provider]:
    """Build Linux kernel with custom configuration."""
    install_dir = ctx.actions.declare_output(ctx.attrs.name, dir = True)
    src_dir = ctx.attrs.source[DefaultInfo].default_outputs[0]

    # Kernel config - can be a source file or output from kernel_config
    config_file = None
    if ctx.attrs.config:
        config_file = ctx.attrs.config
    elif ctx.attrs.config_dep:
        config_file = ctx.attrs.config_dep[DefaultInfo].default_outputs[0]

    script = ctx.actions.write(
        "build_kernel.sh",
        """#!/bin/bash
set -e

# Save absolute paths before changing directory
SRC_DIR="$(cd "$2" && pwd)"

# Convert install paths to absolute
if [[ "$1" = /* ]]; then
    INSTALL_BASE="$1"
else
    INSTALL_BASE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
fi

export INSTALL_PATH="$INSTALL_BASE/boot"
export INSTALL_MOD_PATH="$INSTALL_BASE"
mkdir -p "$INSTALL_PATH"

if [ -n "$3" ]; then
    # Convert config path to absolute if it's relative
    if [[ "$3" = /* ]]; then
        CONFIG_PATH="$3"
    else
        CONFIG_PATH="$(pwd)/$3"
    fi
fi

cd "$SRC_DIR"

# Apply config
if [ -n "$CONFIG_PATH" ]; then
    cp "$CONFIG_PATH" .config
    # Ensure config is complete with olddefconfig (non-interactive)
    make olddefconfig

    # If hardware-specific config fragment exists, merge it
    HARDWARE_CONFIG="$(dirname "$SRC_DIR")/../../hardware-kernel.config"
    if [ -f "$HARDWARE_CONFIG" ]; then
        echo "Merging hardware-specific kernel config..."
        # Use kernel's merge script to combine base config with hardware fragment
        scripts/kconfig/merge_config.sh -m .config "$HARDWARE_CONFIG"
        # Update config with new options (non-interactive)
        make olddefconfig
    fi
else
    make defconfig
fi

# Build kernel
make -j$(nproc)

# Install
make install
make modules_install
""",
    )

    # Build command arguments
    cmd = cmd_args([
        "bash",
        script,
        install_dir.as_output(),
        src_dir,
    ])

    # Add config file if present
    if config_file:
        cmd.add(config_file)

    ctx.actions.run(
        cmd,
        category = "kernel",
        identifier = ctx.attrs.name,
    )

    return [DefaultInfo(default_output = install_dir)]

kernel_build = rule(
    impl = _kernel_build_impl,
    attrs = {
        "source": attrs.dep(),
        "version": attrs.string(),
        "config": attrs.option(attrs.source(), default = None),
        "config_dep": attrs.option(attrs.dep(), default = None),
    },
)

def _binary_package_impl(ctx: AnalysisContext) -> list[Provider]:
    """
    Create a package from pre-built binaries with custom installation script.

    This rule is designed for packages that:
    - Download precompiled binaries
    - Require bootstrap compilation (like Go, GHC, Rust)
    - Need custom installation logic

    Environment variables available in install_script:
    - $SRCS: Directory containing extracted source files from all srcs dependencies
    - $OUT: Output/installation directory (like $DESTDIR)
    - $WORK: Working directory for temporary files
    - $BUILD_DIR: Build subdirectory
    - $PN: Package name
    - $PV: Package version
    """
    install_dir = ctx.actions.declare_output(ctx.attrs.name, dir = True)

    # Collect source directories from dependencies
    src_dirs = []
    for src in ctx.attrs.srcs:
        src_dirs.append(src[DefaultInfo].default_outputs[0])

    # Build the installation script
    install_script = ctx.attrs.install_script if ctx.attrs.install_script else """
        # Default: copy all source contents to output
        cp -r $SRCS/* $OUT/ 2>/dev/null || true
    """

    # Pre-install commands
    pre_install = ctx.attrs.pre_install if ctx.attrs.pre_install else ""

    # Post-install commands
    post_install = ctx.attrs.post_install if ctx.attrs.post_install else ""

    script = ctx.actions.write(
        "install_binary.sh",
        """#!/bin/bash
set -e

# Package variables
export PN="{name}"
export PV="{version}"
export PACKAGE_NAME="{name}"

# Directory setup
mkdir -p "$1"
mkdir -p "$2"
export OUT="$(cd "$1" && pwd)"
export WORK="$(cd "$2" && pwd)"
export SRCS="$(cd "$3" && pwd)"
export BUILD_DIR="$WORK/build"

mkdir -p "$BUILD_DIR"

# Change to working directory
cd "$WORK"

# Pre-install hook
{pre_install}

# Main installation script
{install_script}

# Post-install hook
{post_install}
""".format(
            name = ctx.attrs.name,
            version = ctx.attrs.version,
            pre_install = pre_install,
            install_script = install_script,
            post_install = post_install,
        ),
    )

    # Build command with all source directories
    # We create a combined source directory
    combine_script = ctx.actions.write(
        "combine_sources.sh",
        """#!/bin/bash
set -e
COMBINED_DIR="$1"
shift
mkdir -p "$COMBINED_DIR"
for src_dir in "$@"; do
    if [ -d "$src_dir" ]; then
        cp -r "$src_dir"/* "$COMBINED_DIR/" 2>/dev/null || true
    fi
done
""",
    )

    # Create intermediate combined sources directory
    combined_srcs = ctx.actions.declare_output(ctx.attrs.name + "-combined-srcs", dir = True)
    work_dir = ctx.actions.declare_output(ctx.attrs.name + "-work", dir = True)

    # First combine the sources
    combine_cmd = cmd_args(["bash", combine_script, combined_srcs.as_output()])
    for src_dir in src_dirs:
        combine_cmd.add(src_dir)

    ctx.actions.run(
        combine_cmd,
        category = "combine",
        identifier = ctx.attrs.name + "-combine",
    )

    # Then run the installation
    ctx.actions.run(
        cmd_args([
            "bash",
            script,
            install_dir.as_output(),
            work_dir.as_output(),
            combined_srcs,
        ]),
        category = "binary_install",
        identifier = ctx.attrs.name,
    )

    return [
        DefaultInfo(default_output = install_dir),
        PackageInfo(
            name = ctx.attrs.name,
            version = ctx.attrs.version,
            description = ctx.attrs.description,
            homepage = ctx.attrs.homepage,
            license = ctx.attrs.license,
            src_uri = "",
            checksum = "",
            dependencies = ctx.attrs.deps,
            build_dependencies = ctx.attrs.build_deps,
            maintainers = ctx.attrs.maintainers,
        ),
    ]

binary_package = rule(
    impl = _binary_package_impl,
    attrs = {
        "srcs": attrs.list(attrs.dep(), default = []),
        "install_script": attrs.string(default = ""),
        "pre_install": attrs.string(default = ""),
        "post_install": attrs.string(default = ""),
        "version": attrs.string(default = "1.0"),
        "description": attrs.string(default = ""),
        "homepage": attrs.string(default = ""),
        "license": attrs.string(default = ""),
        "deps": attrs.list(attrs.dep(), default = []),
        "build_deps": attrs.list(attrs.dep(), default = []),
        "maintainers": attrs.list(attrs.string(), default = []),
    },
)

# -----------------------------------------------------------------------------
# Precompiled Binary Package Rule
# -----------------------------------------------------------------------------

def _precompiled_package_impl(ctx: AnalysisContext) -> list[Provider]:
    """
    Simple rule for packages that are downloaded as precompiled binaries
    and just need to be extracted to the right location.

    This is simpler than binary_package when you just need to:
    - Download a binary tarball
    - Extract it to a specific location
    - Optionally create symlinks
    """
    install_dir = ctx.actions.declare_output(ctx.attrs.name, dir = True)

    # Get source directory from dependency
    src_dir = ctx.attrs.source[DefaultInfo].default_outputs[0]

    # Build the installation script
    extract_to = ctx.attrs.extract_to if ctx.attrs.extract_to else "/usr"

    # Generate symlink commands
    symlink_cmds = []
    for link, target in ctx.attrs.symlinks.items():
        symlink_cmds.append('mkdir -p "$OUT/$(dirname "{}")"'.format(link))
        symlink_cmds.append('ln -sf "{}" "$OUT/{}"'.format(target, link))
    symlinks_script = "\n".join(symlink_cmds)

    script = ctx.actions.write(
        "install_precompiled.sh",
        """#!/bin/bash
set -e

export OUT="$1"
export SRC="$2"

# Create target directory
mkdir -p "$OUT{extract_to}"

# Copy precompiled files
cp -r "$SRC"/* "$OUT{extract_to}/" 2>/dev/null || true

# Create symlinks
{symlinks}
""".format(
            extract_to = extract_to,
            symlinks = symlinks_script,
        ),
    )

    ctx.actions.run(
        cmd_args([
            "bash",
            script,
            install_dir.as_output(),
            src_dir,
        ]),
        category = "precompiled",
        identifier = ctx.attrs.name,
    )

    return [
        DefaultInfo(default_output = install_dir),
        PackageInfo(
            name = ctx.attrs.name,
            version = ctx.attrs.version,
            description = ctx.attrs.description,
            homepage = ctx.attrs.homepage,
            license = ctx.attrs.license,
            src_uri = "",
            checksum = "",
            dependencies = ctx.attrs.deps,
            build_dependencies = [],
            maintainers = ctx.attrs.maintainers,
        ),
    ]

precompiled_package = rule(
    impl = _precompiled_package_impl,
    attrs = {
        "source": attrs.dep(),
        "version": attrs.string(),
        "extract_to": attrs.string(default = "/usr"),
        "symlinks": attrs.dict(attrs.string(), attrs.string(), default = {}),
        "description": attrs.string(default = ""),
        "homepage": attrs.string(default = ""),
        "license": attrs.string(default = ""),
        "deps": attrs.list(attrs.dep(), default = []),
        "maintainers": attrs.list(attrs.string(), default = []),
    },
)

def _rootfs_impl(ctx: AnalysisContext) -> list[Provider]:
    """Assemble a root filesystem from packages."""
    rootfs_dir = ctx.actions.declare_output(ctx.attrs.name, dir = True)

    # Recursively collect all packages and their runtime dependencies
    all_packages = {}  # Use dict to avoid duplicates

    def collect_package_deps(pkg):
        """Recursively collect a package and its runtime dependencies."""
        # Get default outputs
        default_outputs = pkg[DefaultInfo].default_outputs

        # Add all outputs to our collection
        for output in default_outputs:
            pkg_key = str(output)
            if pkg_key not in all_packages:
                all_packages[pkg_key] = output

        # Try to collect runtime dependencies if this target has PackageInfo
        # Use get() method which returns None if provider doesn't exist
        pkg_info = pkg.get(PackageInfo)
        if pkg_info and pkg_info.dependencies:
            for dep in pkg_info.dependencies:
                collect_package_deps(dep)

    # Collect all packages starting from the explicitly listed ones
    for pkg in ctx.attrs.packages:
        collect_package_deps(pkg)

    # Convert to list for command arguments
    pkg_dirs = list(all_packages.values())

    # Create assembly script
    script_content = """#!/bin/bash
set -e
ROOTFS="$1"
shift

# Create base directory structure
mkdir -p "$ROOTFS"/{bin,sbin,lib,lib64,usr/{bin,sbin,lib,lib64},etc,var,tmp,proc,sys,dev,run,root,home}

# Copy packages
for pkg_dir in "$@"; do
    if [ -d "$pkg_dir" ]; then
        cp -a "$pkg_dir"/* "$ROOTFS"/ 2>/dev/null || true
    fi
done

# Create compatibility symlinks for /bin -> /usr/bin
# Many scripts expect common utilities in /bin (especially /bin/sh)
for cmd in sh bash; do
    if [ -f "$ROOTFS/usr/bin/$cmd" ] && [ ! -e "$ROOTFS/bin/$cmd" ]; then
        ln -sf ../usr/bin/$cmd "$ROOTFS/bin/$cmd"
    fi
done

# Set permissions
chmod 1777 "$ROOTFS/tmp"
chmod 755 "$ROOTFS/root"
"""

    script = ctx.actions.write("assemble.sh", script_content)

    cmd = cmd_args(["bash", script, rootfs_dir.as_output()])
    for pkg_dir in pkg_dirs:
        cmd.add(pkg_dir)

    ctx.actions.run(
        cmd,
        category = "rootfs",
        identifier = ctx.attrs.name,
    )

    return [DefaultInfo(default_output = rootfs_dir)]

rootfs = rule(
    impl = _rootfs_impl,
    attrs = {
        "packages": attrs.list(attrs.dep()),
    },
)

def _initramfs_impl(ctx: AnalysisContext) -> list[Provider]:
    """Create an initramfs cpio archive from a rootfs."""
    initramfs_file = ctx.actions.declare_output(ctx.attrs.name + ".cpio.gz")

    # Get rootfs directory from dependency
    rootfs_dir = ctx.attrs.rootfs[DefaultInfo].default_outputs[0]

    # Compression type
    compression = ctx.attrs.compression
    if compression == "gz":
        compress_cmd = "gzip -9"
        suffix = ".gz"
    elif compression == "xz":
        compress_cmd = "xz -9 --check=crc32"
        suffix = ".xz"
    elif compression == "lz4":
        compress_cmd = "lz4 -l -9"
        suffix = ".lz4"
    elif compression == "zstd":
        compress_cmd = "zstd -19"
        suffix = ".zstd"
    else:
        compress_cmd = "gzip -9"
        suffix = ".gz"

    # Init binary path
    init_path = ctx.attrs.init if ctx.attrs.init else "/sbin/init"

    script = ctx.actions.write(
        "create_initramfs.sh",
        """#!/bin/bash
set -e

ROOTFS="$1"
OUTPUT="$2"
INIT_PATH="{init_path}"

# Create a temporary directory for initramfs modifications
WORK=$(mktemp -d)
trap "rm -rf $WORK" EXIT

# Copy rootfs to work directory
cp -a "$ROOTFS"/* "$WORK"/

# Ensure init exists
if [ ! -e "$WORK$INIT_PATH" ]; then
    # Try to find busybox or create a minimal init
    if [ -x "$WORK/bin/busybox" ]; then
        mkdir -p "$WORK/sbin"
        ln -sf /bin/busybox "$WORK/sbin/init"
    elif [ -x "$WORK/bin/sh" ]; then
        # Create minimal init script
        cat > "$WORK/sbin/init" << 'INIT_EOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
exec /bin/sh
INIT_EOF
        chmod +x "$WORK/sbin/init"
    fi
fi

# Create the cpio archive
cd "$WORK"
find . -print0 | cpio --null -o -H newc | {compress_cmd} > "$OUTPUT"

echo "Created initramfs: $OUTPUT"
""".format(init_path = init_path, compress_cmd = compress_cmd),
    )

    ctx.actions.run(
        cmd_args([
            "bash",
            script,
            rootfs_dir,
            initramfs_file.as_output(),
        ]),
        category = "initramfs",
        identifier = ctx.attrs.name,
    )

    return [DefaultInfo(default_output = initramfs_file)]

initramfs = rule(
    impl = _initramfs_impl,
    attrs = {
        "rootfs": attrs.dep(),
        "compression": attrs.string(default = "gz"),
        "init": attrs.string(default = "/sbin/init"),
    },
)

def _qemu_boot_script_impl(ctx: AnalysisContext) -> list[Provider]:
    """Generate a QEMU boot script for testing."""
    boot_script = ctx.actions.declare_output(ctx.attrs.name + ".sh")

    # Get kernel and initramfs
    kernel_dir = ctx.attrs.kernel[DefaultInfo].default_outputs[0]
    initramfs_file = ctx.attrs.initramfs[DefaultInfo].default_outputs[0]

    # QEMU options
    memory = ctx.attrs.memory
    cpus = ctx.attrs.cpus
    arch = ctx.attrs.arch
    extra_args = " ".join(ctx.attrs.extra_args) if ctx.attrs.extra_args else ""
    kernel_args = ctx.attrs.kernel_args if ctx.attrs.kernel_args else "console=ttyS0 quiet"

    # Determine QEMU binary based on architecture
    if arch == "x86_64":
        qemu_bin = "qemu-system-x86_64"
        machine = "q35"
    elif arch == "aarch64":
        qemu_bin = "qemu-system-aarch64"
        machine = "virt"
    elif arch == "riscv64":
        qemu_bin = "qemu-system-riscv64"
        machine = "virt"
    else:
        qemu_bin = "qemu-system-x86_64"
        machine = "q35"

    script_content = """#!/bin/bash
# QEMU Boot Script for BuckOs
# Generated by Buck2 build system

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Paths to built artifacts
KERNEL_DIR="{kernel_dir}"
INITRAMFS="{initramfs}"

# Find kernel image
KERNEL=""
for k in "$KERNEL_DIR/boot/vmlinuz"* "$KERNEL_DIR/boot/bzImage" "$KERNEL_DIR/vmlinuz"*; do
    if [ -f "$k" ]; then
        KERNEL="$k"
        break
    fi
done

if [ -z "$KERNEL" ]; then
    echo "Error: Cannot find kernel image in $KERNEL_DIR"
    exit 1
fi

echo "Booting BuckOs with QEMU..."
echo "  Kernel: $KERNEL"
echo "  Initramfs: $INITRAMFS"
echo ""
echo "Press Ctrl-A X to exit QEMU"
echo ""

{qemu_bin} \\
    -machine {machine} \\
    -m {memory} \\
    -smp {cpus} \\
    -kernel "$KERNEL" \\
    -initrd "$INITRAMFS" \\
    -append "{kernel_args}" \\
    -nographic \\
    -no-reboot \\
    {extra_args} \\
    "$@"
""".format(
        kernel_dir = kernel_dir,
        initramfs = initramfs_file,
        qemu_bin = qemu_bin,
        machine = machine,
        memory = memory,
        cpus = cpus,
        kernel_args = kernel_args,
        extra_args = extra_args,
    )

    ctx.actions.write(
        boot_script.as_output(),
        script_content,
        is_executable = True,
    )

    return [DefaultInfo(default_output = boot_script)]

qemu_boot_script = rule(
    impl = _qemu_boot_script_impl,
    attrs = {
        "kernel": attrs.dep(),
        "initramfs": attrs.dep(),
        "arch": attrs.string(default = "x86_64"),
        "memory": attrs.string(default = "512M"),
        "cpus": attrs.string(default = "2"),
        "kernel_args": attrs.string(default = "console=ttyS0 quiet"),
        "extra_args": attrs.list(attrs.string(), default = []),
    },
)

def _iso_image_impl(ctx: AnalysisContext) -> list[Provider]:
    """Create a bootable ISO image from kernel, initramfs, and optional rootfs."""
    iso_file = ctx.actions.declare_output(ctx.attrs.name + ".iso")

    # Get kernel and initramfs
    kernel_dir = ctx.attrs.kernel[DefaultInfo].default_outputs[0]
    initramfs_file = ctx.attrs.initramfs[DefaultInfo].default_outputs[0]

    # Optional rootfs for live system
    rootfs_dir = None
    if ctx.attrs.rootfs:
        rootfs_dir = ctx.attrs.rootfs[DefaultInfo].default_outputs[0]

    # Boot mode configuration
    boot_mode = ctx.attrs.boot_mode
    volume_label = ctx.attrs.volume_label
    kernel_args = ctx.attrs.kernel_args if ctx.attrs.kernel_args else "quiet"

    # GRUB configuration for EFI boot
    grub_cfg = """
# GRUB configuration for BuckOs ISO
set timeout=5
set default=0

menuentry "BuckOs Linux" {{
    linux /boot/vmlinuz {kernel_args}
    initrd /boot/initramfs.img
}}

menuentry "BuckOs Linux (recovery mode)" {{
    linux /boot/vmlinuz {kernel_args} single
    initrd /boot/initramfs.img
}}
""".format(kernel_args = kernel_args)

    # Isolinux configuration for BIOS boot
    isolinux_cfg = """
DEFAULT buckos
TIMEOUT 50
PROMPT 1

LABEL buckos
    MENU LABEL BuckOs Linux
    LINUX /boot/vmlinuz
    INITRD /boot/initramfs.img
    APPEND {kernel_args}

LABEL recovery
    MENU LABEL BuckOs Linux (recovery mode)
    LINUX /boot/vmlinuz
    INITRD /boot/initramfs.img
    APPEND {kernel_args} single
""".format(kernel_args = kernel_args)

    # Determine if we should include squashfs rootfs
    include_rootfs = "yes" if rootfs_dir else ""

    script = ctx.actions.write(
        "create_iso.sh",
        """#!/bin/bash
set -e

ISO_OUT="$1"
KERNEL_DIR="$2"
INITRAMFS="$3"
ROOTFS_DIR="$4"
BOOT_MODE="{boot_mode}"
VOLUME_LABEL="{volume_label}"

# Create ISO working directory
WORK=$(mktemp -d)
trap "rm -rf $WORK" EXIT

mkdir -p "$WORK/boot"
mkdir -p "$WORK/boot/grub"
mkdir -p "$WORK/isolinux"
mkdir -p "$WORK/EFI/BOOT"

# Find and copy kernel
KERNEL=""
for k in "$KERNEL_DIR/boot/vmlinuz"* "$KERNEL_DIR/boot/bzImage" "$KERNEL_DIR/vmlinuz"*; do
    if [ -f "$k" ]; then
        KERNEL="$k"
        break
    fi
done

if [ -z "$KERNEL" ]; then
    echo "Error: Cannot find kernel image in $KERNEL_DIR"
    exit 1
fi

cp "$KERNEL" "$WORK/boot/vmlinuz"
cp "$INITRAMFS" "$WORK/boot/initramfs.img"

# Create GRUB configuration
cat > "$WORK/boot/grub/grub.cfg" << 'GRUBCFG'
{grub_cfg}
GRUBCFG

# Create isolinux configuration
cat > "$WORK/isolinux/isolinux.cfg" << 'ISOCFG'
{isolinux_cfg}
ISOCFG

# Include rootfs as squashfs if provided
if [ -n "{include_rootfs}" ] && [ -d "$ROOTFS_DIR" ]; then
    echo "Creating squashfs from rootfs..."
    mkdir -p "$WORK/live"
    if command -v mksquashfs >/dev/null 2>&1; then
        mksquashfs "$ROOTFS_DIR" "$WORK/live/filesystem.squashfs" -comp xz -no-progress
    else
        echo "Warning: mksquashfs not found, skipping rootfs inclusion"
    fi
fi

# Create the ISO image based on boot mode
echo "Creating ISO image with boot mode: $BOOT_MODE"

if [ "$BOOT_MODE" = "bios" ] || [ "$BOOT_MODE" = "hybrid" ]; then
    # Check for isolinux/syslinux
    ISOLINUX_BIN=""
    for path in /usr/lib/syslinux/bios/isolinux.bin /usr/share/syslinux/isolinux.bin /usr/lib/ISOLINUX/isolinux.bin; do
        if [ -f "$path" ]; then
            ISOLINUX_BIN="$path"
            break
        fi
    done

    if [ -n "$ISOLINUX_BIN" ]; then
        cp "$ISOLINUX_BIN" "$WORK/isolinux/"

        # Copy ldlinux.c32 if available
        LDLINUX=""
        for path in /usr/lib/syslinux/bios/ldlinux.c32 /usr/share/syslinux/ldlinux.c32 /usr/lib/syslinux/ldlinux.c32; do
            if [ -f "$path" ]; then
                LDLINUX="$path"
                break
            fi
        done
        [ -n "$LDLINUX" ] && cp "$LDLINUX" "$WORK/isolinux/"
    fi
fi

# Create ISO using xorriso (preferred) or genisoimage
if command -v xorriso >/dev/null 2>&1; then
    case "$BOOT_MODE" in
        bios)
            xorriso -as mkisofs \\
                -o "$ISO_OUT" \\
                -isohybrid-mbr /usr/lib/syslinux/bios/isohdpfx.bin 2>/dev/null || true \\
                -c isolinux/boot.cat \\
                -b isolinux/isolinux.bin \\
                -no-emul-boot \\
                -boot-load-size 4 \\
                -boot-info-table \\
                -V "$VOLUME_LABEL" \\
                "$WORK"
            ;;
        efi)
            # Create EFI boot image
            mkdir -p "$WORK/EFI/BOOT"
            if command -v grub-mkimage >/dev/null 2>&1; then
                grub-mkimage -o "$WORK/EFI/BOOT/BOOTX64.EFI" -O x86_64-efi -p /boot/grub \\
                    part_gpt part_msdos fat iso9660 normal boot linux configfile loopback chain \\
                    efifwsetup efi_gop efi_uga ls search search_label search_fs_uuid search_fs_file \\
                    gfxterm gfxterm_background gfxterm_menu test all_video loadenv exfat ext2 ntfs \\
                    2>/dev/null || echo "Warning: grub-mkimage failed"
            fi

            # Create EFI boot image file
            dd if=/dev/zero of="$WORK/boot/efi.img" bs=1M count=10
            mkfs.vfat "$WORK/boot/efi.img"
            mmd -i "$WORK/boot/efi.img" ::/EFI ::/EFI/BOOT
            mcopy -i "$WORK/boot/efi.img" "$WORK/EFI/BOOT/BOOTX64.EFI" ::/EFI/BOOT/ 2>/dev/null || true

            xorriso -as mkisofs \\
                -o "$ISO_OUT" \\
                -e boot/efi.img \\
                -no-emul-boot \\
                -V "$VOLUME_LABEL" \\
                "$WORK"
            ;;
        hybrid|*)
            # Hybrid BIOS+EFI boot
            # Create EFI boot image
            mkdir -p "$WORK/EFI/BOOT"
            if command -v grub-mkimage >/dev/null 2>&1; then
                grub-mkimage -o "$WORK/EFI/BOOT/BOOTX64.EFI" -O x86_64-efi -p /boot/grub \\
                    part_gpt part_msdos fat iso9660 normal boot linux configfile loopback chain \\
                    efifwsetup efi_gop efi_uga ls search search_label search_fs_uuid search_fs_file \\
                    gfxterm gfxterm_background gfxterm_menu test all_video loadenv exfat ext2 ntfs \\
                    2>/dev/null || echo "Warning: grub-mkimage failed"
            fi

            # Create EFI boot image file
            dd if=/dev/zero of="$WORK/boot/efi.img" bs=1M count=10
            mkfs.vfat "$WORK/boot/efi.img" 2>/dev/null || true
            if command -v mmd >/dev/null 2>&1; then
                mmd -i "$WORK/boot/efi.img" ::/EFI ::/EFI/BOOT
                mcopy -i "$WORK/boot/efi.img" "$WORK/EFI/BOOT/BOOTX64.EFI" ::/EFI/BOOT/ 2>/dev/null || true
            fi

            # Build ISO with both BIOS and EFI support
            xorriso -as mkisofs \\
                -o "$ISO_OUT" \\
                -isohybrid-mbr /usr/lib/syslinux/bios/isohdpfx.bin 2>/dev/null || true \\
                -c isolinux/boot.cat \\
                -b isolinux/isolinux.bin \\
                -no-emul-boot \\
                -boot-load-size 4 \\
                -boot-info-table \\
                -eltorito-alt-boot \\
                -e boot/efi.img \\
                -no-emul-boot \\
                -isohybrid-gpt-basdat \\
                -V "$VOLUME_LABEL" \\
                "$WORK" || \\
            # Fallback to simpler ISO if hybrid fails
            xorriso -as mkisofs \\
                -o "$ISO_OUT" \\
                -c isolinux/boot.cat \\
                -b isolinux/isolinux.bin \\
                -no-emul-boot \\
                -boot-load-size 4 \\
                -boot-info-table \\
                -V "$VOLUME_LABEL" \\
                "$WORK"
            ;;
    esac
elif command -v genisoimage >/dev/null 2>&1; then
    genisoimage \\
        -o "$ISO_OUT" \\
        -b isolinux/isolinux.bin \\
        -c isolinux/boot.cat \\
        -no-emul-boot \\
        -boot-load-size 4 \\
        -boot-info-table \\
        -V "$VOLUME_LABEL" \\
        -J -R \\
        "$WORK"
elif command -v mkisofs >/dev/null 2>&1; then
    mkisofs \\
        -o "$ISO_OUT" \\
        -b isolinux/isolinux.bin \\
        -c isolinux/boot.cat \\
        -no-emul-boot \\
        -boot-load-size 4 \\
        -boot-info-table \\
        -V "$VOLUME_LABEL" \\
        -J -R \\
        "$WORK"
else
    echo "Error: No ISO creation tool found (xorriso, genisoimage, or mkisofs required)"
    exit 1
fi

echo "Created ISO image: $ISO_OUT"
ls -lh "$ISO_OUT"
""".format(
            boot_mode = boot_mode,
            volume_label = volume_label,
            grub_cfg = grub_cfg,
            isolinux_cfg = isolinux_cfg,
            include_rootfs = include_rootfs,
        ),
    )

    rootfs_arg = rootfs_dir if rootfs_dir else ""

    ctx.actions.run(
        cmd_args([
            "bash",
            script,
            iso_file.as_output(),
            kernel_dir,
            initramfs_file,
            rootfs_arg,
        ]),
        category = "iso",
        identifier = ctx.attrs.name,
    )

    return [DefaultInfo(default_output = iso_file)]

iso_image = rule(
    impl = _iso_image_impl,
    attrs = {
        "kernel": attrs.dep(),
        "initramfs": attrs.dep(),
        "rootfs": attrs.option(attrs.dep(), default = None),
        "boot_mode": attrs.string(default = "hybrid"),  # bios, efi, or hybrid
        "volume_label": attrs.string(default = "BUCKOS"),
        "kernel_args": attrs.string(default = "quiet"),
    },
)

# =============================================================================
# EBUILD-STYLE HELPER FUNCTIONS
# =============================================================================
# These helpers mirror Gentoo's ebuild system functionality for Buck2

# -----------------------------------------------------------------------------
# Logging and Output Helpers
# -----------------------------------------------------------------------------

def einfo(msg: str) -> str:
    """Print an informational message (green asterisk)."""
    return 'echo -e "\\033[32m * \\033[0m{}"'.format(msg)

def ewarn(msg: str) -> str:
    """Print a warning message (yellow asterisk)."""
    return 'echo -e "\\033[33m * \\033[0mWARNING: {}"'.format(msg)

def eerror(msg: str) -> str:
    """Print an error message (red asterisk)."""
    return 'echo -e "\\033[31m * \\033[0mERROR: {}"'.format(msg)

def ebegin(msg: str) -> str:
    """Print a message indicating start of a process."""
    return 'echo -e "\\033[32m * \\033[0m{}..."'.format(msg)

def eend(retval: str = "$?") -> str:
    """Print success/failure based on return value."""
    return '''
if [ {} -eq 0 ]; then
    echo -e "\\033[32m [ ok ]\\033[0m"
else
    echo -e "\\033[31m [ !! ]\\033[0m"
fi
'''.format(retval)

def die(msg: str) -> str:
    """Print error and exit with failure."""
    return '{}\nexit 1'.format(eerror(msg))

# -----------------------------------------------------------------------------
# Installation Directory Helpers
# -----------------------------------------------------------------------------

def into(dir: str) -> str:
    """Set the installation prefix for subsequent do* commands."""
    return 'export INSDESTTREE="{}"'.format(dir)

def insinto(dir: str) -> str:
    """Set installation directory for doins."""
    return 'export INSDESTTREE="{}"'.format(dir)

def exeinto(dir: str) -> str:
    """Set installation directory for doexe."""
    return 'export EXEDESTTREE="{}"'.format(dir)

def docinto(dir: str) -> str:
    """Set installation subdirectory for dodoc."""
    return 'export DOCDESTTREE="{}"'.format(dir)

# -----------------------------------------------------------------------------
# File Installation Helpers
# -----------------------------------------------------------------------------

def dobin(files: list[str]) -> str:
    """Install executables into /usr/bin."""
    cmds = ['mkdir -p "$DESTDIR/usr/bin"']
    for f in files:
        cmds.append('install -m 0755 "{}" "$DESTDIR/usr/bin/"'.format(f))
    return "\n".join(cmds)

def dosbin(files: list[str]) -> str:
    """Install system executables into /usr/sbin."""
    cmds = ['mkdir -p "$DESTDIR/usr/sbin"']
    for f in files:
        cmds.append('install -m 0755 "{}" "$DESTDIR/usr/sbin/"'.format(f))
    return "\n".join(cmds)

def dolib_so(files: list[str]) -> str:
    """Install shared libraries into /usr/lib64 (or /usr/lib)."""
    cmds = ['mkdir -p "$DESTDIR/${LIBDIR:-usr/lib64}"']
    for f in files:
        cmds.append('install -m 0755 "{}" "$DESTDIR/${{LIBDIR:-usr/lib64}}/"'.format(f))
    return "\n".join(cmds)

def dolib_a(files: list[str]) -> str:
    """Install static libraries into /usr/lib64 (or /usr/lib)."""
    cmds = ['mkdir -p "$DESTDIR/${LIBDIR:-usr/lib64}"']
    for f in files:
        cmds.append('install -m 0644 "{}" "$DESTDIR/${{LIBDIR:-usr/lib64}}/"'.format(f))
    return "\n".join(cmds)

def newlib_so(src: str, dst: str) -> str:
    """Install shared library with new name."""
    return '''mkdir -p "$DESTDIR/${{LIBDIR:-usr/lib64}}"
install -m 0755 "{}" "$DESTDIR/${{LIBDIR:-usr/lib64}}/{}"'''.format(src, dst)

def newlib_a(src: str, dst: str) -> str:
    """Install static library with new name."""
    return '''mkdir -p "$DESTDIR/${{LIBDIR:-usr/lib64}}"
install -m 0644 "{}" "$DESTDIR/${{LIBDIR:-usr/lib64}}/{}"'''.format(src, dst)

def doins(files: list[str]) -> str:
    """Install files into INSDESTTREE (default: /usr/share)."""
    cmds = ['mkdir -p "$DESTDIR/${INSDESTTREE:-usr/share}"']
    for f in files:
        cmds.append('install -m 0644 "{}" "$DESTDIR/${{INSDESTTREE:-usr/share}}/"'.format(f))
    return "\n".join(cmds)

def newins(src: str, dst: str) -> str:
    """Install file with new name into INSDESTTREE."""
    return '''mkdir -p "$DESTDIR/${{INSDESTTREE:-usr/share}}"
install -m 0644 "{}" "$DESTDIR/${{INSDESTTREE:-usr/share}}/{}"'''.format(src, dst)

def doexe(files: list[str]) -> str:
    """Install executables into EXEDESTTREE."""
    cmds = ['mkdir -p "$DESTDIR/${EXEDESTTREE:-usr/bin}"']
    for f in files:
        cmds.append('install -m 0755 "{}" "$DESTDIR/${{EXEDESTTREE:-usr/bin}}/"'.format(f))
    return "\n".join(cmds)

def newexe(src: str, dst: str) -> str:
    """Install executable with new name."""
    return '''mkdir -p "$DESTDIR/${{EXEDESTTREE:-usr/bin}}"
install -m 0755 "{}" "$DESTDIR/${{EXEDESTTREE:-usr/bin}}/{}"'''.format(src, dst)

def doheader(files: list[str]) -> str:
    """Install header files into /usr/include."""
    cmds = ['mkdir -p "$DESTDIR/usr/include"']
    for f in files:
        cmds.append('install -m 0644 "{}" "$DESTDIR/usr/include/"'.format(f))
    return "\n".join(cmds)

def newheader(src: str, dst: str) -> str:
    """Install header file with new name."""
    return '''mkdir -p "$DESTDIR/usr/include"
install -m 0644 "{}" "$DESTDIR/usr/include/{}"'''.format(src, dst)

def doconfd(files: list[str]) -> str:
    """Install config files into /etc/conf.d."""
    cmds = ['mkdir -p "$DESTDIR/etc/conf.d"']
    for f in files:
        cmds.append('install -m 0644 "{}" "$DESTDIR/etc/conf.d/"'.format(f))
    return "\n".join(cmds)

def doenvd(files: list[str]) -> str:
    """Install environment files into /etc/env.d."""
    cmds = ['mkdir -p "$DESTDIR/etc/env.d"']
    for f in files:
        cmds.append('install -m 0644 "{}" "$DESTDIR/etc/env.d/"'.format(f))
    return "\n".join(cmds)

def doinitd(files: list[str]) -> str:
    """Install init scripts into /etc/init.d."""
    cmds = ['mkdir -p "$DESTDIR/etc/init.d"']
    for f in files:
        cmds.append('install -m 0755 "{}" "$DESTDIR/etc/init.d/"'.format(f))
    return "\n".join(cmds)

def dosym(target: str, link: str) -> str:
    """Create a symbolic link."""
    return '''mkdir -p "$DESTDIR/$(dirname "{}")"
ln -sf "{}" "$DESTDIR/{}"'''.format(link, target, link)

def dosym_rel(target: str, link: str) -> str:
    """Create a relative symbolic link."""
    return '''mkdir -p "$DESTDIR/$(dirname "{}")"
ln -srf "$DESTDIR/{}" "$DESTDIR/{}"'''.format(link, target, link)

def newbin(src: str, dst: str) -> str:
    """Install executable with new name into /usr/bin."""
    return '''mkdir -p "$DESTDIR/usr/bin"
install -m 0755 "{}" "$DESTDIR/usr/bin/{}"'''.format(src, dst)

def newsbin(src: str, dst: str) -> str:
    """Install system executable with new name into /usr/sbin."""
    return '''mkdir -p "$DESTDIR/usr/sbin"
install -m 0755 "{}" "$DESTDIR/usr/sbin/{}"'''.format(src, dst)

# -----------------------------------------------------------------------------
# Documentation Helpers
# -----------------------------------------------------------------------------

def dodoc(files: list[str]) -> str:
    """Install documentation files."""
    cmds = ['mkdir -p "$DESTDIR/usr/share/doc/${PN:-$PACKAGE_NAME}/${DOCDESTTREE:-}"']
    for f in files:
        cmds.append('install -m 0644 "{}" "$DESTDIR/usr/share/doc/${{PN:-$PACKAGE_NAME}}/${{DOCDESTTREE:-}}/"'.format(f))
    return "\n".join(cmds)

def newdoc(src: str, dst: str) -> str:
    """Install documentation file with new name."""
    return '''mkdir -p "$DESTDIR/usr/share/doc/${{PN:-$PACKAGE_NAME}}/${{DOCDESTTREE:-}}"
install -m 0644 "{}" "$DESTDIR/usr/share/doc/${{PN:-$PACKAGE_NAME}}/${{DOCDESTTREE:-}}/{}"'''.format(src, dst)

def doman(files: list[str]) -> str:
    """Install man pages."""
    cmds = []
    for f in files:
        # Detect man section from filename
        cmds.append('''
_manfile="{}"
_section="${{_manfile##*.}}"
mkdir -p "$DESTDIR/usr/share/man/man$_section"
install -m 0644 "$_manfile" "$DESTDIR/usr/share/man/man$_section/"
'''.format(f))
    return "\n".join(cmds)

def newman(src: str, dst: str) -> str:
    """Install man page with new name."""
    return '''
_section="${{{1}##*.}}"
mkdir -p "$DESTDIR/usr/share/man/man$_section"
install -m 0644 "{}" "$DESTDIR/usr/share/man/man$_section/{}"
'''.format(dst, src, dst)

def doinfo(files: list[str]) -> str:
    """Install GNU info files."""
    cmds = ['mkdir -p "$DESTDIR/usr/share/info"']
    for f in files:
        cmds.append('install -m 0644 "{}" "$DESTDIR/usr/share/info/"'.format(f))
    return "\n".join(cmds)

def dohtml(files: list[str], recursive: bool = False) -> str:
    """Install HTML documentation."""
    cmds = ['mkdir -p "$DESTDIR/usr/share/doc/${PN:-$PACKAGE_NAME}/html"']
    if recursive:
        for f in files:
            cmds.append('cp -r "{}" "$DESTDIR/usr/share/doc/${{PN:-$PACKAGE_NAME}}/html/"'.format(f))
    else:
        for f in files:
            cmds.append('install -m 0644 "{}" "$DESTDIR/usr/share/doc/${{PN:-$PACKAGE_NAME}}/html/"'.format(f))
    return "\n".join(cmds)

# -----------------------------------------------------------------------------
# Directory and Permission Helpers
# -----------------------------------------------------------------------------

def dodir(dirs: list[str]) -> str:
    """Create directories in DESTDIR."""
    cmds = []
    for d in dirs:
        cmds.append('mkdir -p "$DESTDIR/{}"'.format(d))
    return "\n".join(cmds)

def keepdir(dirs: list[str]) -> str:
    """Create directories and add .keep files to preserve empty dirs."""
    cmds = []
    for d in dirs:
        cmds.append('mkdir -p "$DESTDIR/{}"'.format(d))
        cmds.append('touch "$DESTDIR/{}/.keep"'.format(d))
    return "\n".join(cmds)

def fowners(owner: str, files: list[str]) -> str:
    """Change file ownership (recorded for package manager)."""
    cmds = []
    for f in files:
        cmds.append('chown {} "$DESTDIR/{}"'.format(owner, f))
    return "\n".join(cmds)

def fperms(mode: str, files: list[str]) -> str:
    """Change file permissions."""
    cmds = []
    for f in files:
        cmds.append('chmod {} "$DESTDIR/{}"'.format(mode, f))
    return "\n".join(cmds)

# -----------------------------------------------------------------------------
# Compilation Helpers
# -----------------------------------------------------------------------------

def emake(args: list[str] = []) -> str:
    """Run make with standard parallel jobs and arguments."""
    args_str = " ".join(args) if args else ""
    return 'make -j${{MAKEOPTS:-$(nproc)}} {}'.format(args_str)

def econf(args: list[str] = []) -> str:
    """Run configure with standard arguments."""
    args_str = " ".join(args) if args else ""
    return '''
ECONF_SOURCE="${{ECONF_SOURCE:-.}}"
"$ECONF_SOURCE/configure" \\
    --prefix="${{EPREFIX:-/usr}}" \\
    --build="${{CBUILD:-$(gcc -dumpmachine)}}" \\
    --host="${{CHOST:-$(gcc -dumpmachine)}}" \\
    --mandir="${{EPREFIX:-/usr}}/share/man" \\
    --infodir="${{EPREFIX:-/usr}}/share/info" \\
    --datadir="${{EPREFIX:-/usr}}/share" \\
    --sysconfdir="${{EPREFIX:-/etc}}" \\
    --localstatedir="${{EPREFIX:-/var}}" \\
    --libdir="${{EPREFIX:-/usr}}/${{LIBDIR_SUFFIX:-lib64}}" \\
    {}
'''.format(args_str)

def einstall(args: list[str] = []) -> str:
    """Run make install with DESTDIR."""
    args_str = " ".join(args) if args else ""
    return 'make DESTDIR="$DESTDIR" {} install'.format(args_str)

def eautoreconf() -> str:
    """Run autoreconf to regenerate autotools files."""
    return '''
{begin}
if [ -f configure.ac ] || [ -f configure.in ]; then
    autoreconf -fiv
fi
{end}
'''.format(begin = ebegin("Running autoreconf"), end = eend())

def elibtoolize() -> str:
    """Run libtoolize to update libtool scripts."""
    return '''
{begin}
if [ -f configure.ac ] || [ -f configure.in ]; then
    libtoolize --copy --force
fi
{end}
'''.format(begin = ebegin("Running libtoolize"), end = eend())

# -----------------------------------------------------------------------------
# Patch Helpers
# -----------------------------------------------------------------------------

def epatch(patches: list[str], strip: int = 1) -> str:
    """Apply patches to source."""
    cmds = []
    for p in patches:
        cmds.append('{}\npatch -p{} < "{}"'.format(
            ebegin("Applying patch {}".format(p)),
            strip,
            p,
        ))
    return "\n".join(cmds)

def eapply(patches: list[str], strip: int = 1) -> str:
    """Modern patch application (EAPI 6+)."""
    cmds = []
    for p in patches:
        cmds.append('''
{begin}
if [ -d "{patch}" ]; then
    for _p in "{patch}"/*.patch; do
        patch -p{strip} < "$_p" || die "Patch failed: $_p"
    done
else
    patch -p{strip} < "{patch}" || die "Patch failed: {patch}"
fi
'''.format(begin = ebegin("Applying {}".format(p)), patch = p, strip = strip))
    return "\n".join(cmds)

def eapply_user() -> str:
    """Apply user patches from /etc/portage/patches."""
    return '''
# Apply user patches if they exist
_user_patches="${{EPREFIX:-}}/etc/portage/patches/${{CATEGORY}}/${{PN}}"
if [ -d "$_user_patches" ]; then
    {}
    for _p in "$_user_patches"/*.patch; do
        [ -f "$_p" ] && patch -p1 < "$_p"
    done
fi
'''.format(ebegin("Applying user patches"))

# -----------------------------------------------------------------------------
# USE Flag Helpers
# -----------------------------------------------------------------------------

def use_enable(flag: str, option: str = "") -> str:
    """Generate --enable-X or --disable-X based on USE flag."""
    opt = option if option else flag
    return '''
if use {}; then
    echo "--enable-{}"
else
    echo "--disable-{}"
fi
'''.format(flag, opt, opt)

def use_with(flag: str, option: str = "") -> str:
    """Generate --with-X or --without-X based on USE flag."""
    opt = option if option else flag
    return '''
if use {}; then
    echo "--with-{}"
else
    echo "--without-{}"
fi
'''.format(flag, opt, opt)

def usev(flag: str, value: str = "") -> str:
    """Echo value if USE flag is enabled."""
    val = value if value else flag
    return '''
if use {}; then
    echo "{}"
fi
'''.format(flag, val)

def usex(flag: str, yes_val: str = "yes", no_val: str = "no") -> str:
    """Return different values based on USE flag."""
    return '''
if use {}; then
    echo "{}"
else
    echo "{}"
fi
'''.format(flag, yes_val, no_val)

def use_check(flag: str) -> str:
    """Return shell code to check if a USE flag is set."""
    return '[[ " $USE " == *" {} "* ]]'.format(flag)

# -----------------------------------------------------------------------------
# Build System Specific Helpers
# -----------------------------------------------------------------------------

def cmake_src_configure(args: list[str] = [], build_type: str = "Release") -> str:
    """Configure CMake project."""
    args_str = " ".join(args) if args else ""
    return '''
mkdir -p "${{BUILD_DIR:-build}}"
cd "${{BUILD_DIR:-build}}"
cmake \\
    -DCMAKE_INSTALL_PREFIX="${{EPREFIX:-/usr}}" \\
    -DCMAKE_BUILD_TYPE={build_type} \\
    -DCMAKE_INSTALL_LIBDIR="${{LIBDIR:-lib64}}" \\
    -DCMAKE_C_FLAGS="${{CFLAGS:-}}" \\
    -DCMAKE_CXX_FLAGS="${{CXXFLAGS:-}}" \\
    {args} \\
    ..
'''.format(build_type = build_type, args = args_str)

def cmake_src_compile(args: list[str] = []) -> str:
    """Build CMake project."""
    args_str = " ".join(args) if args else ""
    return '''
cd "${{BUILD_DIR:-build}}"
cmake --build . -j${{MAKEOPTS:-$(nproc)}} {}
'''.format(args_str)

def cmake_src_install(args: list[str] = []) -> str:
    """Install CMake project."""
    args_str = " ".join(args) if args else ""
    return '''
cd "${{BUILD_DIR:-build}}"
DESTDIR="$DESTDIR" cmake --install . {}
'''.format(args_str)

def meson_src_configure(args: list[str] = [], build_type: str = "release") -> str:
    """Configure Meson project."""
    args_str = " ".join(args) if args else ""
    return '''
meson setup "${{BUILD_DIR:-build}}" \\
    --prefix="${{EPREFIX:-/usr}}" \\
    --libdir="${{LIBDIR:-lib64}}" \\
    --buildtype={build_type} \\
    {}
'''.format(args_str, build_type = build_type)

def meson_src_compile() -> str:
    """Build Meson project."""
    return 'meson compile -C "${BUILD_DIR:-build}" -j${MAKEOPTS:-$(nproc)}'

def meson_src_install() -> str:
    """Install Meson project."""
    return 'DESTDIR="$DESTDIR" meson install -C "${BUILD_DIR:-build}"'

def cargo_src_configure(args: list[str] = []) -> str:
    """Configure Cargo/Rust project."""
    args_str = " ".join(args) if args else ""
    return '''
export CARGO_HOME="${{CARGO_HOME:-$PWD/.cargo}}"
mkdir -p "$CARGO_HOME"
# Configure offline mode if vendor dir exists
if [ -d vendor ]; then
    mkdir -p .cargo
    cat > .cargo/config.toml << 'CARGO_EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
CARGO_EOF
fi
{}
'''.format(args_str)

def cargo_src_compile(args: list[str] = []) -> str:
    """Build Cargo/Rust project."""
    args_str = " ".join(args) if args else ""
    return '''
cargo build --release \\
    --jobs ${{MAKEOPTS:-$(nproc)}} \\
    {}
'''.format(args_str)

def cargo_src_install(bins: list[str] = []) -> str:
    """Install Cargo/Rust binaries."""
    if bins:
        cmds = ['mkdir -p "$DESTDIR/usr/bin"']
        for b in bins:
            cmds.append('install -m 0755 "target/release/{}" "$DESTDIR/usr/bin/"'.format(b))
        return "\n".join(cmds)
    return '''
mkdir -p "$DESTDIR/usr/bin"
find target/release -maxdepth 1 -type f -executable ! -name "*.d" -exec install -m 0755 {{}} "$DESTDIR/usr/bin/" \\;
'''

def go_src_compile(packages: list[str] = ["."], ldflags: str = "") -> str:
    """Build Go project."""
    pkgs = " ".join(packages)
    return '''
export GOPATH="${{GOPATH:-$PWD/go}}"
export GOCACHE="${{GOCACHE:-$PWD/.cache/go-build}}"
export CGO_ENABLED="${{CGO_ENABLED:-1}}"
go build \\
    -v \\
    -ldflags="-s -w {ldflags}" \\
    -o "${{BUILD_DIR:-build}}/" \\
    {packages}
'''.format(ldflags = ldflags, packages = pkgs)

def go_src_install(bins: list[str] = []) -> str:
    """Install Go binaries."""
    if bins:
        cmds = ['mkdir -p "$DESTDIR/usr/bin"']
        for b in bins:
            cmds.append('install -m 0755 "${{BUILD_DIR:-build}}/{}" "$DESTDIR/usr/bin/"'.format(b))
        return "\n".join(cmds)
    return '''
mkdir -p "$DESTDIR/usr/bin"
find "${{BUILD_DIR:-build}}" -maxdepth 1 -type f -executable -exec install -m 0755 {{}} "$DESTDIR/usr/bin/" \\;
'''

def ninja_src_compile(args: list[str] = []) -> str:
    """Build with Ninja."""
    args_str = " ".join(args) if args else ""
    return 'ninja -C "${{BUILD_DIR:-build}}" -j${{MAKEOPTS:-$(nproc)}} {}'.format(args_str)

def ninja_src_install() -> str:
    """Install with Ninja."""
    return 'DESTDIR="$DESTDIR" ninja -C "${BUILD_DIR:-build}" install'

def python_src_install(python: str = "python3") -> str:
    """Install Python package."""
    return '''
{python} setup.py install \\
    --prefix=/usr \\
    --root="$DESTDIR" \\
    --optimize=1 \\
    --skip-build
'''.format(python = python)

def pip_src_install(python: str = "python3") -> str:
    """Install Python package with pip."""
    return '''
{python} -m pip install \\
    --prefix=/usr \\
    --root="$DESTDIR" \\
    --no-deps \\
    --no-build-isolation \\
    .
'''.format(python = python)

# -----------------------------------------------------------------------------
# VCS Source Helpers
# -----------------------------------------------------------------------------

def git_src_unpack(repo: str, branch: str = "main", depth: int = 1) -> str:
    """Clone git repository."""
    return '''
git clone \\
    --depth={depth} \\
    --branch={branch} \\
    "{repo}" \\
    "${{S:-source}}"
'''.format(repo = repo, branch = branch, depth = depth)

def git_src_prepare() -> str:
    """Prepare git source (submodules, etc.)."""
    return '''
cd "${S:-source}"
if [ -f .gitmodules ]; then
    git submodule update --init --recursive --depth=1
fi
'''

def svn_src_unpack(repo: str, revision: str = "HEAD") -> str:
    """Checkout SVN repository."""
    return '''
svn checkout \\
    -r {revision} \\
    "{repo}" \\
    "${{S:-source}}"
'''.format(repo = repo, revision = revision)

def hg_src_unpack(repo: str, branch: str = "default") -> str:
    """Clone Mercurial repository."""
    return '''
hg clone \\
    -b {branch} \\
    "{repo}" \\
    "${{S:-source}}"
'''.format(repo = repo, branch = branch)

# -----------------------------------------------------------------------------
# Test Helpers
# -----------------------------------------------------------------------------

def default_src_test() -> str:
    """Default test phase implementation."""
    return '''
if [ -f Makefile ] || [ -f GNUmakefile ] || [ -f makefile ]; then
    if make -q check 2>/dev/null; then
        emake check
    elif make -q test 2>/dev/null; then
        emake test
    fi
fi
'''

def python_test(args: list[str] = []) -> str:
    """Run Python tests with pytest."""
    args_str = " ".join(args) if args else ""
    return 'python3 -m pytest {} -v'.format(args_str)

def go_test(packages: list[str] = ["./..."]) -> str:
    """Run Go tests."""
    pkgs = " ".join(packages)
    return 'go test -v {}'.format(pkgs)

def cargo_test(args: list[str] = []) -> str:
    """Run Cargo tests."""
    args_str = " ".join(args) if args else ""
    return 'cargo test --release {}'.format(args_str)

# -----------------------------------------------------------------------------
# Environment Setup Helpers
# -----------------------------------------------------------------------------

def tc_export(vars: list[str] = ["CC", "CXX", "LD", "AR", "RANLIB", "NM"]) -> str:
    """Export toolchain variables."""
    exports = []
    for var in vars:
        if var == "CC":
            exports.append('export CC="${CC:-gcc}"')
        elif var == "CXX":
            exports.append('export CXX="${CXX:-g++}"')
        elif var == "LD":
            exports.append('export LD="${LD:-ld}"')
        elif var == "AR":
            exports.append('export AR="${AR:-ar}"')
        elif var == "RANLIB":
            exports.append('export RANLIB="${RANLIB:-ranlib}"')
        elif var == "NM":
            exports.append('export NM="${NM:-nm}"')
        elif var == "STRIP":
            exports.append('export STRIP="${STRIP:-strip}"')
        elif var == "OBJCOPY":
            exports.append('export OBJCOPY="${OBJCOPY:-objcopy}"')
        elif var == "PKG_CONFIG":
            exports.append('export PKG_CONFIG="${PKG_CONFIG:-pkg-config}"')
    return "\n".join(exports)

def append_cflags(flags: list[str]) -> str:
    """Append flags to CFLAGS."""
    return 'export CFLAGS="$CFLAGS {}"'.format(" ".join(flags))

def append_cxxflags(flags: list[str]) -> str:
    """Append flags to CXXFLAGS."""
    return 'export CXXFLAGS="$CXXFLAGS {}"'.format(" ".join(flags))

def append_ldflags(flags: list[str]) -> str:
    """Append flags to LDFLAGS."""
    return 'export LDFLAGS="$LDFLAGS {}"'.format(" ".join(flags))

def filter_flags(patterns: list[str]) -> str:
    """Remove flags matching patterns from CFLAGS/CXXFLAGS."""
    cmds = []
    for pat in patterns:
        cmds.append('CFLAGS=$(echo "$CFLAGS" | sed "s/{}//g")'.format(pat))
        cmds.append('CXXFLAGS=$(echo "$CXXFLAGS" | sed "s/{}//g")'.format(pat))
    return "\n".join(cmds)

def replace_flags(old: str, new: str) -> str:
    """Replace flag in CFLAGS/CXXFLAGS."""
    return '''
CFLAGS="${{CFLAGS//{old}/{new}}}"
CXXFLAGS="${{CXXFLAGS//{old}/{new}}}"
'''.format(old = old, new = new)

# -----------------------------------------------------------------------------
# Package Information Helpers
# -----------------------------------------------------------------------------

def get_version_component_range(component_range: str, version: str) -> str:
    """Extract version components (e.g., '1-2' from '1.2.3')."""
    return '''
_ver="{version}"
_range="{range}"
echo "$_ver" | cut -d. -f"$_range"
'''.format(version = version, range = component_range)

def get_major_version(version: str) -> str:
    """Get major version number."""
    return 'echo "{}" | cut -d. -f1'.format(version)

def get_minor_version(version: str) -> str:
    """Get minor version number (major.minor)."""
    return 'echo "{}" | cut -d. -f1-2'.format(version)

def ver_cut(range: str, version: str) -> str:
    """Cut version string by components."""
    return 'echo "{}" | cut -d. -f{}'.format(version, range)

def ver_rs(sep_from: str, sep_to: str, version: str) -> str:
    """Replace version separator."""
    return 'echo "{}" | sed "s/{}/${}$/g"'.format(version, sep_from, sep_to)

# -----------------------------------------------------------------------------
# Systemd Helpers
# -----------------------------------------------------------------------------

def systemd_dounit(files: list[str]) -> str:
    """Install systemd unit files."""
    cmds = ['mkdir -p "$DESTDIR/usr/lib/systemd/system"']
    for f in files:
        cmds.append('install -m 0644 "{}" "$DESTDIR/usr/lib/systemd/system/"'.format(f))
    return "\n".join(cmds)

def systemd_newunit(src: str, dst: str) -> str:
    """Install systemd unit file with new name."""
    return '''mkdir -p "$DESTDIR/usr/lib/systemd/system"
install -m 0644 "{}" "$DESTDIR/usr/lib/systemd/system/{}"'''.format(src, dst)

def systemd_douserunit(files: list[str]) -> str:
    """Install systemd user unit files."""
    cmds = ['mkdir -p "$DESTDIR/usr/lib/systemd/user"']
    for f in files:
        cmds.append('install -m 0644 "{}" "$DESTDIR/usr/lib/systemd/user/"'.format(f))
    return "\n".join(cmds)

def systemd_enable_service(service: str, target: str = "multi-user.target") -> str:
    """Create symlink to enable systemd service."""
    return '''mkdir -p "$DESTDIR/usr/lib/systemd/system/{target}.wants"
ln -sf "../{service}" "$DESTDIR/usr/lib/systemd/system/{target}.wants/{service}"
'''.format(service = service, target = target)

# -----------------------------------------------------------------------------
# OpenRC Helpers
# -----------------------------------------------------------------------------

def openrc_doinitd(files: list[str]) -> str:
    """Install OpenRC init scripts."""
    return doinitd(files)

def openrc_doconfd(files: list[str]) -> str:
    """Install OpenRC conf.d files."""
    return doconfd(files)

def newinitd(src: str, dst: str) -> str:
    """Install OpenRC init script with new name."""
    return '''mkdir -p "$DESTDIR/etc/init.d"
install -m 0755 "{}" "$DESTDIR/etc/init.d/{}"'''.format(src, dst)

def newconfd(src: str, dst: str) -> str:
    """Install conf.d file with new name."""
    return '''mkdir -p "$DESTDIR/etc/conf.d"
install -m 0644 "{}" "$DESTDIR/etc/conf.d/{}"'''.format(src, dst)

# -----------------------------------------------------------------------------
# Portage/Package Manager Helpers
# -----------------------------------------------------------------------------

def has_version(atom: str) -> str:
    """Check if package is installed (shell condition)."""
    # This would integrate with the package manager
    return '[ -n "$(find "${{EPREFIX:-}}/var/db/pkg" -maxdepth 2 -name "{}*" 2>/dev/null)" ]'.format(atom)

def best_version(atom: str) -> str:
    """Get best matching installed version."""
    return 'find "${EPREFIX:-}/var/db/pkg" -maxdepth 2 -name "{}*" -printf "%f\\n" 2>/dev/null | sort -V | tail -1'.format(atom)

# -----------------------------------------------------------------------------
# Ebuild Phase Package Rule
# -----------------------------------------------------------------------------

def _ebuild_package_impl(ctx: AnalysisContext) -> list[Provider]:
    """
    Build a package using ebuild-style phases:
    - src_unpack: Extract sources
    - src_prepare: Apply patches, run autoreconf
    - src_configure: Run configure/cmake/meson setup
    - src_compile: Build the software
    - src_test: Run tests (optional)
    - src_install: Install to DESTDIR
    """
    install_dir = ctx.actions.declare_output(ctx.attrs.name, dir = True)

    # Get source directory from dependency
    src_dir = ctx.attrs.source[DefaultInfo].default_outputs[0]

    # Build phases (use 'true' as no-op for empty phases to avoid syntax errors)
    src_unpack = ctx.attrs.src_unpack if ctx.attrs.src_unpack else "true"
    src_prepare = ctx.attrs.src_prepare if ctx.attrs.src_prepare else "true"
    pre_configure = ctx.attrs.pre_configure if ctx.attrs.pre_configure else "true"
    src_configure = ctx.attrs.src_configure if ctx.attrs.src_configure else "true"
    src_compile = ctx.attrs.src_compile if ctx.attrs.src_compile else "make -j$(nproc)"
    src_test = ctx.attrs.src_test if ctx.attrs.src_test else "true"
    src_install = ctx.attrs.src_install if ctx.attrs.src_install else "make install DESTDIR=\"$DESTDIR\""

    # Environment variables
    env_setup = []
    for k, v in ctx.attrs.env.items():
        env_setup.append('export {}="{}"'.format(k, v))
    env_str = "\n".join(env_setup)

    # USE flags
    use_flags = " ".join(ctx.attrs.use_flags) if ctx.attrs.use_flags else ""

    script = ctx.actions.write(
        "ebuild.sh",
        '''#!/bin/bash
set -e

# Package variables
export PN="{name}"
export PV="{version}"
export PACKAGE_NAME="{name}"
export CATEGORY="{category}"
export SLOT="{slot}"
export USE="{use_flags}"

# Installation directories
mkdir -p "$1"
export DESTDIR="$(cd "$1" && pwd)"
export S="$(cd "$2" && pwd)"
export EPREFIX="${{EPREFIX:-}}"
export PREFIX="${{PREFIX:-/usr}}"
export LIBDIR="${{LIBDIR:-lib64}}"
export LIBDIR_SUFFIX="${{LIBDIR_SUFFIX:-64}}"

# Build directories
export BUILD_DIR="${{BUILD_DIR:-$S/build}}"
export WORKDIR="$(dirname "$S")"
export T="$WORKDIR/temp"
export FILESDIR="${{FILESDIR:-}}"

mkdir -p "$T"

# Custom environment
{env}

# USE flag helper
use() {{
    [[ " $USE " == *" $1 "* ]]
}}

cd "$S"

# Phase: src_unpack (already done by download_source)
{src_unpack}

# Generate phases script
cat > "$T/phases.sh" << 'PHASES_EOF'
#!/bin/bash
set -e

# Variables will be inherited from parent environment
export PN='{name}'
export PV='{version}'
export PACKAGE_NAME='{name}'
export CATEGORY='{category}'
export SLOT='{slot}'
export USE='{use_flags}'

# These are passed via environment
cd "$S"

# Custom environment
{env}

# USE flag helper
use() {{
    [[ " $USE " == *" $1 "* ]]
}}

# Error handler for build phases
handle_phase_error() {{
    local phase=$1
    local exit_code=$2
    local log_file=$T/${{phase}}.log

    echo "" >&2
    echo "✗ Build phase $phase FAILED (exit code: $exit_code)" >&2
    echo "  Package: {name}-{version}" >&2
    echo "  Category: {category}" >&2
    echo "  Phase: $phase" >&2
    echo "  Working directory: $PWD" >&2
    echo "" >&2

    # Detect common error patterns (for automation)
    if [ -f "$log_file" ]; then
        echo "Analyzing error log..." >&2

        # Check for missing dependencies (pkg-config)
        if grep -q "Package .* was not found" "$log_file" 2>/dev/null; then
            echo "" >&2
            echo "DETECTED: Missing pkg-config dependencies" >&2
            grep "Package .* was not found" "$log_file" | while read line; do
                echo "  $line" >&2
            done
            echo "  Fix: Add missing dependencies to deps=[] in BUCK file" >&2
        fi

        # Check for CMake compatibility errors
        if grep -q "Compatibility with CMake" "$log_file" 2>/dev/null; then
            echo "" >&2
            echo "DETECTED: CMake compatibility issue" >&2
            echo "  Fix: Add -DCMAKE_MINIMUM_REQUIRED_VERSION=3.5 to cmake_args" >&2
        fi

        # Check for Meson unknown options
        if grep -q "ERROR: Unknown options" "$log_file" 2>/dev/null; then
            echo "" >&2
            echo "DETECTED: Meson unknown options" >&2
            grep "ERROR: Unknown options" "$log_file" | while read line; do
                echo "  $line" >&2
            done
            echo "  Fix: Remove obsolete options from meson_args in BUCK file" >&2
        fi

        # Check for Meson boolean format errors
        if grep -q "not one of the choices.*enabled.*disabled" "$log_file" 2>/dev/null; then
            echo "" >&2
            echo "DETECTED: Meson boolean format error (Meson 1.0+)" >&2
            echo "  Fix: Replace true/false with enabled/disabled/auto in meson_args" >&2
        fi
    fi

    echo "" >&2
    echo "Common fixes for $phase:" >&2
    case "$phase" in
        src_configure)
            echo "  - Check if all dependencies are installed" >&2
            echo "  - Review configure_args in BUCK file" >&2
            echo "  - For CMake: Check cmake_args" >&2
            echo "  - For Meson: Ensure options use enabled/disabled/auto format" >&2
            ;;
        src_compile)
            echo "  - Check for missing build dependencies" >&2
            echo "  - Review compiler errors in build log" >&2
            echo "  - May need additional USE flags or dependencies" >&2
            ;;
        src_install)
            echo "  - Check if DESTDIR is respected" >&2
            echo "  - Review install paths in configure_args" >&2
            ;;
    esac
    exit $exit_code
}}

echo "📦 Phase: src_prepare"
if ! ( {src_prepare} ) 2>&1 | tee "$T/src_prepare.log"; then
    handle_phase_error "src_prepare" ${{PIPESTATUS[0]}}
fi

echo "📦 Phase: pre_configure"
if ! ( {pre_configure} ) 2>&1 | tee "$T/pre_configure.log"; then
    handle_phase_error "pre_configure" ${{PIPESTATUS[0]}}
fi

echo "📦 Phase: src_configure"
if ! ( {src_configure} ) 2>&1 | tee "$T/src_configure.log"; then
    handle_phase_error "src_configure" ${{PIPESTATUS[0]}}
fi

echo "📦 Phase: src_compile"
if ! ( {src_compile} ) 2>&1 | tee "$T/src_compile.log"; then
    handle_phase_error "src_compile" ${{PIPESTATUS[0]}}
fi

echo "📦 Phase: src_test"
if [ -n "{run_tests}" ]; then
    if ! ( {src_test} ) 2>&1 | tee "$T/src_test.log"; then
        handle_phase_error "src_test" ${{PIPESTATUS[0]}}
    fi
fi

echo "📦 Phase: src_install"
if ! ( {src_install} ) 2>&1 | tee "$T/src_install.log"; then
    handle_phase_error "src_install" ${{PIPESTATUS[0]}}
fi
PHASES_EOF

# Make phases script executable
chmod +x "$T/phases.sh"

# Run phases with network isolation
if command -v unshare >/dev/null 2>&1 && unshare --net true 2>/dev/null; then
    echo "🔒 Running build phases in network-isolated environment (no internet access)"
    DESTDIR="$DESTDIR" S="$S" EPREFIX="$EPREFIX" PREFIX="$PREFIX" LIBDIR="$LIBDIR" LIBDIR_SUFFIX="$LIBDIR_SUFFIX" BUILD_DIR="$BUILD_DIR" WORKDIR="$WORKDIR" T="$T" FILESDIR="$FILESDIR" unshare --net -- "$T/phases.sh"
else
    echo "⚠ Warning: unshare not available or insufficient permissions, building without network isolation"
    DESTDIR="$DESTDIR" S="$S" EPREFIX="$EPREFIX" PREFIX="$PREFIX" LIBDIR="$LIBDIR" LIBDIR_SUFFIX="$LIBDIR_SUFFIX" BUILD_DIR="$BUILD_DIR" WORKDIR="$WORKDIR" T="$T" FILESDIR="$FILESDIR" "$T/phases.sh"
fi
'''.format(
            name = ctx.attrs.name,
            version = ctx.attrs.version,
            category = ctx.attrs.category,
            slot = ctx.attrs.slot,
            use_flags = use_flags,
            env = env_str,
            src_unpack = src_unpack,
            src_prepare = src_prepare,
            pre_configure = pre_configure,
            src_configure = src_configure,
            src_compile = src_compile,
            src_test = src_test,
            src_install = src_install,
            run_tests = "yes" if ctx.attrs.run_tests else "",
        ),
    )

    ctx.actions.run(
        cmd_args([
            "bash",
            script,
            install_dir.as_output(),
            src_dir,
        ]),
        category = "ebuild",
        identifier = ctx.attrs.name,
    )

    return [
        DefaultInfo(default_output = install_dir),
        PackageInfo(
            name = ctx.attrs.name,
            version = ctx.attrs.version,
            description = ctx.attrs.description,
            homepage = ctx.attrs.homepage,
            license = ctx.attrs.license,
            src_uri = "",
            checksum = "",
            dependencies = ctx.attrs.rdepend,
            build_dependencies = ctx.attrs.bdepend,
            maintainers = ctx.attrs.maintainers,
        ),
    ]

ebuild_package = rule(
    impl = _ebuild_package_impl,
    attrs = {
        "source": attrs.dep(),
        "version": attrs.string(),
        "category": attrs.string(default = ""),
        "slot": attrs.string(default = "0"),
        "description": attrs.string(default = ""),
        "homepage": attrs.string(default = ""),
        "license": attrs.string(default = ""),
        "use_flags": attrs.list(attrs.string(), default = []),
        "src_unpack": attrs.string(default = ""),
        "src_prepare": attrs.string(default = ""),
        "pre_configure": attrs.string(default = ""),
        "src_configure": attrs.string(default = ""),
        "src_compile": attrs.string(default = ""),
        "src_test": attrs.string(default = ""),
        "src_install": attrs.string(default = ""),
        "run_tests": attrs.bool(default = False),
        "env": attrs.dict(attrs.string(), attrs.string(), default = {}),
        "depend": attrs.list(attrs.dep(), default = []),
        "rdepend": attrs.list(attrs.dep(), default = []),
        "bdepend": attrs.list(attrs.dep(), default = []),
        "pdepend": attrs.list(attrs.dep(), default = []),
        "maintainers": attrs.list(attrs.string(), default = []),
    },
)

# -----------------------------------------------------------------------------
# Convenience Macros
# -----------------------------------------------------------------------------

def simple_package(
        name: str,
        version: str,
        src_uri: str,
        sha256: str,
        configure_args: list[str] = [],
        make_args: list[str] = [],
        deps: list[str] = [],
        maintainers: list[str] = [],
        signature_uri: str | None = None,
        gpg_key: str | None = None,
        gpg_keyring: str | None = None,
        auto_detect_signature: bool = True,
        exclude_patterns: list[str] = [],
        **kwargs):
    """
    Convenience macro for standard autotools packages without USE flags.
    This is a simplified wrapper around autotools_package() for basic packages.

    Args:
        signature_uri: Optional URL to GPG signature file (.asc or .sig)
        gpg_key: Optional GPG key ID or fingerprint to import and verify against
        gpg_keyring: Optional path to GPG keyring file with trusted keys
        auto_detect_signature: Auto-detect signature files (.asc, .sig, .sign) (default: True)
        exclude_patterns: List of patterns to exclude from source extraction (passed to tar --exclude)
    """
    # Forward to autotools_package() which supports both USE flags and simple builds
    autotools_package(
        name = name,
        version = version,
        src_uri = src_uri,
        sha256 = sha256,
        configure_args = configure_args,
        make_args = make_args,
        deps = deps,
        maintainers = maintainers,
        signature_uri = signature_uri,
        gpg_key = gpg_key,
        gpg_keyring = gpg_keyring,
        auto_detect_signature = auto_detect_signature,
        exclude_patterns = exclude_patterns,
        **kwargs
    )

def cmake_package(
        name: str,
        version: str,
        src_uri: str | None = None,
        sha256: str | None = None,
        source: str | None = None,
        cmake_args: list[str] = [],
        pre_configure: str = "",
        deps: list[str] = [],
        maintainers: list[str] = [],
        # USE flag support
        iuse: list[str] = [],
        use_defaults: list[str] = [],
        use_options: dict = {},
        use_deps: dict = {},
        global_use: dict | None = None,
        package_overrides: dict | None = None,
        signature_uri: str | None = None,
        gpg_key: str | None = None,
        gpg_keyring: str | None = None,
        auto_detect_signature: bool = True,
        exclude_patterns: list[str] = [],
        **kwargs):
    """
    Convenience macro for CMake packages with USE flag support.
    Uses the cmake eclass for standardized build phases.

    Args:
        name: Package name
        version: Package version
        src_uri: Source download URL
        sha256: Source checksum
        cmake_args: Base CMake arguments
        pre_configure: Pre-configure script
        deps: Base dependencies (always applied)
        maintainers: Package maintainers
        iuse: List of USE flags this package supports
        use_defaults: Default enabled USE flags
        use_options: Dict mapping USE flag to CMake option(s)
                     Example: {"ssl": "ENABLE_SSL", "tests": "BUILD_TESTING"}
        use_deps: Dict mapping USE flag to conditional dependencies
        global_use: Global USE flag configuration
        package_overrides: Package-specific USE overrides
        signature_uri: Optional URL to GPG signature file (.asc or .sig)
        gpg_key: Optional GPG key ID or fingerprint to import and verify against
        gpg_keyring: Optional path to GPG keyring file with trusted keys
        auto_detect_signature: Auto-detect signature files (.asc, .sig, .sign) (default: True)
        exclude_patterns: List of patterns to exclude from source extraction (passed to tar --exclude)

    Example:
        cmake_package(
            name = "libfoo",
            version = "1.2.3",
            src_uri = "https://example.com/libfoo-1.2.3.tar.gz",
            sha256 = "...",
            iuse = ["ssl", "tests", "doc"],
            use_defaults = ["ssl"],
            use_options = {
                "ssl": "ENABLE_SSL",
                "tests": "BUILD_TESTING",
                "doc": "BUILD_DOCUMENTATION",
            },
            use_deps = {
                "ssl": ["//packages/linux/dev-libs/openssl"],
            },
        )
    """
    # Handle source - either use provided source or create one from src_uri
    if source:
        src_target = source
    else:
        if not src_uri or not sha256:
            fail("Either 'source' or both 'src_uri' and 'sha256' must be provided")
        src_name = name + "-src"
        download_source(
            name = src_name,
            src_uri = src_uri,
            sha256 = sha256,
            signature_uri = signature_uri,
            gpg_key = gpg_key,
            gpg_keyring = gpg_keyring,
            auto_detect_signature = auto_detect_signature,
            exclude_patterns = exclude_patterns,
        )
        src_target = ":" + src_name

    # Calculate effective USE flags if USE flags are specified
    effective_use = []
    resolved_deps = list(deps)
    resolved_cmake_args = list(cmake_args)

    if iuse:
        effective_use = get_effective_use(
            name,
            iuse,
            use_defaults,
            global_use,
            package_overrides,
        )

        # Resolve conditional dependencies
        resolved_deps.extend(use_dep(use_deps, effective_use))

        # Generate CMake options based on USE flags
        if use_options:
            cmake_opts = use_cmake_options(use_options, effective_use)
            resolved_cmake_args.extend(cmake_opts)

    # Use eclass inheritance for cmake
    eclass_config = inherit(["cmake"])

    # Handle cmake_args by setting environment variable
    env = kwargs.pop("env", {})
    if resolved_cmake_args:
        env["CMAKE_EXTRA_ARGS"] = " ".join(resolved_cmake_args)

    # Merge eclass bdepend with any existing bdepend
    bdepend = list(kwargs.pop("bdepend", []))
    for dep in eclass_config["bdepend"]:
        if dep not in bdepend:
            bdepend.append(dep)

    ebuild_package(
        name = name,
        source = src_target,
        version = version,
        pre_configure = pre_configure,
        src_configure = eclass_config["src_configure"],
        src_compile = eclass_config["src_compile"],
        src_install = eclass_config["src_install"],
        rdepend = resolved_deps,
        bdepend = bdepend,
        env = env,
        maintainers = maintainers,
        use_flags = effective_use,
        **kwargs
    )

def meson_package(
        name: str,
        version: str,
        src_uri: str | None = None,
        sha256: str | None = None,
        source: str | None = None,
        meson_args: list[str] = [],
        deps: list[str] = [],
        maintainers: list[str] = [],
        # USE flag support
        iuse: list[str] = [],
        use_defaults: list[str] = [],
        use_options: dict = {},
        use_deps: dict = {},
        global_use: dict | None = None,
        package_overrides: dict | None = None,
        signature_uri: str | None = None,
        gpg_key: str | None = None,
        gpg_keyring: str | None = None,
        auto_detect_signature: bool = True,
        exclude_patterns: list[str] = [],
        **kwargs):
    """
    Convenience macro for Meson packages with USE flag support.
    Uses the meson eclass for standardized build phases.

    Args:
        name: Package name
        version: Package version
        src_uri: Source download URL
        sha256: Source checksum
        meson_args: Base Meson arguments
        deps: Base dependencies (always applied)
        maintainers: Package maintainers
        iuse: List of USE flags this package supports
        use_defaults: Default enabled USE flags
        use_options: Dict mapping USE flag to Meson option(s)
                     Example: {"ssl": "ssl", "tests": "tests"}
        use_deps: Dict mapping USE flag to conditional dependencies
        global_use: Global USE flag configuration
        package_overrides: Package-specific USE overrides
        signature_uri: Optional URL to GPG signature file (.asc or .sig)
        gpg_key: Optional GPG key ID or fingerprint to import and verify against
        gpg_keyring: Optional path to GPG keyring file with trusted keys
        auto_detect_signature: Auto-detect signature files (.asc, .sig, .sign) (default: True)
        exclude_patterns: List of patterns to exclude from source extraction (passed to tar --exclude)

    Example:
        meson_package(
            name = "libbar",
            version = "2.3.4",
            src_uri = "https://example.com/libbar-2.3.4.tar.xz",
            sha256 = "...",
            iuse = ["ssl", "tests", "doc"],
            use_defaults = ["ssl"],
            use_options = {
                "ssl": "ssl",
                "tests": "tests",
                "doc": "docs",
            },
            use_deps = {
                "ssl": ["//packages/linux/dev-libs/openssl"],
            },
        )
    """
    # Handle source - either use provided source or create one from src_uri
    if source:
        src_target = source
    else:
        if not src_uri or not sha256:
            fail("Either 'source' or both 'src_uri' and 'sha256' must be provided")
        src_name = name + "-src"
        download_source(
            name = src_name,
            src_uri = src_uri,
            sha256 = sha256,
            signature_uri = signature_uri,
            gpg_key = gpg_key,
            gpg_keyring = gpg_keyring,
            auto_detect_signature = auto_detect_signature,
            exclude_patterns = exclude_patterns,
        )
        src_target = ":" + src_name

    # Calculate effective USE flags if USE flags are specified
    effective_use = []
    resolved_deps = list(deps)
    resolved_meson_args = list(meson_args)

    if iuse:
        effective_use = get_effective_use(
            name,
            iuse,
            use_defaults,
            global_use,
            package_overrides,
        )

        # Resolve conditional dependencies
        resolved_deps.extend(use_dep(use_deps, effective_use))

        # Generate Meson options based on USE flags
        if use_options:
            meson_opts = use_meson_options(use_options, effective_use)
            resolved_meson_args.extend(meson_opts)

    # Use eclass inheritance for meson
    eclass_config = inherit(["meson"])

    # Handle meson_args by setting environment variable
    env = kwargs.pop("env", {})
    if resolved_meson_args:
        env["MESON_EXTRA_ARGS"] = " ".join(resolved_meson_args)

    # Merge eclass bdepend with any existing bdepend
    bdepend = list(kwargs.pop("bdepend", []))
    for dep in eclass_config["bdepend"]:
        if dep not in bdepend:
            bdepend.append(dep)

    ebuild_package(
        name = name,
        source = src_target,
        version = version,
        src_configure = eclass_config["src_configure"],
        src_compile = eclass_config["src_compile"],
        src_install = eclass_config["src_install"],
        rdepend = resolved_deps,
        bdepend = bdepend,
        env = env,
        maintainers = maintainers,
        use_flags = effective_use,
        **kwargs
    )

def autotools_package(
        name: str,
        version: str,
        src_uri: str | None = None,
        sha256: str | None = None,
        source: str | None = None,
        configure_args: list[str] = [],
        make_args: list[str] = [],
        deps: list[str] = [],
        maintainers: list[str] = [],
        # USE flag support
        iuse: list[str] = [],
        use_defaults: list[str] = [],
        use_configure: dict = {},
        use_deps: dict = {},
        global_use: dict | None = None,
        package_overrides: dict | None = None,
        signature_uri: str | None = None,
        gpg_key: str | None = None,
        gpg_keyring: str | None = None,
        auto_detect_signature: bool = True,
        exclude_patterns: list[str] = [],
        **kwargs):
    """
    Convenience macro for autotools packages with USE flag support.
    Uses the autotools eclass for standardized build phases.

    This replaces both configure_make_package() and use_package() with a
    unified interface consistent with all other language package types.

    Args:
        name: Package name
        version: Package version
        src_uri: Source download URL (required if source not provided)
        sha256: Source checksum (required if source not provided)
        source: Pre-defined source target (alternative to src_uri/sha256)
        configure_args: Base configure arguments
        make_args: Make arguments
        deps: Base dependencies (always applied)
        maintainers: Package maintainers
        iuse: List of USE flags this package supports
        use_defaults: Default enabled USE flags
        use_configure: Dict mapping USE flag to configure argument(s)
                       Example: {"ssl": "--with-ssl", "-ssl": "--without-ssl"}
        use_deps: Dict mapping USE flag to conditional dependencies
        global_use: Global USE flag configuration
        package_overrides: Package-specific USE overrides
        signature_uri: Optional URL to GPG signature file (.asc or .sig)
        gpg_key: Optional GPG key ID or fingerprint to import and verify against
        gpg_keyring: Optional path to GPG keyring file with trusted keys
        auto_detect_signature: Auto-detect signature files (.asc, .sig, .sign) (default: True)
        exclude_patterns: List of patterns to exclude from source extraction (passed to tar --exclude)

    Example:
        autotools_package(
            name = "curl",
            version = "8.5.0",
            src_uri = "https://curl.se/download/curl-8.5.0.tar.xz",
            sha256 = "...",
            iuse = ["ssl", "http2", "ipv6"],
            use_defaults = ["ssl", "ipv6"],
            use_configure = {
                "ssl": "--with-ssl",
                "-ssl": "--without-ssl",
                "http2": "--with-nghttp2",
                "ipv6": "--enable-ipv6",
                "-ipv6": "--disable-ipv6",
            },
            use_deps = {
                "ssl": ["//packages/linux/dev-libs/openssl"],
                "http2": ["//packages/linux/net-libs/nghttp2"],
            },
        )
    """
    # Handle source - either use provided source or create one from src_uri
    if source:
        src_target = source
    else:
        if not src_uri or not sha256:
            fail("Either 'source' or both 'src_uri' and 'sha256' must be provided")
        src_name = name + "-src"
        download_source(
            name = src_name,
            src_uri = src_uri,
            sha256 = sha256,
            signature_uri = signature_uri,
            gpg_key = gpg_key,
            gpg_keyring = gpg_keyring,
            auto_detect_signature = auto_detect_signature,
            exclude_patterns = exclude_patterns,
        )
        src_target = ":" + src_name

    # Calculate effective USE flags if USE flags are specified
    effective_use = []
    resolved_deps = list(deps)
    resolved_configure_args = list(configure_args)

    if iuse:
        effective_use = get_effective_use(
            name,
            iuse,
            use_defaults,
            global_use,
            package_overrides,
        )

        # Resolve conditional dependencies
        resolved_deps.extend(use_dep(use_deps, effective_use))

        # Generate configure arguments based on USE flags
        if use_configure:
            config_args = use_configure_args(use_configure, effective_use)
            resolved_configure_args.extend(config_args)

    # Use eclass inheritance for autotools
    eclass_config = inherit(["autotools"])

    # Handle configure and make args by setting environment variables
    env = kwargs.pop("env", {})
    if resolved_configure_args:
        env["EXTRA_ECONF"] = " ".join(resolved_configure_args)
    if make_args:
        env["EXTRA_EMAKE"] = " ".join(make_args)

    # Merge eclass bdepend with any existing bdepend
    bdepend = list(kwargs.pop("bdepend", []))
    for dep in eclass_config["bdepend"]:
        if dep not in bdepend:
            bdepend.append(dep)

    # Get pre_configure and post_install if provided
    pre_configure = kwargs.pop("pre_configure", "")
    post_install = kwargs.pop("post_install", "")

    # Allow overriding eclass phases for non-autotools packages
    custom_src_configure = kwargs.pop("src_configure", None)
    custom_src_compile = kwargs.pop("src_compile", None)
    custom_src_install = kwargs.pop("src_install", None)

    # Combine with eclass phases
    src_prepare = eclass_config.get("src_prepare", "")
    if pre_configure:
        src_prepare += "\n" + pre_configure

    # Use custom phases if provided, otherwise use eclass defaults
    src_configure = custom_src_configure if custom_src_configure else eclass_config["src_configure"]
    src_compile = custom_src_compile if custom_src_compile else eclass_config["src_compile"]

    # For src_install, always append post_install if provided (whether using custom or eclass)
    src_install = custom_src_install if custom_src_install else eclass_config["src_install"]
    if post_install:
        src_install += "\n" + post_install

    ebuild_package(
        name = name,
        source = src_target,
        version = version,
        src_prepare = src_prepare,
        src_configure = src_configure,
        src_compile = src_compile,
        src_install = src_install,
        rdepend = resolved_deps,
        bdepend = bdepend,
        env = env,
        maintainers = maintainers,
        use_flags = effective_use,
        **kwargs
    )

def cargo_package(
        name: str,
        version: str,
        src_uri: str,
        sha256: str,
        bins: list[str] = [],
        cargo_args: list[str] = [],
        deps: list[str] = [],
        maintainers: list[str] = [],
        # USE flag support
        iuse: list[str] = [],
        use_defaults: list[str] = [],
        use_features: dict = {},
        use_deps: dict = {},
        global_use: dict | None = None,
        package_overrides: dict | None = None,
        signature_uri: str | None = None,
        gpg_key: str | None = None,
        gpg_keyring: str | None = None,
        auto_detect_signature: bool = True,
        exclude_patterns: list[str] = [],
        **kwargs):
    """
    Convenience macro for Rust/Cargo packages with USE flag support.
    Uses the cargo eclass for standardized build phases.

    Args:
        name: Package name
        version: Package version
        src_uri: Source download URL
        sha256: Source checksum
        bins: Binary names to install
        cargo_args: Base Cargo arguments
        deps: Base dependencies (always applied)
        maintainers: Package maintainers
        iuse: List of USE flags this package supports
        use_defaults: Default enabled USE flags
        use_features: Dict mapping USE flag to Cargo feature(s)
                      Example: {"ssl": "tls", "compression": ["zstd", "brotli"]}
        use_deps: Dict mapping USE flag to conditional dependencies
        global_use: Global USE flag configuration
        package_overrides: Package-specific USE overrides
        signature_uri: Optional URL to GPG signature file (.asc or .sig)
        gpg_key: Optional GPG key ID or fingerprint to import and verify against
        gpg_keyring: Optional path to GPG keyring file with trusted keys
        auto_detect_signature: Auto-detect signature files (.asc, .sig, .sign) (default: True)
        exclude_patterns: List of patterns to exclude from source extraction (passed to tar --exclude)

    Example:
        cargo_package(
            name = "ripgrep",
            version = "14.0.0",
            src_uri = "https://github.com/BurntSushi/ripgrep/archive/14.0.0.tar.gz",
            sha256 = "...",
            iuse = ["pcre2", "simd"],
            use_defaults = ["simd"],
            use_features = {
                "pcre2": "pcre2",
                "simd": "simd-accel",
            },
            use_deps = {
                "pcre2": ["//packages/linux/dev-libs/pcre2"],
            },
        )
    """
    src_name = name + "-src"

    download_source(
        name = src_name,
        src_uri = src_uri,
        sha256 = sha256,
        signature_uri = signature_uri,
        gpg_key = gpg_key,
        gpg_keyring = gpg_keyring,
        auto_detect_signature = auto_detect_signature,
        exclude_patterns = exclude_patterns,
    )

    # Calculate effective USE flags if USE flags are specified
    effective_use = []
    resolved_deps = list(deps)
    resolved_cargo_args = list(cargo_args)

    if iuse:
        effective_use = get_effective_use(
            name,
            iuse,
            use_defaults,
            global_use,
            package_overrides,
        )

        # Resolve conditional dependencies
        resolved_deps.extend(use_dep(use_deps, effective_use))

        # Generate Cargo arguments with features
        if use_features:
            resolved_cargo_args = use_cargo_args(use_features, effective_use, cargo_args)

    # Use eclass inheritance for cargo
    eclass_config = inherit(["cargo"])

    # Handle cargo_args by setting environment variable
    env = kwargs.pop("env", {})
    if resolved_cargo_args:
        env["CARGO_BUILD_FLAGS"] = " ".join(resolved_cargo_args)

    # Merge eclass bdepend with any existing bdepend
    bdepend = list(kwargs.pop("bdepend", []))
    for dep in eclass_config["bdepend"]:
        if dep not in bdepend:
            bdepend.append(dep)

    # Filter out rdepend from kwargs since we pass it explicitly as deps
    kwargs.pop("rdepend", None)

    # Use custom install if bins specified, otherwise use eclass default
    src_install = cargo_src_install(bins) if bins else eclass_config["src_install"]

    ebuild_package(
        name = name,
        source = ":" + src_name,
        version = version,
        src_configure = eclass_config["src_configure"],
        src_compile = eclass_config["src_compile"],
        src_install = src_install,
        rdepend = resolved_deps,
        bdepend = bdepend,
        env = env,
        maintainers = maintainers,
        use_flags = effective_use,
        **kwargs
    )

def go_package(
        name: str,
        version: str,
        src_uri: str,
        sha256: str,
        bins: list[str] = [],
        packages: list[str] = ["."],
        deps: list[str] = [],
        maintainers: list[str] = [],
        # USE flag support
        iuse: list[str] = [],
        use_defaults: list[str] = [],
        use_tags: dict = {},
        use_deps: dict = {},
        global_use: dict | None = None,
        package_overrides: dict | None = None,
        signature_uri: str | None = None,
        gpg_key: str | None = None,
        gpg_keyring: str | None = None,
        auto_detect_signature: bool = True,
        exclude_patterns: list[str] = [],
        **kwargs):
    """
    Convenience macro for Go packages with USE flag support.
    Uses the go-module eclass for standardized build phases.

    Args:
        name: Package name
        version: Package version
        src_uri: Source download URL
        sha256: Source checksum
        bins: Binary names to install
        packages: Go packages to build
        deps: Base dependencies (always applied)
        maintainers: Package maintainers
        iuse: List of USE flags this package supports
        use_defaults: Default enabled USE flags
        use_tags: Dict mapping USE flag to Go build tag(s)
                  Example: {"sqlite": "sqlite", "postgres": "postgres"}
        use_deps: Dict mapping USE flag to conditional dependencies
        global_use: Global USE flag configuration
        package_overrides: Package-specific USE overrides
        signature_uri: Optional URL to GPG signature file (.asc or .sig)
        gpg_key: Optional GPG key ID or fingerprint to import and verify against
        gpg_keyring: Optional path to GPG keyring file with trusted keys
        auto_detect_signature: Auto-detect signature files (.asc, .sig, .sign) (default: True)
        exclude_patterns: List of patterns to exclude from source extraction (passed to tar --exclude)

    Example:
        go_package(
            name = "go-sqlite3",
            version = "1.14.18",
            src_uri = "https://github.com/mattn/go-sqlite3/archive/v1.14.18.tar.gz",
            sha256 = "...",
            iuse = ["icu", "json1", "fts5"],
            use_defaults = ["json1"],
            use_tags = {
                "icu": "icu",
                "json1": "json1",
                "fts5": "fts5",
            },
            use_deps = {
                "icu": ["//packages/linux/dev-libs/icu"],
            },
        )
    """
    src_name = name + "-src"

    download_source(
        name = src_name,
        src_uri = src_uri,
        sha256 = sha256,
        signature_uri = signature_uri,
        gpg_key = gpg_key,
        gpg_keyring = gpg_keyring,
        auto_detect_signature = auto_detect_signature,
        exclude_patterns = exclude_patterns,
    )

    # Calculate effective USE flags if USE flags are specified
    effective_use = []
    resolved_deps = list(deps)
    resolved_go_build_args = kwargs.pop("go_build_args", [])

    if iuse:
        effective_use = get_effective_use(
            name,
            iuse,
            use_defaults,
            global_use,
            package_overrides,
        )

        # Resolve conditional dependencies
        resolved_deps.extend(use_dep(use_deps, effective_use))

        # Generate Go build arguments with tags
        if use_tags:
            resolved_go_build_args = use_go_build_args(use_tags, effective_use, resolved_go_build_args)

    # Use eclass inheritance for go-module
    eclass_config = inherit(["go-module"])

    # Handle packages by setting environment variable
    env = kwargs.pop("env", {})
    if packages != ["."]:
        env["GO_PACKAGES"] = " ".join(packages)

    # Handle go_build_args
    if resolved_go_build_args:
        env["GO_BUILD_FLAGS"] = " ".join(resolved_go_build_args)

    # Merge eclass bdepend with any existing bdepend
    bdepend = list(kwargs.pop("bdepend", []))
    for dep in eclass_config["bdepend"]:
        if dep not in bdepend:
            bdepend.append(dep)

    # Use custom install if bins specified, otherwise use eclass default
    src_install = go_src_install(bins) if bins else eclass_config["src_install"]

    ebuild_package(
        name = name,
        source = ":" + src_name,
        version = version,
        src_configure = eclass_config["src_configure"],
        src_compile = eclass_config["src_compile"],
        src_install = src_install,
        rdepend = resolved_deps,
        bdepend = bdepend,
        env = env,
        maintainers = maintainers,
        use_flags = effective_use,
        **kwargs
    )

def python_package(
        name: str,
        version: str,
        src_uri: str,
        sha256: str,
        python: str = "python3",
        deps: list[str] = [],
        maintainers: list[str] = [],
        # USE flag support
        iuse: list[str] = [],
        use_defaults: list[str] = [],
        use_extras: dict = {},
        use_deps: dict = {},
        global_use: dict | None = None,
        package_overrides: dict | None = None,
        signature_uri: str | None = None,
        gpg_key: str | None = None,
        gpg_keyring: str | None = None,
        auto_detect_signature: bool = True,
        exclude_patterns: list[str] = [],
        **kwargs):
    """
    Convenience macro for Python packages with USE flag support.
    Uses the python-single-r1 eclass for standardized build phases.

    Args:
        name: Package name
        version: Package version
        src_uri: Source download URL
        sha256: Source checksum
        python: Python interpreter (default: python3)
        deps: Base dependencies (always applied)
        maintainers: Package maintainers
        iuse: List of USE flags this package supports
        use_defaults: Default enabled USE flags
        use_extras: Dict mapping USE flag to Python extras
                    Example: {"ssl": "ssl", "http2": "http2"}
        use_deps: Dict mapping USE flag to conditional dependencies
        global_use: Global USE flag configuration
        package_overrides: Package-specific USE overrides
        signature_uri: Optional URL to GPG signature file (.asc or .sig)
        gpg_key: Optional GPG key ID or fingerprint to import and verify against
        gpg_keyring: Optional path to GPG keyring file with trusted keys
        auto_detect_signature: Auto-detect signature files (.asc, .sig, .sign) (default: True)
        exclude_patterns: List of patterns to exclude from source extraction (passed to tar --exclude)

    Example:
        python_package(
            name = "requests",
            version = "2.31.0",
            src_uri = "https://github.com/psf/requests/archive/v2.31.0.tar.gz",
            sha256 = "...",
            iuse = ["socks", "security"],
            use_defaults = ["security"],
            use_extras = {
                "socks": "socks",
                "security": "security",
            },
            use_deps = {
                "socks": ["//packages/linux/dev-python/pysocks"],
            },
        )
    """
    src_name = name + "-src"

    download_source(
        name = src_name,
        src_uri = src_uri,
        sha256 = sha256,
        signature_uri = signature_uri,
        gpg_key = gpg_key,
        gpg_keyring = gpg_keyring,
        auto_detect_signature = auto_detect_signature,
        exclude_patterns = exclude_patterns,
    )

    # Calculate effective USE flags if USE flags are specified
    effective_use = []
    resolved_deps = list(deps)
    extras = []

    if iuse:
        effective_use = get_effective_use(
            name,
            iuse,
            use_defaults,
            global_use,
            package_overrides,
        )

        # Resolve conditional dependencies
        resolved_deps.extend(use_dep(use_deps, effective_use))

        # Collect Python extras based on USE flags
        enabled_set = set(effective_use)
        for flag, extra_name in use_extras.items():
            if flag in enabled_set:
                if isinstance(extra_name, list):
                    extras.extend(extra_name)
                else:
                    extras.append(extra_name)

    # Use eclass inheritance for python-single-r1
    eclass_config = inherit(["python-single-r1"])

    # Handle python version by setting environment variable
    env = kwargs.pop("env", {})
    if python != "python3":
        env["PYTHON"] = python

    # Set extras if any are enabled
    if extras:
        env["PYTHON_EXTRAS"] = ",".join(extras)

    # Merge eclass bdepend with any existing bdepend
    bdepend = list(kwargs.pop("bdepend", []))
    for dep in eclass_config["bdepend"]:
        if dep not in bdepend:
            bdepend.append(dep)

    # Merge eclass rdepend with resolved dependencies
    rdepend = resolved_deps
    for dep in eclass_config.get("rdepend", []):
        if dep not in rdepend:
            rdepend.append(dep)

    # Filter out python-specific parameters that ebuild_package doesn't accept
    filtered_kwargs = dict(kwargs)
    filtered_kwargs.pop("python_deps", None)
    filtered_kwargs.pop("extras", None)
    filtered_kwargs.pop("build_deps", None)

    ebuild_package(
        name = name,
        source = ":" + src_name,
        version = version,
        src_configure = eclass_config["src_configure"],
        src_compile = eclass_config["src_compile"],
        src_install = eclass_config["src_install"],
        rdepend = rdepend,
        bdepend = bdepend,
        env = env,
        maintainers = maintainers,
        use_flags = effective_use,
        **filtered_kwargs
    )

# -----------------------------------------------------------------------------
# Binary Package Helper Functions
# -----------------------------------------------------------------------------

def binary_install_bins(bins: list[str], src_dir: str = "$SRCS") -> str:
    """
    Helper to install binary executables from source directory to /usr/bin.

    Usage in install_script:
        install_script = binary_install_bins(["myapp", "mytool"])
    """
    cmds = ['mkdir -p "$OUT/usr/bin"']
    for b in bins:
        cmds.append('install -m 0755 "{}/{}" "$OUT/usr/bin/"'.format(src_dir, b))
    return "\n".join(cmds)

def binary_install_libs(libs: list[str], src_dir: str = "$SRCS") -> str:
    """
    Helper to install shared libraries from source directory to /usr/lib64.

    Usage in install_script:
        install_script = binary_install_libs(["libfoo.so", "libbar.so.1"])
    """
    cmds = ['mkdir -p "$OUT/usr/lib64"']
    for lib in libs:
        cmds.append('install -m 0755 "{}/{}" "$OUT/usr/lib64/"'.format(src_dir, lib))
    return "\n".join(cmds)

def binary_extract_tarball(tarball: str, dest: str = "/usr", strip: int = 1) -> str:
    """
    Helper to extract a tarball to a destination directory.

    Usage in install_script:
        install_script = binary_extract_tarball("app-1.0.tar.gz", "/opt/app", strip=1)
    """
    return '''
mkdir -p "$OUT{dest}"
tar -xf "$SRCS/{tarball}" -C "$OUT{dest}" --strip-components={strip}
'''.format(tarball = tarball, dest = dest, strip = strip)

def binary_copy_tree(src_subdir: str = "", dest: str = "/usr") -> str:
    """
    Helper to copy a directory tree from source to destination.

    Usage in install_script:
        install_script = binary_copy_tree("bin", "/usr/bin")
    """
    src = "$SRCS" if not src_subdir else "$SRCS/{}".format(src_subdir)
    return '''
mkdir -p "$OUT{dest}"
cp -r {src}/* "$OUT{dest}/" 2>/dev/null || true
'''.format(src = src, dest = dest)

def binary_create_wrapper(name: str, target: str, env_vars: dict[str, str] = {}) -> str:
    """
    Helper to create a wrapper script for a binary with environment setup.

    Usage in install_script:
        install_script = binary_create_wrapper("java", "/usr/lib/jvm/bin/java", {"JAVA_HOME": "/usr/lib/jvm"})
    """
    env_exports = "\n".join(['export {}="{}"'.format(k, v) for k, v in env_vars.items()])
    return '''
mkdir -p "$OUT/usr/bin"
cat > "$OUT/usr/bin/{name}" << 'WRAPPER_EOF'
#!/bin/bash
{env}
exec "{target}" "$@"
WRAPPER_EOF
chmod 0755 "$OUT/usr/bin/{name}"
'''.format(name = name, target = target, env = env_exports)

def binary_install_manpages(manpages: list[str], src_dir: str = "$SRCS") -> str:
    """
    Helper to install man pages from a binary package.

    Usage in install_script:
        install_script = binary_install_manpages(["app.1", "app.conf.5"])
    """
    cmds = []
    for man in manpages:
        # Extract section from filename (e.g., "app.1" -> section 1)
        cmds.append('''
_manfile="{src_dir}/{man}"
_section="${{_manfile##*.}}"
mkdir -p "$OUT/usr/share/man/man$_section"
install -m 0644 "$_manfile" "$OUT/usr/share/man/man$_section/"
'''.format(src_dir = src_dir, man = man))
    return "\n".join(cmds)

def binary_make_symlinks(symlinks: dict[str, str]) -> str:
    """
    Helper to create symbolic links.

    Usage in install_script:
        install_script = binary_make_symlinks({"/usr/bin/vi": "/usr/bin/vim"})
    """
    cmds = []
    for link, target in symlinks.items():
        cmds.append('mkdir -p "$OUT/$(dirname "{}")"'.format(link))
        cmds.append('ln -sf "{}" "$OUT/{}"'.format(target, link))
    return "\n".join(cmds)

def bootstrap_compiler_install(
        bootstrap_tarball: str,
        source_dir: str,
        build_cmd: str,
        install_prefix: str = "/usr",
        bins: list[str] = []) -> str:
    """
    Helper for bootstrap-style compiler installations (Go, GHC, Rust, etc.).

    Usage in install_script:
        install_script = bootstrap_compiler_install(
            bootstrap_tarball = "go1.21.6.linux-amd64.tar.gz",
            source_dir = "go",
            build_cmd = "cd src && ./make.bash",
            install_prefix = "/usr/local/go",
            bins = ["go", "gofmt"]
        )
    """
    bin_symlinks = "\n".join([
        'ln -sf "{}/bin/{}" "$OUT/usr/bin/{}"'.format(install_prefix, b, b)
        for b in bins
    ]) if bins else ""

    return '''
# Setup bootstrap
mkdir -p $WORK/bootstrap
tar -xf "$SRCS/{bootstrap_tarball}" -C $WORK/bootstrap --strip-components=1
export PATH="$WORK/bootstrap/bin:$PATH"

# Build from source
cd "$SRCS/{source_dir}"
{build_cmd}

# Install
mkdir -p "$OUT{install_prefix}"
cp -r "$SRCS/{source_dir}"/* "$OUT{install_prefix}/"

# Create bin symlinks
mkdir -p "$OUT/usr/bin"
{bin_symlinks}
'''.format(
        bootstrap_tarball = bootstrap_tarball,
        source_dir = source_dir,
        build_cmd = build_cmd,
        install_prefix = install_prefix,
        bin_symlinks = bin_symlinks,
    )

# -----------------------------------------------------------------------------
# Binary Package Convenience Macros
# -----------------------------------------------------------------------------

def simple_binary_package(
        name: str,
        version: str,
        src_uri: str,
        sha256: str,
        bins: list[str] = [],
        libs: list[str] = [],
        extract_to: str = "/usr",
        symlinks: dict[str, str] = {},
        deps: list[str] = [],
        maintainers: list[str] = [],
        exclude_patterns: list[str] = [],
        **kwargs):
    """
    Convenience macro for simple precompiled binary packages.

    This is the easiest way to package a precompiled binary - just specify
    the binaries and libraries to install.

    Example:
        simple_binary_package(
            name = "ripgrep",
            version = "14.1.0",
            src_uri = "https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-x86_64-unknown-linux-musl.tar.gz",
            sha256 = "...",
            bins = ["rg"],
        )
    """
    src_name = name + "-src"

    download_source(
        name = src_name,
        src_uri = src_uri,
        sha256 = sha256,
        exclude_patterns = exclude_patterns,
    )

    # Build install script
    install_cmds = []
    if bins:
        install_cmds.append(binary_install_bins(bins))
    if libs:
        install_cmds.append(binary_install_libs(libs))
    if symlinks:
        install_cmds.append(binary_make_symlinks(symlinks))
    if not bins and not libs:
        install_cmds.append(binary_copy_tree("", extract_to))

    binary_package(
        name = name,
        srcs = [":" + src_name],
        version = version,
        install_script = "\n".join(install_cmds),
        deps = deps,
        maintainers = maintainers,
        **kwargs
    )

def bootstrap_package(
        name: str,
        version: str,
        src_uri: str,
        sha256: str,
        bootstrap_uri: str,
        bootstrap_sha256: str,
        build_cmd: str,
        install_prefix: str = "/usr",
        bins: list[str] = [],
        deps: list[str] = [],
        maintainers: list[str] = [],
        exclude_patterns: list[str] = [],
        bootstrap_exclude_patterns: list[str] = [],
        **kwargs):
    """
    Convenience macro for bootstrap-compiled packages (compilers that need
    a previous version to build).

    Example:
        bootstrap_package(
            name = "go",
            version = "1.22.0",
            src_uri = "https://go.dev/dl/go1.22.0.src.tar.gz",
            sha256 = "...",
            bootstrap_uri = "https://go.dev/dl/go1.21.6.linux-amd64.tar.gz",
            bootstrap_sha256 = "...",
            build_cmd = "cd src && ./make.bash",
            install_prefix = "/usr/local/go",
            bins = ["go", "gofmt"],
        )
    """
    src_name = name + "-src"
    bootstrap_name = name + "-bootstrap-src"

    download_source(
        name = src_name,
        src_uri = src_uri,
        sha256 = sha256,
        exclude_patterns = exclude_patterns,
    )

    download_source(
        name = bootstrap_name,
        src_uri = bootstrap_uri,
        sha256 = bootstrap_sha256,
        exclude_patterns = bootstrap_exclude_patterns,
    )

    # Derive bootstrap tarball name from URI
    bootstrap_tarball = bootstrap_uri.split("/")[-1]

    binary_package(
        name = name,
        srcs = [":" + src_name, ":" + bootstrap_name],
        version = version,
        install_script = bootstrap_compiler_install(
            bootstrap_tarball = bootstrap_tarball,
            source_dir = name,
            build_cmd = build_cmd,
            install_prefix = install_prefix,
            bins = bins,
        ),
        deps = deps,
        maintainers = maintainers,
        **kwargs
    )
