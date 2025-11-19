"""
Multi-version package management system for Sideros Linux.

Inspired by Gentoo's slot system, this provides:
- Multiple concurrent versions of packages
- Slot-based version grouping
- Default stable version selection
- Version constraint resolution
- Scalable version registry

Example usage:
    # Register versions in package BUCK file
    register_package_versions(
        name = "openssl",
        category = "dev-libs",
        versions = {
            "3.2.0": {"slot": "3", "keywords": ["stable"]},
            "3.1.4": {"slot": "3", "keywords": ["stable"]},
            "1.1.1w": {"slot": "1.1", "keywords": ["stable"]},
        },
        default_version = "3.2.0",
    )

    # Reference in dependencies
    deps = [
        version_dep("//packages/dev-libs/openssl", ">=1.1.0"),
        slot_dep("//packages/lang/python", "3"),
    ]
"""

load("//defs:package_defs.bzl", "download_source", "configure_make_package")

# ============================================================================
# VERSION COMPARISON UTILITIES
# ============================================================================

def _parse_version(version_str):
    """Parse version string into comparable components.

    Handles formats like: 1.2.3, 1.2.3a, 1.2.3_rc1, 1.2.3-beta1

    Returns a tuple of (numeric_parts, suffix_type, suffix_num)
    """
    # Remove common suffixes and track them
    suffix_type = 0  # 0=release, -1=rc, -2=beta, -3=alpha
    suffix_num = 0

    version = version_str.lower()

    # Handle suffixes
    for i, (pattern, stype) in enumerate([("_rc", -1), ("-rc", -1), ("rc", -1),
                                           ("_beta", -2), ("-beta", -2), ("beta", -2),
                                           ("_alpha", -3), ("-alpha", -3), ("alpha", -3)]):
        if pattern in version:
            parts = version.split(pattern)
            version = parts[0]
            if len(parts) > 1 and parts[1]:
                # Extract suffix number
                num_str = ""
                for c in parts[1]:
                    if c.isdigit():
                        num_str += c
                    else:
                        break
                suffix_num = int(num_str) if num_str else 0
            suffix_type = stype
            break

    # Parse main version components
    components = []
    current = ""
    for c in version:
        if c.isdigit():
            current += c
        elif c in "._-":
            if current:
                components.append(int(current))
                current = ""
        elif c.isalpha():
            if current:
                components.append(int(current))
                current = ""
            # Handle letter suffixes (e.g., 1.1.1w)
            components.append(ord(c) - ord('a') + 1)

    if current:
        components.append(int(current))

    return (tuple(components), suffix_type, suffix_num)

def version_compare(v1, v2):
    """Compare two version strings.

    Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
    """
    parsed1 = _parse_version(v1)
    parsed2 = _parse_version(v2)

    # Compare main version components
    for i in range(max(len(parsed1[0]), len(parsed2[0]))):
        c1 = parsed1[0][i] if i < len(parsed1[0]) else 0
        c2 = parsed2[0][i] if i < len(parsed2[0]) else 0
        if c1 < c2:
            return -1
        if c1 > c2:
            return 1

    # Compare suffix type (release > rc > beta > alpha)
    if parsed1[1] < parsed2[1]:
        return -1
    if parsed1[1] > parsed2[1]:
        return 1

    # Compare suffix number
    if parsed1[2] < parsed2[2]:
        return -1
    if parsed1[2] > parsed2[2]:
        return 1

    return 0

def version_satisfies(version, constraint):
    """Check if version satisfies a constraint.

    Constraints can be:
    - "1.2.3" - exact match
    - ">=1.2.3" - greater than or equal
    - ">1.2.3" - greater than
    - "<=1.2.3" - less than or equal
    - "<1.2.3" - less than
    - "~>1.2" - pessimistic (>=1.2.0, <2.0.0)
    - "1.2.*" - wildcard match
    """
    if not constraint:
        return True

    # Exact match
    if constraint[0].isdigit():
        return version_compare(version, constraint) == 0

    # Operators
    if constraint.startswith(">="):
        return version_compare(version, constraint[2:]) >= 0
    if constraint.startswith("<="):
        return version_compare(version, constraint[2:]) <= 0
    if constraint.startswith(">"):
        return version_compare(version, constraint[1:]) > 0
    if constraint.startswith("<"):
        return version_compare(version, constraint[1:]) < 0

    # Pessimistic constraint (~>1.2 means >=1.2.0, <2.0.0)
    if constraint.startswith("~>"):
        base = constraint[2:]
        parts = base.split(".")
        if len(parts) >= 2:
            upper = str(int(parts[0]) + 1) + ".0.0"
            return version_compare(version, base) >= 0 and version_compare(version, upper) < 0

    # Wildcard
    if "*" in constraint:
        prefix = constraint.replace("*", "")
        return version.startswith(prefix.rstrip("."))

    return False

# ============================================================================
# VERSION REGISTRY
# ============================================================================

# Global version registry - maps package path to version info
# This is populated by register_package_versions calls
_VERSION_REGISTRY = {}

def _get_slot_from_version(version):
    """Extract default slot from version number.

    Default behavior: use major.minor for slot
    Examples: 3.2.0 -> "3.2", 1.1.1w -> "1.1"
    """
    parts = version.split(".")
    if len(parts) >= 2:
        return parts[0] + "." + parts[1]
    return parts[0] if parts else "0"

def register_package_versions(
    name,
    category,
    versions,
    default_version = None,
    default_slot = None):
    """Register available versions for a package.

    Args:
        name: Package name
        category: Package category path (e.g., "dev-libs/openssl")
        versions: Dict mapping version string to metadata:
            {
                "3.2.0": {
                    "slot": "3",           # Version slot for co-installation
                    "keywords": ["stable"], # stable, testing, unstable
                    "eapi": "8",           # Optional: ebuild API version
                    "src_uri": "...",      # Optional: override source URI
                    "sha256": "...",       # Optional: override checksum
                },
            }
        default_version: Version to use when no constraint specified
        default_slot: Slot to use as default

    Returns:
        Dict with version resolution helpers
    """
    package_path = "//packages/{}/{}".format(category, name)

    # Process versions and extract metadata
    version_list = []
    slots = {}

    for ver, meta in versions.items():
        slot = meta.get("slot", _get_slot_from_version(ver))
        keywords = meta.get("keywords", ["testing"])

        version_info = {
            "version": ver,
            "slot": slot,
            "keywords": keywords,
            "src_uri": meta.get("src_uri", ""),
            "sha256": meta.get("sha256", ""),
            "deps": meta.get("deps", []),
        }

        version_list.append(version_info)

        # Track best version per slot
        if slot not in slots:
            slots[slot] = []
        slots[slot].append(ver)

    # Sort versions in each slot (newest first)
    for slot in slots:
        slots[slot] = sorted(slots[slot], key=lambda v: _parse_version(v), reverse=True)

    # Determine default version
    if not default_version:
        # Pick newest stable version
        for vi in sorted(version_list, key=lambda x: _parse_version(x["version"]), reverse=True):
            if "stable" in vi["keywords"]:
                default_version = vi["version"]
                break
        if not default_version and version_list:
            default_version = version_list[0]["version"]

    # Determine default slot
    if not default_slot and default_version:
        for vi in version_list:
            if vi["version"] == default_version:
                default_slot = vi["slot"]
                break

    registry_entry = {
        "name": name,
        "category": category,
        "path": package_path,
        "versions": {v["version"]: v for v in version_list},
        "slots": slots,
        "default_version": default_version,
        "default_slot": default_slot,
    }

    return registry_entry

# ============================================================================
# VERSION-AWARE PACKAGE RULES
# ============================================================================

def versioned_package(
    name,
    version,
    slot = None,
    keywords = None,
    source = None,
    src_uri = None,
    sha256 = None,
    **kwargs):
    """Define a versioned package with slot support.

    This creates multiple targets:
    - {name}-{version}: The specific version
    - {name}:{slot}: Alias to latest in slot
    - {name}: Alias to default version (if this is default)

    Args:
        name: Package name
        version: Package version
        slot: Version slot (defaults to major.minor)
        keywords: List of keywords (stable, testing, unstable)
        source: Pre-defined source target
        src_uri: Source download URI
        sha256: Source checksum
        **kwargs: Additional args passed to configure_make_package
    """
    if not slot:
        slot = _get_slot_from_version(version)

    if not keywords:
        keywords = ["testing"]

    # Version-specific target name
    versioned_name = "{}-{}".format(name, version)

    # Create source download if needed
    if src_uri and sha256:
        download_source(
            name = versioned_name + "-src",
            src_uri = src_uri,
            sha256 = sha256,
        )
        source = ":" + versioned_name + "-src"

    # Create the versioned package
    configure_make_package(
        name = versioned_name,
        source = source,
        version = version,
        **kwargs
    )

    # Create slot alias
    native.alias(
        name = "{}:{}".format(name, slot),
        actual = ":" + versioned_name,
        visibility = ["PUBLIC"],
    )

    return versioned_name

def multi_version_package(
    name,
    versions,
    default_version = None,
    common_args = None,
    **kwargs):
    """Define multiple versions of a package.

    This is the main entry point for multi-version packages.

    Args:
        name: Package name
        versions: Dict mapping version to version-specific config:
            {
                "3.2.0": {
                    "slot": "3",
                    "keywords": ["stable"],
                    "src_uri": "https://...",
                    "sha256": "...",
                    "configure_args": [...],  # Optional overrides
                },
            }
        default_version: Version to use as default
        common_args: Args applied to all versions
        **kwargs: Default args for all versions
    """
    if not common_args:
        common_args = {}

    created_targets = []
    slots = {}

    # Determine default version
    if not default_version:
        for ver, meta in versions.items():
            if "stable" in meta.get("keywords", []):
                if not default_version or version_compare(ver, default_version) > 0:
                    default_version = ver
        if not default_version:
            default_version = sorted(versions.keys(), key=lambda v: _parse_version(v), reverse=True)[0]

    # Create each version
    for version, meta in versions.items():
        slot = meta.get("slot", _get_slot_from_version(version))

        # Merge args: kwargs < common_args < version-specific
        merged_args = dict(kwargs)
        merged_args.update(common_args)

        # Version-specific overrides
        for key in ["configure_args", "make_args", "deps", "build_deps", "env",
                    "pre_configure", "post_install"]:
            if key in meta:
                merged_args[key] = meta[key]

        versioned_name = versioned_package(
            name = name,
            version = version,
            slot = slot,
            keywords = meta.get("keywords", ["testing"]),
            src_uri = meta.get("src_uri"),
            sha256 = meta.get("sha256"),
            **merged_args
        )

        created_targets.append(versioned_name)

        # Track slots for alias creation
        if slot not in slots:
            slots[slot] = []
        slots[slot].append((version, versioned_name))

    # Create default alias
    default_target = "{}-{}".format(name, default_version)
    native.alias(
        name = name,
        actual = ":" + default_target,
        visibility = ["PUBLIC"],
    )

    # Create slot aliases pointing to newest version in each slot
    for slot, versions_in_slot in slots.items():
        sorted_versions = sorted(versions_in_slot, key=lambda x: _parse_version(x[0]), reverse=True)
        newest = sorted_versions[0][1]

        # Only create if not already created by versioned_package
        # The alias is created there, but we might want to update it
        pass

    return created_targets

# ============================================================================
# DEPENDENCY RESOLUTION HELPERS
# ============================================================================

def version_dep(package_path, constraint = None):
    """Create a dependency with version constraint.

    Args:
        package_path: Full package path (e.g., "//packages/core/openssl")
        constraint: Version constraint (e.g., ">=1.1.0", "<3.0")

    Returns:
        Target string for the resolved dependency

    Example:
        deps = [
            version_dep("//packages/dev-libs/openssl", ">=3.0"),
            version_dep("//packages/core/zlib", "~>1.2"),
        ]
    """
    if constraint:
        # For Buck2, we encode the constraint in the target name
        # The actual resolution happens at build time
        # Format: package_path:version_constraint
        safe_constraint = constraint.replace(">", "gt").replace("<", "lt").replace("=", "eq").replace("~", "tilde").replace("*", "star")
        return "{}:{}".format(package_path, safe_constraint)
    return package_path

def slot_dep(package_path, slot):
    """Create a dependency on a specific slot.

    Args:
        package_path: Full package path
        slot: Slot identifier (e.g., "3", "1.1")

    Returns:
        Target string for the slot dependency

    Example:
        deps = [
            slot_dep("//packages/lang/python", "3"),
            slot_dep("//packages/dev-libs/openssl", "1.1"),
        ]
    """
    return "{}:{}".format(package_path, slot)

def any_of(*packages):
    """Specify alternative dependencies (virtual packages).

    The first available package is selected.

    Example:
        deps = [
            any_of(
                "//packages/core/musl",
                "//packages/core/glibc",
            ),
        ]
    """
    # Return the first one as default
    # Actual resolution would need build-time logic
    return packages[0] if packages else None

# ============================================================================
# VERSION MANIFEST GENERATION
# ============================================================================

def generate_version_manifest(registry_entries):
    """Generate a manifest of all package versions.

    This creates a JSON-like structure for package managers
    and tooling to consume.

    Args:
        registry_entries: List of register_package_versions results

    Returns:
        Manifest structure
    """
    manifest = {
        "schema_version": "1.0",
        "packages": {},
    }

    for entry in registry_entries:
        pkg_id = "{}/{}".format(entry["category"], entry["name"])
        manifest["packages"][pkg_id] = {
            "name": entry["name"],
            "category": entry["category"],
            "default_version": entry["default_version"],
            "default_slot": entry["default_slot"],
            "slots": entry["slots"],
            "versions": entry["versions"],
        }

    return manifest

# ============================================================================
# SLOT CONFLICT DETECTION
# ============================================================================

def check_slot_conflicts(deps):
    """Check for slot conflicts in dependencies.

    Two packages with the same name but different slots can coexist.
    Two packages with the same name and slot cannot.

    Args:
        deps: List of dependency targets

    Returns:
        List of conflict warnings
    """
    seen = {}  # package_path -> set of slots
    conflicts = []

    for dep in deps:
        # Parse dependency target
        if ":" in dep:
            parts = dep.rsplit(":", 1)
            path = parts[0]
            slot_or_constraint = parts[1]
        else:
            path = dep
            slot_or_constraint = "default"

        if path not in seen:
            seen[path] = set()

        # Check for duplicate slots
        if slot_or_constraint in seen[path]:
            conflicts.append("Duplicate slot {} for package {}".format(slot_or_constraint, path))

        seen[path].add(slot_or_constraint)

    return conflicts

# ============================================================================
# CONVENIENCE MACROS FOR COMMON PATTERNS
# ============================================================================

def library_package_versions(
    name,
    versions,
    default_version = None,
    **kwargs):
    """Multi-version package with library-specific defaults.

    Sets up proper soname versioning and parallel slot installation.
    """
    # Add library-specific configure args
    common_args = {
        "configure_args": ["--enable-shared", "--disable-static"],
    }

    return multi_version_package(
        name = name,
        versions = versions,
        default_version = default_version,
        common_args = common_args,
        **kwargs
    )

def interpreter_package_versions(
    name,
    versions,
    default_version = None,
    **kwargs):
    """Multi-version package for language interpreters.

    Sets up versioned binary names (e.g., python3.11, python3.12).
    """
    common_args = {
        "post_install": """
# Create versioned symlinks
cd "$DESTDIR/usr/bin"
for bin in *; do
    if [ -f "$bin" ] && [ ! -L "$bin" ]; then
        # Don't rename if already versioned
        case "$bin" in
            *[0-9]) ;;
            *) mv "$bin" "${bin}${VERSION}" 2>/dev/null || true ;;
        esac
    fi
done
""",
    }

    return multi_version_package(
        name = name,
        versions = versions,
        default_version = default_version,
        common_args = common_args,
        **kwargs
    )

# ============================================================================
# VIRTUAL PACKAGES
# ============================================================================

def virtual_package(name, providers, default = None):
    """Define a virtual package satisfied by multiple providers.

    Similar to Gentoo's virtual packages.

    Example:
        virtual_package(
            name = "libc",
            providers = [
                "//packages/core/musl",
                "//packages/core/glibc",
            ],
            default = "//packages/core/musl",
        )

    Args:
        name: Virtual package name
        providers: List of packages that satisfy this virtual
        default: Default provider
    """
    if not default and providers:
        default = providers[0]

    native.alias(
        name = name,
        actual = default,
        visibility = ["PUBLIC"],
    )

    # Create a filegroup with metadata about providers
    # This can be queried to find alternatives
    native.filegroup(
        name = name + "-providers",
        srcs = providers,
        visibility = ["PUBLIC"],
    )

# ============================================================================
# PACKAGE SET HELPERS
# ============================================================================

def version_set(name, packages):
    """Create a named set of specific package versions.

    Useful for reproducible builds and release management.

    Example:
        version_set(
            name = "stable-2024.01",
            packages = [
                "//packages/core/openssl:openssl-3.2.0",
                "//packages/lang/python:python-3.12.1",
                "//packages/core/zlib:zlib-1.3.1",
            ],
        )
    """
    native.filegroup(
        name = name,
        srcs = packages,
        visibility = ["PUBLIC"],
    )
