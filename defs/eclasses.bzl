"""
Eclass inheritance system for BuckOs packages.

This module provides an eclass-like inheritance mechanism similar to Gentoo's
ebuild system, allowing code reuse and standardized build patterns.

Example usage:
    load("//defs:eclasses.bzl", "inherit", "ECLASSES")

    # Get combined configuration from multiple eclasses
    config = inherit(["cmake", "python-single-r1"])

    ebuild_package(
        name = "my-package",
        source = ":my-package-src",
        version = "1.0.0",
        src_configure = config["src_configure"],
        src_compile = config["src_compile"],
        src_install = config["src_install"],
        bdepend = config["bdepend"],
        ...
    )
"""

# =============================================================================
# ECLASS DEFINITIONS
# =============================================================================

# -----------------------------------------------------------------------------
# CMake Eclass
# -----------------------------------------------------------------------------

_CMAKE_ECLASS = {
    "name": "cmake",
    "description": "Support for cmake-based packages",
    "src_configure": '''
mkdir -p "${BUILD_DIR:-build}"
cd "${BUILD_DIR:-build}"
cmake \\
    -DCMAKE_INSTALL_PREFIX="${EPREFIX:-/usr}" \\
    -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}" \\
    -DCMAKE_INSTALL_LIBDIR="${LIBDIR:-lib64}" \\
    -DCMAKE_C_FLAGS="${CFLAGS:-}" \\
    -DCMAKE_CXX_FLAGS="${CXXFLAGS:-}" \\
    ${CMAKE_EXTRA_ARGS:-} \\
    ..
''',
    "src_compile": '''
cd "${BUILD_DIR:-build}"
cmake --build . -j${MAKEOPTS:-$(nproc)}
''',
    "src_install": '''
cd "${BUILD_DIR:-build}"
DESTDIR="$DESTDIR" cmake --install .
''',
    "src_test": '''
cd "${BUILD_DIR:-build}"
ctest --output-on-failure
''',
    "bdepend": ["//packages/dev-util:cmake", "//packages/dev-util:ninja"],
    "exports": ["cmake-utils_src_configure", "cmake-utils_src_compile", "cmake-utils_src_install"],
}

# -----------------------------------------------------------------------------
# Meson Eclass
# -----------------------------------------------------------------------------

_MESON_ECLASS = {
    "name": "meson",
    "description": "Support for meson-based packages",
    "src_configure": '''
meson setup "${BUILD_DIR:-build}" \\
    --prefix="${EPREFIX:-/usr}" \\
    --libdir="${LIBDIR:-lib64}" \\
    --buildtype="${MESON_BUILD_TYPE:-release}" \\
    ${MESON_EXTRA_ARGS:-}
''',
    "src_compile": '''
meson compile -C "${BUILD_DIR:-build}" -j${MAKEOPTS:-$(nproc)}
''',
    "src_install": '''
DESTDIR="$DESTDIR" meson install -C "${BUILD_DIR:-build}"
''',
    "src_test": '''
meson test -C "${BUILD_DIR:-build}" --print-errorlogs
''',
    "bdepend": ["//packages/dev-util:meson", "//packages/dev-util:ninja"],
    "exports": ["meson_src_configure", "meson_src_compile", "meson_src_install"],
}

# -----------------------------------------------------------------------------
# Autotools Eclass
# -----------------------------------------------------------------------------

_AUTOTOOLS_ECLASS = {
    "name": "autotools",
    "description": "Support for autotools-based packages",
    "src_prepare": '''
# Run autoreconf if needed
if [ -f configure.ac ] || [ -f configure.in ]; then
    if [ ! -f configure ] || [ configure.ac -nt configure ] 2>/dev/null; then
        autoreconf -fiv
    fi
fi
''',
    "src_configure": '''
ECONF_SOURCE="${ECONF_SOURCE:-.}"
"$ECONF_SOURCE/configure" \\
    --prefix="${EPREFIX:-/usr}" \\
    --build="${CBUILD:-$(gcc -dumpmachine)}" \\
    --host="${CHOST:-$(gcc -dumpmachine)}" \\
    --mandir="${EPREFIX:-/usr}/share/man" \\
    --infodir="${EPREFIX:-/usr}/share/info" \\
    --datadir="${EPREFIX:-/usr}/share" \\
    --sysconfdir="${EPREFIX:-/etc}" \\
    --localstatedir="${EPREFIX:-/var}" \\
    --libdir="${EPREFIX:-/usr}/${LIBDIR:-lib64}" \\
    ${EXTRA_ECONF:-}
''',
    "src_compile": '''
make -j${MAKEOPTS:-$(nproc)} ${EXTRA_EMAKE:-}
''',
    "src_install": '''
make DESTDIR="$DESTDIR" ${EXTRA_EMAKE:-} install
''',
    "src_test": '''
if make -q check 2>/dev/null; then
    make check
elif make -q test 2>/dev/null; then
    make test
fi
''',
    "bdepend": ["//packages/sys-devel:autoconf", "//packages/sys-devel:automake", "//packages/sys-devel:libtool"],
    "exports": ["eautoreconf", "econf", "emake", "einstall"],
}

# -----------------------------------------------------------------------------
# Python Single-R1 Eclass
# -----------------------------------------------------------------------------

_PYTHON_SINGLE_R1_ECLASS = {
    "name": "python-single-r1",
    "description": "Support for packages that need a single Python implementation",
    "src_configure": '''
# Setup Python environment
export PYTHON="${PYTHON:-python3}"
export PYTHON_SITEDIR="$($PYTHON -c 'import site; print(site.getsitepackages()[0])')"
''',
    "src_compile": '''
$PYTHON setup.py build
''',
    "src_install": '''
$PYTHON setup.py install \\
    --prefix=/usr \\
    --root="$DESTDIR" \\
    --optimize=1 \\
    --skip-build
''',
    "src_test": '''
$PYTHON -m pytest -v
''',
    "bdepend": ["//packages/dev-python:setuptools"],
    "rdepend": ["//packages/dev-lang:python"],
    "exports": ["python_get_sitedir", "python_domodule", "python_newscript"],
}

# -----------------------------------------------------------------------------
# Python R1 Eclass (multiple implementations)
# -----------------------------------------------------------------------------

_PYTHON_R1_ECLASS = {
    "name": "python-r1",
    "description": "Support for packages compatible with multiple Python versions",
    "src_configure": '''
# Setup for multiple Python implementations
for impl in ${PYTHON_COMPAT:-python3}; do
    export PYTHON="$impl"
    mkdir -p "${BUILD_DIR:-build}-$impl"
done
''',
    "src_compile": '''
for impl in ${PYTHON_COMPAT:-python3}; do
    cd "${BUILD_DIR:-build}-$impl"
    $impl ../setup.py build
done
''',
    "src_install": '''
for impl in ${PYTHON_COMPAT:-python3}; do
    cd "${BUILD_DIR:-build}-$impl"
    $impl ../setup.py install \\
        --prefix=/usr \\
        --root="$DESTDIR" \\
        --optimize=1 \\
        --skip-build
done
''',
    "bdepend": ["//packages/dev-python:setuptools"],
    "rdepend": ["//packages/dev-lang:python"],
    "exports": ["python_foreach_impl", "python_setup"],
}

# -----------------------------------------------------------------------------
# Go Module Eclass
# -----------------------------------------------------------------------------

_GO_MODULE_ECLASS = {
    "name": "go-module",
    "description": "Support for Go module-based packages",
    "src_configure": '''
export GOPATH="${GOPATH:-$PWD/go}"
export GOCACHE="${GOCACHE:-$PWD/.cache/go-build}"
export GOMODCACHE="${GOMODCACHE:-$GOPATH/pkg/mod}"
export CGO_ENABLED="${CGO_ENABLED:-1}"

# Use vendored dependencies if available
if [ -d vendor ]; then
    export GOFLAGS="${GOFLAGS:-} -mod=vendor"
fi
''',
    "src_compile": '''
go build \\
    -v \\
    -ldflags="-s -w ${GO_LDFLAGS:-}" \\
    -o "${BUILD_DIR:-build}/" \\
    ${GO_PACKAGES:-.}
''',
    "src_install": '''
mkdir -p "$DESTDIR/usr/bin"
find "${BUILD_DIR:-build}" -maxdepth 1 -type f -executable -exec install -m 0755 {} "$DESTDIR/usr/bin/" \;
''',
    "src_test": '''
go test -v ${GO_TEST_PACKAGES:-./...}
''',
    "bdepend": ["//packages/dev-lang:go"],
    "exports": ["go-module_src_compile", "go-module_src_install"],
}

# -----------------------------------------------------------------------------
# Cargo Eclass
# -----------------------------------------------------------------------------

_CARGO_ECLASS = {
    "name": "cargo",
    "description": "Support for Rust/Cargo packages",
    "src_configure": '''
export CARGO_HOME="${CARGO_HOME:-$PWD/.cargo}"
mkdir -p "$CARGO_HOME"

# Use vendored crates if available
if [ -d vendor ]; then
    mkdir -p .cargo
    cat > .cargo/config.toml << 'CARGO_CONFIG_EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
CARGO_CONFIG_EOF
fi
''',
    "src_compile": '''
cargo build --release \\
    --jobs ${MAKEOPTS:-$(nproc)} \\
    ${CARGO_BUILD_FLAGS:-}
''',
    "src_install": '''
mkdir -p "$DESTDIR/usr/bin"
find target/release -maxdepth 1 -type f -executable ! -name "*.d" -exec install -m 0755 {} "$DESTDIR/usr/bin/" \;
''',
    "src_test": '''
cargo test --release ${CARGO_TEST_FLAGS:-}
''',
    "bdepend": ["//packages/dev-lang:rust"],
    "exports": ["cargo_src_configure", "cargo_src_compile", "cargo_src_install"],
}

# -----------------------------------------------------------------------------
# XDG Eclass
# -----------------------------------------------------------------------------

_XDG_ECLASS = {
    "name": "xdg",
    "description": "XDG base directory specification support",
    "src_install": '''
# Standard install phase - can be customized
''',
    "post_install": '''
# Update desktop database
if [ -d "$DESTDIR/usr/share/applications" ]; then
    update-desktop-database -q "$DESTDIR/usr/share/applications" 2>/dev/null || true
fi

# Update icon cache
if [ -d "$DESTDIR/usr/share/icons/hicolor" ]; then
    gtk-update-icon-cache -q -t -f "$DESTDIR/usr/share/icons/hicolor" 2>/dev/null || true
fi

# Update MIME database
if [ -d "$DESTDIR/usr/share/mime" ]; then
    update-mime-database "$DESTDIR/usr/share/mime" 2>/dev/null || true
fi
''',
    "rdepend": [],
    "exports": ["xdg_desktop_database_update", "xdg_icon_cache_update", "xdg_mimeinfo_database_update"],
}

# -----------------------------------------------------------------------------
# Kernel Module Eclass
# -----------------------------------------------------------------------------

_LINUX_MOD_ECLASS = {
    "name": "linux-mod",
    "description": "Support for external kernel module building",
    "src_configure": '''
# Verify kernel source availability
if [ -z "${KERNEL_DIR:-}" ]; then
    if [ -d "/lib/modules/$(uname -r)/build" ]; then
        export KERNEL_DIR="/lib/modules/$(uname -r)/build"
    elif [ -d "/usr/src/linux" ]; then
        export KERNEL_DIR="/usr/src/linux"
    else
        echo "ERROR: Cannot find kernel sources"
        exit 1
    fi
fi
export KBUILD_DIR="${KBUILD_DIR:-$KERNEL_DIR}"
''',
    "src_compile": '''
make -C "$KERNEL_DIR" M="$PWD" modules
''',
    "src_install": '''
make -C "$KERNEL_DIR" M="$PWD" INSTALL_MOD_PATH="$DESTDIR" modules_install
''',
    "bdepend": ["//packages/kernel:linux-headers"],
    "exports": ["linux-mod_src_compile", "linux-mod_src_install"],
}

# -----------------------------------------------------------------------------
# Systemd Eclass
# -----------------------------------------------------------------------------

_SYSTEMD_ECLASS = {
    "name": "systemd",
    "description": "Systemd unit file installation helpers",
    "post_install": '''
# Reload systemd if running
if command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1; then
    systemctl daemon-reload 2>/dev/null || true
fi
''',
    "rdepend": ["//packages/sys-apps:systemd"],
    "exports": ["systemd_dounit", "systemd_newunit", "systemd_enable_service", "systemd_get_unitdir"],
}

# -----------------------------------------------------------------------------
# Qt5 Eclass
# -----------------------------------------------------------------------------

_QT5_ECLASS = {
    "name": "qt5",
    "description": "Support for Qt5-based packages",
    "src_configure": '''
export QT_SELECT=qt5
export PATH="/usr/lib/qt5/bin:$PATH"

if [ -f *.pro ]; then
    qmake ${QMAKE_ARGS:-}
elif [ -f CMakeLists.txt ]; then
    mkdir -p "${BUILD_DIR:-build}"
    cd "${BUILD_DIR:-build}"
    cmake .. \\
        -DCMAKE_INSTALL_PREFIX="${EPREFIX:-/usr}" \\
        -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}" \\
        -DQT_QMAKE_EXECUTABLE=/usr/lib/qt5/bin/qmake \\
        ${CMAKE_EXTRA_ARGS:-}
fi
''',
    "src_compile": '''
if [ -f Makefile ]; then
    make -j${MAKEOPTS:-$(nproc)}
elif [ -d "${BUILD_DIR:-build}" ]; then
    cmake --build "${BUILD_DIR:-build}" -j${MAKEOPTS:-$(nproc)}
fi
''',
    "src_install": '''
if [ -f Makefile ]; then
    make INSTALL_ROOT="$DESTDIR" install
elif [ -d "${BUILD_DIR:-build}" ]; then
    DESTDIR="$DESTDIR" cmake --install "${BUILD_DIR:-build}"
fi
''',
    "bdepend": ["//packages/dev-qt:qtcore"],
    "rdepend": ["//packages/dev-qt:qtcore"],
    "exports": ["qt5_get_bindir", "qt5_get_headerdir", "qt5_get_libdir"],
}

# =============================================================================
# ECLASS REGISTRY
# =============================================================================

ECLASSES = {
    "cmake": _CMAKE_ECLASS,
    "meson": _MESON_ECLASS,
    "autotools": _AUTOTOOLS_ECLASS,
    "python-single-r1": _PYTHON_SINGLE_R1_ECLASS,
    "python-r1": _PYTHON_R1_ECLASS,
    "go-module": _GO_MODULE_ECLASS,
    "cargo": _CARGO_ECLASS,
    "xdg": _XDG_ECLASS,
    "linux-mod": _LINUX_MOD_ECLASS,
    "systemd": _SYSTEMD_ECLASS,
    "qt5": _QT5_ECLASS,
}

# =============================================================================
# INHERITANCE FUNCTIONS
# =============================================================================

def inherit(eclass_names):
    """
    Inherit from one or more eclasses, returning merged configuration.

    This is the main entry point for the eclass system. It takes a list of
    eclass names and returns a dictionary with merged phase functions and
    dependencies.

    Args:
        eclass_names: List of eclass names to inherit from

    Returns:
        Dictionary with:
        - src_prepare: Combined prepare phase
        - src_configure: Combined configure phase
        - src_compile: Combined compile phase
        - src_install: Combined install phase
        - src_test: Combined test phase
        - post_install: Combined post-install hooks
        - bdepend: Combined build dependencies
        - rdepend: Combined runtime dependencies
        - inherited: List of inherited eclass names

    Example:
        config = inherit(["cmake", "xdg"])
        ebuild_package(
            name = "my-app",
            src_configure = config["src_configure"],
            src_compile = config["src_compile"],
            src_install = config["src_install"],
            bdepend = config["bdepend"],
        )
    """
    result = {
        "src_prepare": "",
        "src_configure": "",
        "src_compile": "",
        "src_install": "",
        "src_test": "",
        "post_install": "",
        "bdepend": [],
        "rdepend": [],
        "inherited": [],
    }

    for name in eclass_names:
        if name not in ECLASSES:
            fail("Unknown eclass: {}. Available: {}".format(name, ", ".join(ECLASSES.keys())))

        eclass = ECLASSES[name]
        result["inherited"].append(name)

        # Merge phase functions (later eclasses can override)
        if "src_prepare" in eclass and eclass["src_prepare"]:
            result["src_prepare"] = eclass["src_prepare"]
        if "src_configure" in eclass and eclass["src_configure"]:
            result["src_configure"] = eclass["src_configure"]
        if "src_compile" in eclass and eclass["src_compile"]:
            result["src_compile"] = eclass["src_compile"]
        if "src_install" in eclass and eclass["src_install"]:
            result["src_install"] = eclass["src_install"]
        if "src_test" in eclass and eclass["src_test"]:
            result["src_test"] = eclass["src_test"]

        # Concatenate post-install hooks
        if "post_install" in eclass and eclass["post_install"]:
            result["post_install"] += "\n" + eclass["post_install"]

        # Merge dependencies (deduplicating)
        if "bdepend" in eclass:
            for dep in eclass["bdepend"]:
                if dep not in result["bdepend"]:
                    result["bdepend"].append(dep)
        if "rdepend" in eclass:
            for dep in eclass["rdepend"]:
                if dep not in result["rdepend"]:
                    result["rdepend"].append(dep)

    return result

def get_eclass(name):
    """
    Get a single eclass definition by name.

    Args:
        name: Name of the eclass

    Returns:
        Dictionary with eclass configuration
    """
    if name not in ECLASSES:
        fail("Unknown eclass: {}".format(name))
    return ECLASSES[name]

def list_eclasses():
    """
    Get list of all available eclass names.

    Returns:
        List of eclass name strings
    """
    return list(ECLASSES.keys())

def eclass_has_phase(eclass_name, phase):
    """
    Check if an eclass provides a specific phase function.

    Args:
        eclass_name: Name of the eclass
        phase: Phase name (src_configure, src_compile, etc.)

    Returns:
        Boolean indicating if the eclass provides the phase
    """
    if eclass_name not in ECLASSES:
        return False
    eclass = ECLASSES[eclass_name]
    return phase in eclass and eclass[phase]

# =============================================================================
# ECLASS HELPER MACROS
# =============================================================================

def eclass_package(
        name,
        source,
        version,
        eclass_inherit,
        category = "",
        slot = "0",
        description = "",
        homepage = "",
        license = "",
        use_flags = [],
        env = {},
        depend = [],
        rdepend = [],
        bdepend = [],
        pdepend = [],
        maintainers = [],
        src_prepare_extra = "",
        src_configure_extra = "",
        src_compile_extra = "",
        src_install_extra = "",
        run_tests = False,
        **kwargs):
    """
    Create an ebuild-style package with eclass inheritance.

    This is a convenience macro that combines ebuild_package with the
    inherit() function for cleaner package definitions.

    Args:
        name: Package name
        source: Source dependency
        version: Package version
        eclass_inherit: List of eclasses to inherit from
        ... (other ebuild_package arguments)

    Example:
        eclass_package(
            name = "my-cmake-app",
            source = ":my-cmake-app-src",
            version = "1.0.0",
            eclass_inherit = ["cmake", "xdg"],
            description = "My CMake Application",
        )
    """
    # This would be implemented in package_defs.bzl to create ebuild_package
    # with inherited eclass configuration
    pass  # Implementation would go here

# =============================================================================
# DOCUMENTATION
# =============================================================================

"""
## Available Eclasses

### cmake
Support for CMake-based packages. Provides standard cmake configure, build,
and install phases.

### meson
Support for Meson-based packages with ninja backend.

### autotools
Support for traditional autotools (configure/make) packages.

### python-single-r1
Support for Python packages that need a single Python implementation.

### python-r1
Support for Python packages compatible with multiple Python versions.

### go-module
Support for Go module-based packages.

### cargo
Support for Rust/Cargo packages.

### xdg
XDG base directory specification support for desktop applications.

### linux-mod
Support for external Linux kernel module building.

### systemd
Systemd unit file installation helpers.

### qt5
Support for Qt5-based packages.

## Adding New Eclasses

To add a new eclass:

1. Define the eclass dictionary with:
   - name: Eclass identifier
   - description: What the eclass does
   - src_*: Phase function scripts
   - bdepend: Build dependencies
   - rdepend: Runtime dependencies
   - exports: Exported function names (documentation)

2. Add to ECLASSES registry

3. Document in this file

Example:
    _MY_ECLASS = {
        "name": "my-eclass",
        "description": "My custom eclass",
        "src_configure": "...",
        "src_compile": "...",
        "bdepend": [...],
    }

    ECLASSES["my-eclass"] = _MY_ECLASS
"""
