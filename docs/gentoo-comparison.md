# Buck Macros vs Gentoo Ebuild System Comparison

This document compares the Buck macros in the `defs` directory with Gentoo's ebuild/portage system, identifying equivalent functionality and missing features.

## Feature Comparison Summary

| Category | Status | Notes |
|----------|--------|-------|
| USE Flags | **Implemented** | 80+ flags, profiles, conditional deps |
| Build Phases | **Implemented** | All standard phases supported |
| Slots/Subslots | **Implemented** | Full slot and subslot support with ABI tracking |
| Version Constraints | **Implemented** | Full constraint syntax |
| Package Sets | **Implemented** | @system, @world equivalents |
| Profiles | **Implemented** | 8 profiles available |
| Eclasses | **Implemented** | 11 eclasses: cmake, meson, cargo, go-module, etc. |
| License Tracking | **Implemented** | License groups, validation, ACCEPT_LICENSE |
| EAPI | **Implemented** | EAPI 6-8 with feature flags and migration support |
| VDB | **Implemented** | Installed package database with file ownership |
| Overlays | **Implemented** | Layered repository system with priorities |
| Config Protection | **Implemented** | CONFIG_PROTECT with merge file support |
| USE_EXPAND | **Implemented** | PYTHON_TARGETS, CPU_FLAGS_X86, VIDEO_CARDS, etc. |

---

## Well-Implemented Features

### 1. USE Flags System (`use_flags.bzl`)

**Equivalent Features:**
- Global USE flags (80+ defined covering build, graphics, audio, networking, etc.)
- Per-package USE flags via `package_use()`
- USE-conditional dependencies via `use_dep()`
- `use_enable()` and `use_with()` helpers
- REQUIRED_USE constraint checking
- Profile-based USE defaults
- USE flag descriptions

**Example:**
```python
use_package(
    name = "ffmpeg",
    use_flags = ["x264", "x265", "opus", "webp"],
    use_conditional_deps = {
        "x264": [":x264"],
        "x265": [":x265"],
    },
)
```

### 2. Build Phases (`package_defs.bzl`)

**Implemented Phases:**
- `src_unpack` - Source extraction (including git, svn, hg)
- `src_prepare` - Patching and preparation
- `src_configure` - Configuration (autotools, cmake, meson)
- `src_compile` - Compilation
- `src_install` - Installation
- `src_test` - Testing

**Ebuild-style Helpers:**
- `einfo`, `ewarn`, `eerror`, `die`
- `dobin`, `dosbin`, `dolib_so`, `dolib_a`
- `dodoc`, `doman`, `doinfo`
- `doins`, `doexe`, `dosym`
- `econf`, `emake`, `einstall`
- `epatch`, `eapply`, `eapply_user`

### 3. Version Management (`versions.bzl`, `registry.bzl`)

**Equivalent Features:**
- Version constraint operators: `>=`, `>`, `<=`, `<`, `~>`, wildcards
- Slot-based version grouping
- Multi-version package co-installation
- Default version selection
- Version status (stable, testing, deprecated, masked)

**Example:**
```python
versioned_package(
    name = "openssl",
    version = "3.0.10",
    slot = "3",
    keywords = ["amd64", "~arm64"],
)
```

### 4. Package Sets (`package_sets.bzl`)

**Equivalent to Gentoo sets:**
- System profiles (minimal, server, desktop, developer, hardened)
- Task sets (web-server, database-server, etc.)
- Desktop environment sets (gnome, kde, xfce, sway, etc.)
- Set operations (union, intersection, difference)

### 5. Package Masking (`package_customize.bzl`)

**Implemented:**
- Package masking/unmasking
- Keyword acceptance per package
- Profile-based masking

### 6. Build Systems Support

**Full Support For:**
- Autotools (configure/make)
- CMake
- Meson
- Cargo (Rust)
- Go
- Python (setuptools, pip)
- Ninja

### 7. Init System Integration

**Implemented:**
- `systemd_dounit()`, `systemd_enable_service()`
- `openrc_doinitd()`, `openrc_doconfd()`
- `newinitd()`, `newconfd()`

### 8. System Detection (`tooling.bzl`)

**Automated Detection:**
- CPU flags (AES, AVX, SSE)
- GPU (NVIDIA, AMD, Intel)
- Audio system
- Init system
- Storage type

---

### 9. Eclass System (`eclasses.bzl`)

**Equivalent Features:**
- Eclass inheritance via `inherit()` function
- 11 built-in eclasses for common build systems
- Combined phase functions and dependencies
- Automatic dependency merging

**Available Eclasses:**
- `cmake` - CMake-based packages
- `meson` - Meson-based packages
- `autotools` - Traditional configure/make
- `python-single-r1` - Single Python implementation
- `python-r1` - Multiple Python versions
- `go-module` - Go module packages
- `cargo` - Rust/Cargo packages
- `xdg` - Desktop application support
- `linux-mod` - Kernel modules
- `systemd` - Systemd unit files
- `qt5` - Qt5 applications

**Example:**
```python
load("//defs:eclasses.bzl", "inherit")

config = inherit(["cmake", "xdg"])

ebuild_package(
    name = "my-app",
    source = ":my-app-src",
    version = "1.0.0",
    src_configure = config["src_configure"],
    src_compile = config["src_compile"],
    bdepend = config["bdepend"],
)
```

### 10. License Tracking (`licenses.bzl`)

**Equivalent Features:**
- 60+ license definitions with metadata
- License groups (@FREE, @GPL-COMPATIBLE, @OSI-APPROVED, etc.)
- ACCEPT_LICENSE configuration
- License validation and compliance checking
- License file installation helpers

**Example:**
```python
load("//defs:licenses.bzl", "check_license", "dolicense")

# Validate license acceptance
if not check_license("GPL-2", ["@FREE"]):
    fail("License not accepted")

# Install license files
ebuild_package(
    name = "my-package",
    license = "GPL-2 || MIT",  # Dual licensed
    post_install = dolicense(["COPYING", "LICENSE"]),
)
```

### 11. EAPI Versioning (`eapi.bzl`)

**Equivalent Features:**
- EAPI versions 6, 7, and 8 supported
- Feature flags per EAPI version
- Deprecation and banning of functions
- Migration guides between versions
- Default phase implementations

**Example:**
```python
load("//defs:eapi.bzl", "require_eapi", "eapi_has_feature")

# Require minimum EAPI
require_eapi(8)

# Check for feature availability
if eapi_has_feature("subslots"):
    deps = [subslot_dep("//pkg/openssl", "3", "=")]
```

### 12. Subslots (`versions.bzl`)

**Equivalent Features:**
- Subslot specification for ABI tracking
- Subslot-aware dependencies (`:=` operator)
- ABI compatibility checking
- Automatic rebuild triggering

**Example:**
```python
load("//defs:versions.bzl", "subslot_dep", "register_package_versions")

register_package_versions(
    name = "openssl",
    category = "dev-libs",
    versions = {
        "3.2.0": {"slot": "3", "subslot": "3.2", "keywords": ["stable"]},
        "3.1.4": {"slot": "3", "subslot": "3.1", "keywords": ["stable"]},
    },
)

# Rebuild when ABI changes
deps = [subslot_dep("//packages/dev-libs/openssl", "3", "=")]
```

---

## Partially Implemented Features

### 2. Dependencies

**Implemented:**
- Build dependencies (via Buck2 deps)
- Conditional dependencies (USE-based)
- Version-constrained dependencies

**Missing:**
- `RDEPEND` vs `BDEPEND` vs `DEPEND` distinction
- `PDEPEND` (post-dependencies)
- Circular dependency handling
- `|| ( )` any-of dependency syntax

### 3. Keywords

**Implemented:**
- Keyword assignment (stable, testing)
- Arch-specific keywords

**Missing:**
- `~arch` testing keyword propagation
- `-*` keyword blocking
- `**` accept all keywords

### 4. License Tracking

**Missing Completely:**
- No license field in package definitions
- No license group definitions (GPL-COMPATIBLE, FREE, etc.)
- No `ACCEPT_LICENSE` filtering
- No license file installation helpers

---

## Missing Features

### 1. VDB (Installed Package Database) (High Priority)

**What it is:** Database tracking installed packages, their files, and metadata.

**Missing Capabilities:**
- Query installed packages
- Track which package owns which file
- Reverse dependency calculation
- Collision detection during installation
- Package uninstallation tracking

**Impact:** Cannot implement `emerge --depclean`, file ownership queries, or proper upgrades.

### 2. Overlay System (Medium Priority)

**What it is:** Layered package repositories for customization.

**Missing:**
- No way to override upstream packages
- No local package definitions
- No third-party repository support

**Impact:** Users cannot maintain local patches or custom packages easily.

### 3. Preserved Libraries Rebuild (Medium Priority)

**What it is:** Automatically rebuild packages when a library is upgraded.

**Missing:**
- No tracking of library consumers
- No automatic rebuild triggering
- No preserved-libs tracking

**Impact:** Manual intervention needed when upgrading core libraries.

### 4. News System (Low Priority)

**What it is:** Important notices to users about package changes.

**Missing:**
- No news item support
- No notification system for breaking changes

### 5. Configuration Protection (Medium Priority)

**What it is:** Protect user-modified configuration files during upgrades.

**Missing:**
- No `CONFIG_PROTECT` equivalent
- No `._cfg0000_` file generation
- No `dispatch-conf` or `etc-update` equivalent

**Impact:** User configuration may be overwritten during package updates.

### 6. Package Blocker Syntax (Low Priority)

**Missing:**
- `!package` - hard blocker
- `!!package` - unmerge blocker

### 7. SRC_URI Advanced Features (Low Priority)

**Missing:**
- `-> rename` syntax
- Mirror selection (`mirror://`)
- Fetch restrictions (`RESTRICT="fetch"`)

### 8. USE Flag Expansion (Medium Priority)

**Missing:**
- `USE_EXPAND` variables (CPU_FLAGS_X86, PYTHON_TARGETS, etc.)
- Automatic expansion in USE string

### 9. REQUIRED_USE Complex Syntax (Low Priority)

**Partially Implemented:** Basic checks work.

**Missing:**
- `^^ ( a b c )` - exactly one of
- `?? ( a b c )` - at most one of
- `|| ( a b )` - at least one of
- Nested expressions

### 10. Package Environment Files (Low Priority)

**Missing:**
- `/etc/portage/env/` per-package environment
- `/etc/portage/package.env` mappings

---

## Recommendations by Priority

### High Priority

1. **Add VDB Support**
   - Track installed packages in database
   - Implement file ownership tracking
   - Enable reverse dependency queries

2. **Complete Dependency Types**
   - Distinguish BDEPEND/DEPEND/RDEPEND
   - Implement PDEPEND for circular deps
   - Add `|| ( )` any-of syntax

### Medium Priority

3. **Add Configuration Protection**
   - Implement CONFIG_PROTECT
   - Generate merge conflict files

4. **Implement USE_EXPAND**
   - Support PYTHON_TARGETS, RUBY_TARGETS
   - Support CPU_FLAGS_X86

5. **Add Overlay System**
   - Support layered repositories
   - Allow local overrides

### Low Priority

6. **Add News System**
    - Support important notices
    - Track read/unread status

7. **Package Blocker Support**
    - Implement `!package` hard blocker
    - Implement `!!package` unmerge blocker

---

## Conclusion

The Buck macros now provide approximately **85-90%** of Gentoo's ebuild functionality. Core features like USE flags, build phases, versions/slots, package sets, eclasses, license tracking, EAPI versioning, and subslots are well-implemented.

The most critical remaining missing features are:
1. **VDB** - Prevents proper package management operations (file ownership, uninstallation tracking)
2. **Overlay System** - Users cannot maintain local package customizations easily

With the recent additions of eclasses, license tracking, EAPI versioning, and subslot support, BuckOs has achieved near-parity with Gentoo's core package building functionality.

## Appendix: Feature Mapping Table

| Gentoo Feature | Buck Equivalent | Status |
|----------------|-----------------|--------|
| ebuild | `ebuild_package()` | Done |
| eclass | `eclasses.bzl`, `inherit()` | Done |
| USE flags | `use_flags.bzl` | Done |
| SLOT | `slot` parameter | Done |
| SUBSLOT | `subslot` parameter, `subslot_dep()` | Done |
| KEYWORDS | `keywords` parameter | Partial |
| DEPEND | `deps` | Partial |
| BDEPEND | `bdepend` in ebuild_package | Done |
| RDEPEND | `rdepend` in ebuild_package | Done |
| PDEPEND | `pdepend` in ebuild_package | Done |
| LICENSE | `licenses.bzl`, license groups | Done |
| EAPI | `eapi.bzl`, EAPI 6-8 | Done |
| RESTRICT | - | Missing |
| PROPERTIES | - | Missing |
| REQUIRED_USE | `required_use_check()` | Partial |
| SRC_URI | `src_url` | Done |
| inherit | `inherit()` function | Done |
| default_src_* | Helper functions | Done |
| do* helpers | Helper functions | Done |
| /var/db/pkg | - | Missing |
| emerge | Buck2 build | Different paradigm |
| make.conf | `generate_make_conf()` | Done |
| package.use | `generate_package_use()` | Done |
| package.mask | `package_masks` | Done |
| package.accept_keywords | `package_accept_keywords` | Done |
| profiles | `PROFILES` dict | Done |
| overlays | - | Missing |
| sets (@world) | `package_sets.bzl` | Done |
| news | - | Missing |
| preserved-libs | - | Missing |
| CONFIG_PROTECT | - | Missing |
