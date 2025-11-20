"""
Package Set system for BuckOs Linux Distribution.

Similar to Gentoo's system profiles and package sets, this provides:
- Predefined package collections for common use cases
- System profiles (minimal, server, desktop, developer, embedded)
- Hierarchical set inheritance
- Integration with USE flag profiles
- Package set operations (union, intersection, difference)

Example usage:
    # Use a predefined system profile
    system_set(
        name = "my-server",
        profile = "server",
        additions = ["//packages/linux/net-vpn:wireguard-tools"],
        removals = ["//packages/linux/editors:emacs"],
    )

    # Create a custom package set
    package_set(
        name = "web-development",
        packages = [
            "//packages/linux/lang/nodejs",
            "//packages/linux/lang/python",
            "//packages/linux/editors:neovim",
        ],
        inherits = ["@base"],
    )

    # Combine sets
    combined_set(
        name = "full-stack",
        sets = ["@web-development", "@database-tools"],
    )
"""

load("//defs:use_flags.bzl", "USE_PROFILES")

# =============================================================================
# CORE SYSTEM PACKAGES (@system equivalent)
# =============================================================================

# Absolute minimum for a bootable system
SYSTEM_PACKAGES = [
    "//packages/linux/core:musl",
    "//packages/linux/core:busybox",
    "//packages/linux/core:util-linux",
    "//packages/linux/core:zlib",
]

# Base packages that should be in almost every installation
BASE_PACKAGES = SYSTEM_PACKAGES + [
    # Core libraries
    "//packages/linux/core:readline",
    "//packages/linux/core:ncurses",
    "//packages/linux/core:less",
    "//packages/linux/core:libffi",
    "//packages/linux/core:expat",

    # Shell and terminal
    "//packages/linux/shells:bash",

    # Compression
    "//packages/linux/core:bzip2",
    "//packages/linux/core:xz",
    "//packages/linux/system/libs/compression/gzip:gzip",
    "//packages/linux/system/apps/tar:tar",

    # System utilities
    "//packages/linux/system/apps:coreutils",
    "//packages/linux/system/apps:findutils",
    "//packages/linux/core:procps-ng",
    "//packages/linux/core:file",
    "//packages/linux/system/apps/shadow:shadow",

    # Networking basics
    "//packages/linux/network:openssl",
    "//packages/linux/network:curl",
    "//packages/linux/network:iproute2",
    "//packages/linux/network:dhcpcd",
]

# =============================================================================
# PROFILE-BASED PACKAGE SETS
# =============================================================================

# Maps profile names to their package sets
PROFILE_PACKAGE_SETS = {
    # Minimal - Bare essentials only
    "minimal": {
        "description": "Absolute minimum packages for a bootable system",
        "packages": SYSTEM_PACKAGES + [
            "//packages/linux/shells:bash",
            "//packages/linux/core:readline",
            "//packages/linux/core:ncurses",
        ],
        "inherits": [],
        "use_profile": "minimal",
    },

    # Server - Headless server configuration
    "server": {
        "description": "Server-optimized package set without GUI",
        "packages": BASE_PACKAGES + [
            # Remote access
            "//packages/linux/network:openssh",

            # Editors
            "//packages/linux/editors:vim",

            # System administration
            "//packages/linux/system/apps:sudo",
            "//packages/linux/system/apps:tmux",
            "//packages/linux/system/apps:htop",
            "//packages/linux/system/apps:rsync",
            "//packages/linux/system/apps:logrotate",
            "//packages/linux/system/apps:cronie",
            "//packages/linux/system/apps:lsof",
            "//packages/linux/system/apps:strace",

            # Init system
            "//packages/linux/system/init:systemd",

            # Documentation
            "//packages/linux/system/docs:man-db",
            "//packages/linux/system/docs:man-pages",
        ],
        "inherits": [],
        "use_profile": "server",
    },

    # Desktop - Full desktop environment
    "desktop": {
        "description": "Full desktop environment with multimedia support",
        "packages": BASE_PACKAGES + [
            # Remote access
            "//packages/linux/network:openssh",

            # Editors
            "//packages/linux/editors:vim",
            "//packages/linux/editors:neovim",

            # System administration
            "//packages/linux/system/apps:sudo",
            "//packages/linux/system/apps:tmux",
            "//packages/linux/system/apps:htop",
            "//packages/linux/system/apps:rsync",
            "//packages/linux/system/apps:logrotate",
            "//packages/linux/system/apps:cronie",

            # Shells
            "//packages/linux/shells:zsh",

            # Terminals
            "//packages/linux/terminals:alacritty",
            "//packages/linux/terminals:foot",

            # Init system
            "//packages/linux/system/init:systemd",

            # Documentation
            "//packages/linux/system/docs:man-db",
            "//packages/linux/system/docs:man-pages",
            "//packages/linux/system/docs:texinfo",

            # Internationalization
            "//packages/linux/dev-libs/misc/gettext:gettext",
        ],
        "inherits": [],
        "use_profile": "desktop",
    },

    # Developer - Development tools and languages
    "developer": {
        "description": "Development-focused with languages, tools, and documentation",
        "packages": BASE_PACKAGES + [
            # Remote access
            "//packages/linux/network:openssh",

            # Editors
            "//packages/linux/editors:vim",
            "//packages/linux/editors:neovim",
            "//packages/linux/editors:emacs",

            # Shells
            "//packages/linux/shells:zsh",

            # System administration
            "//packages/linux/system/apps:sudo",
            "//packages/linux/system/apps:tmux",
            "//packages/linux/system/apps:htop",
            "//packages/linux/system/apps:rsync",
            "//packages/linux/system/apps:strace",
            "//packages/linux/system/apps:lsof",

            # Init system
            "//packages/linux/system/init:systemd",

            # Documentation
            "//packages/linux/system/docs:man-db",
            "//packages/linux/system/docs:man-pages",
            "//packages/linux/system/docs:texinfo",
            "//packages/linux/system/docs:groff",
        ],
        "inherits": [],
        "use_profile": "developer",
    },

    # Hardened - Security-focused system
    "hardened": {
        "description": "Security-hardened configuration with minimal attack surface",
        "packages": BASE_PACKAGES + [
            # Remote access (required for server management)
            "//packages/linux/network:openssh",

            # Minimal editor
            "//packages/linux/editors:vim",

            # System administration
            "//packages/linux/system/apps:sudo",
            "//packages/linux/system/apps:htop",
            "//packages/linux/system/apps:rsync",
            "//packages/linux/system/apps:logrotate",

            # Init system
            "//packages/linux/system/init:systemd",

            # VPN for secure communications
            "//packages/linux/net-vpn:wireguard-tools",
        ],
        "inherits": [],
        "use_profile": "hardened",
    },

    # Embedded - Minimal footprint for embedded systems
    "embedded": {
        "description": "Minimal footprint for embedded and IoT systems",
        "packages": SYSTEM_PACKAGES + [
            "//packages/linux/shells:dash",  # Smaller than bash
            "//packages/linux/core:readline",
            "//packages/linux/network:dropbear",  # Smaller SSH
        ],
        "inherits": [],
        "use_profile": "minimal",
    },

    # Container - Optimized for container base images
    "container": {
        "description": "Minimal base for container images",
        "packages": SYSTEM_PACKAGES + [
            "//packages/linux/shells:bash",
            "//packages/linux/core:readline",
            "//packages/linux/core:ncurses",
            "//packages/linux/network:curl",
        ],
        "inherits": [],
        "use_profile": "minimal",
    },
}

# =============================================================================
# TASK-SPECIFIC PACKAGE SETS
# =============================================================================

TASK_PACKAGE_SETS = {
    # Web server
    "web-server": {
        "description": "Packages for running a web server",
        "packages": [
            "//packages/linux/www-servers:nginx",
        ],
        "inherits": ["server"],
    },

    # Database server
    "database-server": {
        "description": "Database server packages",
        "packages": [
            "//packages/linux/dev-db:postgresql",
            "//packages/linux/dev-db:sqlite",
        ],
        "inherits": ["server"],
    },

    # Container host
    "container-host": {
        "description": "Host system for running containers",
        "packages": [
            "//packages/linux/system/containers:podman-full",
            "//packages/linux/system/containers:buildah",
            "//packages/linux/system/containers:skopeo",
        ],
        "inherits": ["server"],
    },

    # Virtualization host
    "virtualization-host": {
        "description": "Host system for virtual machines",
        "packages": [
            "//packages/linux/emulation/hypervisors/qemu:qemu",
            "//packages/linux/emulation/virtualization/libvirt:libvirt",
        ],
        "inherits": ["server"],
    },

    # VPN server
    "vpn-server": {
        "description": "VPN server packages",
        "packages": [
            "//packages/linux/net-vpn:wireguard-tools",
            "//packages/linux/net-vpn:openvpn",
            "//packages/linux/net-vpn:strongswan",
        ],
        "inherits": ["server"],
    },

    # Monitoring
    "monitoring": {
        "description": "System monitoring and observability tools",
        "packages": [
            "//packages/linux/system/apps:htop",
            "//packages/linux/system/apps:lsof",
            "//packages/linux/system/apps:strace",
        ],
        "inherits": ["server"],
    },

    # Benchmarking
    "benchmarking": {
        "description": "Performance testing and benchmarking tools",
        "packages": [
            "//packages/linux/benchmarks:stress-ng",
            "//packages/linux/benchmarks:fio",
            "//packages/linux/benchmarks:sysbench",
            "//packages/linux/benchmarks:iperf3",
            "//packages/linux/benchmarks:hackbench",
            "//packages/linux/benchmarks:memtester",
        ],
        "inherits": ["server"],
    },
}

# =============================================================================
# DESKTOP ENVIRONMENT SETS
# =============================================================================

DESKTOP_ENVIRONMENT_SETS = {
    # GNOME
    "gnome-desktop": {
        "description": "GNOME desktop environment",
        "packages": [
            "//packages/linux/desktop:gnome",
        ],
        "inherits": ["desktop"],
    },

    # KDE Plasma
    "kde-desktop": {
        "description": "KDE Plasma desktop environment",
        "packages": [
            "//packages/linux/desktop:kde-plasma",
        ],
        "inherits": ["desktop"],
    },

    # XFCE
    "xfce-desktop": {
        "description": "XFCE lightweight desktop environment",
        "packages": [
            "//packages/linux/desktop:xfce",
        ],
        "inherits": ["desktop"],
    },

    # Sway (Wayland tiling)
    "sway-desktop": {
        "description": "Sway Wayland compositor with tiling",
        "packages": [
            "//packages/linux/desktop:sway-desktop",
        ],
        "inherits": ["desktop"],
    },

    # Hyprland (Wayland tiling)
    "hyprland-desktop": {
        "description": "Hyprland Wayland compositor",
        "packages": [
            "//packages/linux/desktop:hyprland-desktop",
        ],
        "inherits": ["desktop"],
    },

    # i3 (X11 tiling)
    "i3-desktop": {
        "description": "i3 X11 tiling window manager",
        "packages": [
            "//packages/linux/desktop:i3-desktop",
        ],
        "inherits": ["desktop"],
    },
}

# =============================================================================
# COMBINED REGISTRY
# =============================================================================

PACKAGE_SETS = {}
PACKAGE_SETS.update(PROFILE_PACKAGE_SETS)
PACKAGE_SETS.update(TASK_PACKAGE_SETS)
PACKAGE_SETS.update(DESKTOP_ENVIRONMENT_SETS)

# =============================================================================
# PACKAGE SET OPERATIONS
# =============================================================================

def _resolve_set_packages(set_name, visited = None):
    """Recursively resolve all packages in a set including inherited sets.

    Args:
        set_name: Name of the package set
        visited: Set of already visited sets (for cycle detection)

    Returns:
        List of all package targets in the set
    """
    if visited == None:
        visited = []

    # Cycle detection
    if set_name in visited:
        fail("Circular inheritance detected in package set: {}".format(set_name))

    # Handle @ prefix for set references
    actual_name = set_name[1:] if set_name.startswith("@") else set_name

    if actual_name not in PACKAGE_SETS:
        fail("Unknown package set: {}".format(actual_name))

    set_info = PACKAGE_SETS[actual_name]
    visited = visited + [set_name]

    # Start with inherited packages
    packages = []
    for inherited in set_info.get("inherits", []):
        packages.extend(_resolve_set_packages(inherited, visited))

    # Add this set's packages
    packages.extend(set_info.get("packages", []))

    # Remove duplicates while preserving order
    seen = {}
    result = []
    for pkg in packages:
        if pkg not in seen:
            seen[pkg] = True
            result.append(pkg)

    return result

def get_set_packages(set_name):
    """Get all packages in a set including inherited packages.

    Args:
        set_name: Name of the package set (with or without @ prefix)

    Returns:
        List of package targets
    """
    return _resolve_set_packages(set_name)

def get_set_info(set_name):
    """Get information about a package set.

    Args:
        set_name: Name of the package set

    Returns:
        Dict with set information or None
    """
    actual_name = set_name[1:] if set_name.startswith("@") else set_name
    return PACKAGE_SETS.get(actual_name)

def list_all_sets():
    """Get list of all available package sets.

    Returns:
        Sorted list of set names
    """
    return sorted(PACKAGE_SETS.keys())

def list_sets_by_type(set_type):
    """Get list of package sets by type.

    Args:
        set_type: "profile", "task", or "desktop"

    Returns:
        List of set names
    """
    if set_type == "profile":
        return sorted(PROFILE_PACKAGE_SETS.keys())
    elif set_type == "task":
        return sorted(TASK_PACKAGE_SETS.keys())
    elif set_type == "desktop":
        return sorted(DESKTOP_ENVIRONMENT_SETS.keys())
    else:
        return []

# =============================================================================
# SET ARITHMETIC OPERATIONS
# =============================================================================

def union_sets(*set_names):
    """Compute union of multiple package sets.

    Args:
        *set_names: Names of package sets to union

    Returns:
        List of unique package targets
    """
    packages = []
    for name in set_names:
        packages.extend(get_set_packages(name))

    # Remove duplicates
    seen = {}
    result = []
    for pkg in packages:
        if pkg not in seen:
            seen[pkg] = True
            result.append(pkg)

    return result

def intersection_sets(*set_names):
    """Compute intersection of multiple package sets.

    Args:
        *set_names: Names of package sets to intersect

    Returns:
        List of package targets common to all sets
    """
    if not set_names:
        return []

    # Start with first set
    result_set = set(get_set_packages(set_names[0]))

    # Intersect with remaining sets
    for name in set_names[1:]:
        result_set = result_set & set(get_set_packages(name))

    return sorted(list(result_set))

def difference_sets(base_set, *remove_sets):
    """Compute difference (base - others) of package sets.

    Args:
        base_set: Name of base package set
        *remove_sets: Names of sets to subtract

    Returns:
        List of package targets in base but not in remove sets
    """
    result_set = set(get_set_packages(base_set))

    for name in remove_sets:
        result_set = result_set - set(get_set_packages(name))

    return sorted(list(result_set))

# =============================================================================
# PACKAGE SET MACROS
# =============================================================================

def package_set(
        name,
        packages = [],
        inherits = [],
        description = "",
        visibility = ["PUBLIC"]):
    """Create a custom package set as a filegroup.

    Args:
        name: Name of the package set
        packages: List of package targets to include
        inherits: List of set names to inherit from (use @name format)
        description: Human-readable description
        visibility: Buck visibility specification

    Example:
        package_set(
            name = "my-tools",
            packages = [
                "//packages/linux/editors:vim",
                "//packages/linux/system/apps:tmux",
            ],
            inherits = ["@base"],
            description = "My essential tools",
        )
    """
    # Resolve inherited packages
    all_packages = []
    for inherited in inherits:
        all_packages.extend(get_set_packages(inherited))

    # Add direct packages
    all_packages.extend(packages)

    # Remove duplicates
    seen = {}
    unique_packages = []
    for pkg in all_packages:
        if pkg not in seen:
            seen[pkg] = True
            unique_packages.append(pkg)

    native.filegroup(
        name = name,
        srcs = unique_packages,
        visibility = visibility,
    )

def system_set(
        name,
        profile,
        additions = [],
        removals = [],
        description = "",
        visibility = ["PUBLIC"]):
    """Create a system set based on a profile with customizations.

    This is the primary way to create a complete system configuration.

    Args:
        name: Name of the system set
        profile: Base profile (minimal, server, desktop, developer, hardened, embedded, container)
        additions: Additional packages to include
        removals: Packages to exclude from the profile
        description: Human-readable description
        visibility: Buck visibility specification

    Example:
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
            description = "Custom web server configuration",
        )
    """
    if profile not in PROFILE_PACKAGE_SETS:
        fail("Unknown profile: {}. Available: {}".format(
            profile, ", ".join(PROFILE_PACKAGE_SETS.keys())))

    # Get base profile packages
    packages = get_set_packages(profile)

    # Remove unwanted packages
    if removals:
        removal_set = set(removals)
        packages = [p for p in packages if p not in removal_set]

    # Add additional packages
    packages.extend(additions)

    # Remove duplicates
    seen = {}
    unique_packages = []
    for pkg in packages:
        if pkg not in seen:
            seen[pkg] = True
            unique_packages.append(pkg)

    native.filegroup(
        name = name,
        srcs = unique_packages,
        visibility = visibility,
    )

def combined_set(
        name,
        sets,
        additions = [],
        removals = [],
        description = "",
        visibility = ["PUBLIC"]):
    """Combine multiple package sets into one.

    Args:
        name: Name of the combined set
        sets: List of set names to combine (use @name format)
        additions: Additional packages to include
        removals: Packages to exclude
        description: Human-readable description
        visibility: Buck visibility specification

    Example:
        combined_set(
            name = "full-stack-server",
            sets = ["@web-server", "@database-server", "@container-host"],
            additions = ["//packages/linux/net-vpn:wireguard-tools"],
            description = "Complete server stack",
        )
    """
    # Union all sets
    packages = union_sets(*sets)

    # Remove unwanted packages
    if removals:
        removal_set = set(removals)
        packages = [p for p in packages if p not in removal_set]

    # Add additional packages
    packages.extend(additions)

    # Remove duplicates
    seen = {}
    unique_packages = []
    for pkg in packages:
        if pkg not in seen:
            seen[pkg] = True
            unique_packages.append(pkg)

    native.filegroup(
        name = name,
        srcs = unique_packages,
        visibility = visibility,
    )

def task_set(
        name,
        task,
        additions = [],
        removals = [],
        description = "",
        visibility = ["PUBLIC"]):
    """Create a package set based on a predefined task.

    Args:
        name: Name of the task set
        task: Task name (web-server, database-server, container-host, etc.)
        additions: Additional packages to include
        removals: Packages to exclude
        description: Human-readable description
        visibility: Buck visibility specification

    Example:
        task_set(
            name = "my-web-server",
            task = "web-server",
            additions = ["//packages/linux/net-vpn:wireguard-tools"],
            description = "Web server with VPN",
        )
    """
    if task not in TASK_PACKAGE_SETS:
        fail("Unknown task: {}. Available: {}".format(
            task, ", ".join(TASK_PACKAGE_SETS.keys())))

    packages = get_set_packages(task)

    # Remove unwanted packages
    if removals:
        removal_set = set(removals)
        packages = [p for p in packages if p not in removal_set]

    # Add additional packages
    packages.extend(additions)

    # Remove duplicates
    seen = {}
    unique_packages = []
    for pkg in packages:
        if pkg not in seen:
            seen[pkg] = True
            unique_packages.append(pkg)

    native.filegroup(
        name = name,
        srcs = unique_packages,
        visibility = visibility,
    )

def desktop_set(
        name,
        environment,
        additions = [],
        removals = [],
        description = "",
        visibility = ["PUBLIC"]):
    """Create a desktop package set.

    Args:
        name: Name of the desktop set
        environment: Desktop environment (gnome-desktop, kde-desktop, sway-desktop, etc.)
        additions: Additional packages to include
        removals: Packages to exclude
        description: Human-readable description
        visibility: Buck visibility specification

    Example:
        desktop_set(
            name = "my-gnome",
            environment = "gnome-desktop",
            additions = ["//packages/linux/editors:vscode"],
            description = "GNOME with VS Code",
        )
    """
    if environment not in DESKTOP_ENVIRONMENT_SETS:
        fail("Unknown desktop environment: {}. Available: {}".format(
            environment, ", ".join(DESKTOP_ENVIRONMENT_SETS.keys())))

    packages = get_set_packages(environment)

    # Remove unwanted packages
    if removals:
        removal_set = set(removals)
        packages = [p for p in packages if p not in removal_set]

    # Add additional packages
    packages.extend(additions)

    # Remove duplicates
    seen = {}
    unique_packages = []
    for pkg in packages:
        if pkg not in seen:
            seen[pkg] = True
            unique_packages.append(pkg)

    native.filegroup(
        name = name,
        srcs = unique_packages,
        visibility = visibility,
    )

# =============================================================================
# QUERY HELPERS
# =============================================================================

def get_profile_use_flags(profile_name):
    """Get the USE flag profile associated with a package set profile.

    Args:
        profile_name: Name of the profile

    Returns:
        USE profile name or None
    """
    if profile_name not in PROFILE_PACKAGE_SETS:
        return None

    return PROFILE_PACKAGE_SETS[profile_name].get("use_profile")

def compare_sets(set1, set2):
    """Compare two package sets.

    Args:
        set1: First set name
        set2: Second set name

    Returns:
        Dict with 'only_in_first', 'only_in_second', 'common'
    """
    packages1 = set(get_set_packages(set1))
    packages2 = set(get_set_packages(set2))

    return {
        "only_in_first": sorted(list(packages1 - packages2)),
        "only_in_second": sorted(list(packages2 - packages1)),
        "common": sorted(list(packages1 & packages2)),
    }

def set_stats():
    """Get statistics about package sets.

    Returns:
        Dict with set statistics
    """
    total_sets = len(PACKAGE_SETS)

    return {
        "total_sets": total_sets,
        "profile_sets": len(PROFILE_PACKAGE_SETS),
        "task_sets": len(TASK_PACKAGE_SETS),
        "desktop_sets": len(DESKTOP_ENVIRONMENT_SETS),
    }

# =============================================================================
# INTEGRATION WITH USE FLAGS
# =============================================================================

def get_recommended_use_flags(set_name):
    """Get recommended USE flags for a package set.

    This returns the USE flags from the associated profile.

    Args:
        set_name: Name of the package set

    Returns:
        Dict with 'enabled' and 'disabled' USE flags
    """
    actual_name = set_name[1:] if set_name.startswith("@") else set_name

    if actual_name not in PACKAGE_SETS:
        return {"enabled": [], "disabled": []}

    use_profile = PACKAGE_SETS[actual_name].get("use_profile")
    if not use_profile or use_profile not in USE_PROFILES:
        return {"enabled": [], "disabled": []}

    profile = USE_PROFILES[use_profile]
    return {
        "enabled": profile.get("enabled", []),
        "disabled": profile.get("disabled", []),
    }
