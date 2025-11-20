# Buck Macros vs Gentoo Ebuild System Comparison

This document compares the Buck macros in the `defs` directory with Gentoo's ebuild/portage system, identifying equivalent functionality and missing features.

## Feature Comparison Summary

| Category | Status | Notes |
|----------|--------|-------|
| USE Flags | **Implemented** | 80+ flags, profiles, conditional deps |
| Build Phases | **Implemented** | All standard phases supported |
| Slots/Subslots | **Partially** | Slots work, subslots missing |
| Version Constraints | **Implemented** | Full constraint syntax |
| Package Sets | **Implemented** | @system, @world equivalents |
| Profiles | **Implemented** | 8 profiles available |
| Eclasses | **Missing** | No eclass inheritance system |
| VDB | **Missing** | No installed package database |
| EAPI | **Missing** | No API versioning |
| Overlays | **Missing** | No overlay system |

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

## Partially Implemented Features

### 1. Slots and Subslots

**Implemented:** Slots for major version grouping
```python
slot = "3"  # openssl 3.x
```

**Missing:** Subslots for ABI compatibility tracking
```bash
# Gentoo: SLOT="3/3" where subslot tracks soname
```

**Impact:** Cannot automatically trigger rebuilds when shared library ABI changes.

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

### 1. Eclasses (High Priority)

**What it is:** Reusable code libraries that ebuilds can inherit.

**Gentoo Example:**
```bash
inherit cmake python-single-r1 xdg
```

**Impact:** Code duplication in package definitions. Common patterns must be repeated.

**Recommendation:** Implement an eclass-like inheritance system:
```python
# Proposed
ebuild_package(
    name = "my-package",
    inherit = ["cmake", "python-single-r1"],
    ...
)
```

### 2. VDB (Installed Package Database) (High Priority)

**What it is:** Database tracking installed packages, their files, and metadata.

**Missing Capabilities:**
- Query installed packages
- Track which package owns which file
- Reverse dependency calculation
- Collision detection during installation
- Package uninstallation tracking

**Impact:** Cannot implement `emerge --depclean`, file ownership queries, or proper upgrades.

### 3. EAPI Versioning (Medium Priority)

**What it is:** API version controlling available features in ebuilds.

**Missing:**
- No way to version the macro API
- Cannot deprecate old behaviors
- Cannot introduce breaking changes safely

**Recommendation:** Add an `eapi` field to package definitions.

### 4. Overlay System (Medium Priority)

**What it is:** Layered package repositories for customization.

**Missing:**
- No way to override upstream packages
- No local package definitions
- No third-party repository support

**Impact:** Users cannot maintain local patches or custom packages easily.

### 5. Preserved Libraries Rebuild (Medium Priority)

**What it is:** Automatically rebuild packages when a library is upgraded.

**Missing:**
- No tracking of library consumers
- No automatic rebuild triggering
- No preserved-libs tracking

**Impact:** Manual intervention needed when upgrading core libraries.

### 6. News System (Low Priority)

**What it is:** Important notices to users about package changes.

**Missing:**
- No news item support
- No notification system for breaking changes

### 7. Configuration Protection (Medium Priority)

**What it is:** Protect user-modified configuration files during upgrades.

**Missing:**
- No `CONFIG_PROTECT` equivalent
- No `._cfg0000_` file generation
- No `dispatch-conf` or `etc-update` equivalent

**Impact:** User configuration may be overwritten during package updates.

### 8. Package Blocker Syntax (Low Priority)

**Missing:**
- `!package` - hard blocker
- `!!package` - unmerge blocker

### 9. SRC_URI Advanced Features (Low Priority)

**Missing:**
- `-> rename` syntax
- Mirror selection (`mirror://`)
- Fetch restrictions (`RESTRICT="fetch"`)

### 10. USE Flag Expansion (Medium Priority)

**Missing:**
- `USE_EXPAND` variables (CPU_FLAGS_X86, PYTHON_TARGETS, etc.)
- Automatic expansion in USE string

### 11. REQUIRED_USE Complex Syntax (Low Priority)

**Partially Implemented:** Basic checks work.

**Missing:**
- `^^ ( a b c )` - exactly one of
- `?? ( a b c )` - at most one of
- `|| ( a b )` - at least one of
- Nested expressions

### 12. Package Environment Files (Low Priority)

**Missing:**
- `/etc/portage/env/` per-package environment
- `/etc/portage/package.env` mappings

---

## Recommendations by Priority

### High Priority

1. **Implement Eclass System**
   - Create `defs/eclasses/` directory
   - Implement `inherit()` mechanism
   - Port common eclasses: cmake, meson, python-single-r1, go-module

2. **Add VDB Support**
   - Track installed packages in database
   - Implement file ownership tracking
   - Enable reverse dependency queries

3. **Complete Dependency Types**
   - Distinguish BDEPEND/DEPEND/RDEPEND
   - Implement PDEPEND for circular deps
   - Add `|| ( )` any-of syntax

### Medium Priority

4. **Add License Support**
   - Add `license` field to packages
   - Implement license groups
   - Add `ACCEPT_LICENSE` configuration

5. **Implement Subslots**
   - Track ABI/soname in subslot
   - Trigger rebuilds on subslot changes

6. **Add Configuration Protection**
   - Implement CONFIG_PROTECT
   - Generate merge conflict files

7. **Implement USE_EXPAND**
   - Support PYTHON_TARGETS, RUBY_TARGETS
   - Support CPU_FLAGS_X86

### Low Priority

8. **Add Overlay System**
   - Support layered repositories
   - Allow local overrides

9. **Implement EAPI Versioning**
   - Version the macro API
   - Support deprecation

10. **Add News System**
    - Support important notices
    - Track read/unread status

---

## Conclusion

The Buck macros provide approximately **70-75%** of Gentoo's ebuild functionality. Core features like USE flags, build phases, versions/slots, and package sets are well-implemented.

The most critical missing features are:
1. **Eclasses** - Prevents code reuse across packages
2. **VDB** - Prevents proper package management operations
3. **License tracking** - Compliance and legal concerns

These gaps should be addressed to achieve feature parity with Gentoo's portage system.

## Appendix: Feature Mapping Table

| Gentoo Feature | Buck Equivalent | Status |
|----------------|-----------------|--------|
| ebuild | `ebuild_package()` | Done |
| eclass | - | Missing |
| USE flags | `use_flags.bzl` | Done |
| SLOT | `slot` parameter | Done |
| SUBSLOT | - | Missing |
| KEYWORDS | `keywords` parameter | Partial |
| DEPEND | `deps` | Partial |
| BDEPEND | - | Missing |
| RDEPEND | `runtime_deps` | Partial |
| PDEPEND | - | Missing |
| LICENSE | - | Missing |
| RESTRICT | - | Missing |
| PROPERTIES | - | Missing |
| REQUIRED_USE | `required_use_check()` | Partial |
| SRC_URI | `src_url` | Done |
| inherit | - | Missing |
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
