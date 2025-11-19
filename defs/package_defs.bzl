"""
Package build rules for Sideros Linux Distribution.
Similar to Gentoo's ebuild system but using Buck2.
"""

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
])

def _download_source_impl(ctx: AnalysisContext) -> list[Provider]:
    """Download and extract source tarball."""
    out_dir = ctx.actions.declare_output(ctx.attrs.name + "-src", dir = True)

    # Script to download and extract
    script = ctx.actions.write(
        "download.sh",
        """#!/bin/bash
set -e
mkdir -p "$1"
cd "$1"
curl -L -o source.tar.gz "$2"
echo "$3  source.tar.gz" | sha256sum -c -
tar xzf source.tar.gz --strip-components=1
rm source.tar.gz
""",
    )

    ctx.actions.run(
        cmd_args([
            "bash",
            script,
            out_dir.as_output(),
            ctx.attrs.src_uri,
            ctx.attrs.sha256,
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
    },
)

def _configure_make_package_impl(ctx: AnalysisContext) -> list[Provider]:
    """Build a package using configure && make && make install."""
    install_dir = ctx.actions.declare_output(ctx.attrs.name, dir = True)

    # Get source directory from dependency
    src_dir = ctx.attrs.source[DefaultInfo].default_outputs[0]

    # Build configuration
    configure_args = " ".join(ctx.attrs.configure_args) if ctx.attrs.configure_args else ""
    make_args = " ".join(ctx.attrs.make_args) if ctx.attrs.make_args else ""
    env_vars = " ".join(["{}={}".format(k, v) for k, v in ctx.attrs.env.items()]) if ctx.attrs.env else ""

    # Pre-configure commands
    pre_configure = ctx.attrs.pre_configure if ctx.attrs.pre_configure else ""

    # Post-install commands
    post_install = ctx.attrs.post_install if ctx.attrs.post_install else ""

    script = ctx.actions.write(
        "build.sh",
        """#!/bin/bash
set -e
export DESTDIR="$1"
export PREFIX="${{PREFIX:-/usr}}"
cd "$2"

# Set environment
{env}

# Pre-configure hook
{pre_configure}

# Configure
if [ -f configure ]; then
    ./configure --prefix="$PREFIX" {configure_args}
elif [ -f Configure ]; then
    ./Configure --prefix="$PREFIX" {configure_args}
elif [ -f CMakeLists.txt ]; then
    mkdir -p build && cd build
    cmake .. -DCMAKE_INSTALL_PREFIX="$PREFIX" {configure_args}
fi

# Build
make -j$(nproc) {make_args}

# Install
make install DESTDIR="$DESTDIR" {make_args}

# Post-install hook
{post_install}
""".format(
            env = env_vars,
            pre_configure = pre_configure,
            configure_args = configure_args,
            make_args = make_args,
            post_install = post_install,
        ),
    )

    # Collect dependency outputs for build environment
    dep_dirs = []
    for dep in ctx.attrs.deps:
        dep_dirs.append(dep[DefaultInfo].default_outputs[0])

    ctx.actions.run(
        cmd_args([
            "bash",
            script,
            install_dir.as_output(),
            src_dir,
        ]),
        category = "build",
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
        ),
    ]

configure_make_package = rule(
    impl = _configure_make_package_impl,
    attrs = {
        "source": attrs.dep(),
        "version": attrs.string(),
        "description": attrs.string(default = ""),
        "homepage": attrs.string(default = ""),
        "license": attrs.string(default = ""),
        "configure_args": attrs.list(attrs.string(), default = []),
        "make_args": attrs.list(attrs.string(), default = []),
        "env": attrs.dict(attrs.string(), attrs.string(), default = {}),
        "pre_configure": attrs.string(default = ""),
        "post_install": attrs.string(default = ""),
        "deps": attrs.list(attrs.dep(), default = []),
        "build_deps": attrs.list(attrs.dep(), default = []),
    },
)

def _kernel_build_impl(ctx: AnalysisContext) -> list[Provider]:
    """Build Linux kernel with custom configuration."""
    install_dir = ctx.actions.declare_output(ctx.attrs.name, dir = True)
    src_dir = ctx.attrs.source[DefaultInfo].default_outputs[0]

    # Kernel config
    config_file = ctx.attrs.config if ctx.attrs.config else None

    script = ctx.actions.write(
        "build_kernel.sh",
        """#!/bin/bash
set -e
export INSTALL_PATH="$1/boot"
export INSTALL_MOD_PATH="$1"
mkdir -p "$INSTALL_PATH"
cd "$2"

# Apply config
if [ -n "$3" ]; then
    cp "$3" .config
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

    config_arg = config_file if config_file else ""

    ctx.actions.run(
        cmd_args([
            "bash",
            script,
            install_dir.as_output(),
            src_dir,
            config_arg,
        ]),
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
    },
)

def _binary_package_impl(ctx: AnalysisContext) -> list[Provider]:
    """Create a package from pre-built binaries or simple scripts."""
    install_dir = ctx.actions.declare_output(ctx.attrs.name, dir = True)

    # Copy files to install directory
    script_content = "#!/bin/bash\nset -e\nmkdir -p \"$1\"\n"

    for dest, src in ctx.attrs.files.items():
        script_content += 'mkdir -p "$(dirname "$1/{}")"\n'.format(dest)
        script_content += 'cp -r "{}" "$1/{}"\n'.format(src, dest)

    script = ctx.actions.write("install.sh", script_content)

    ctx.actions.run(
        cmd_args(["bash", script, install_dir.as_output()]),
        category = "install",
        identifier = ctx.attrs.name,
    )

    return [DefaultInfo(default_output = install_dir)]

binary_package = rule(
    impl = _binary_package_impl,
    attrs = {
        "files": attrs.dict(attrs.string(), attrs.string(), default = {}),
        "version": attrs.string(default = "1.0"),
    },
)

def _rootfs_impl(ctx: AnalysisContext) -> list[Provider]:
    """Assemble a root filesystem from packages."""
    rootfs_dir = ctx.actions.declare_output(ctx.attrs.name, dir = True)

    # Collect all package outputs
    pkg_dirs = []
    for pkg in ctx.attrs.packages:
        pkg_dirs.append(pkg[DefaultInfo].default_outputs[0])

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
