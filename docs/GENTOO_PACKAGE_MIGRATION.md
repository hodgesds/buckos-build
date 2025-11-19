# Gentoo to BuckOs Package Migration Plan

This document lists packages from Gentoo that should be added as buck targets to BuckOs.
Each section can be assigned to a separate agent for parallel execution.

## How to Use This Document

Each package entry contains:
- **Package name**: The Gentoo package name
- **Gentoo category**: Where it lives in Gentoo (e.g., `sys-apps/package`)
- **Suggested BuckOs path**: Where to create the BUCK file
- **Priority**: HIGH (essential), MEDIUM (commonly used), LOW (nice to have)

Agents should:
1. Check the Gentoo repository for the latest version
2. Create the BUCK file with proper download_source and configure_make_package
3. Add to appropriate filegroups
4. Use placeholder sha256 (can be verified later)

---

## Section 1: Core System Utilities (sys-apps)

**Assign to: Agent 1**
**BuckOs base path**: `packages/linux/system/apps/`

### HIGH Priority - Essential System Tools

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `baselayout` | sys-apps | system/apps/baselayout | Already added |
| `kbd` | sys-apps | system/apps/kbd | Already added |
| `kmod` | sys-apps | system/libs/kmod | Already exists - verify |
| `dbus` | sys-apps | system/libs/ipc/dbus | Already exists - verify |
| `haveged` | sys-apps | system/apps/haveged | Already added |
| `pciutils` | sys-apps | system/hardware/pciutils | Already exists - verify |
| `usbutils` | sys-apps | system/hardware/usbutils | Already exists - verify |
| `systemd-utils` | sys-apps | system/apps/systemd-utils | Standalone systemd tools |
| `iproute2` | sys-apps | network/iproute2 | Already exists - verify |
| `openrc` | sys-apps | system/init/openrc | Already exists - verify |
| `file` | sys-apps | core/file | Already exists - verify |
| `ed` | sys-apps | editors/ed | Already added |
| `gawk` | sys-apps | editors/gawk | Already exists - verify |
| `grep` | sys-apps | editors/grep | Already exists - verify |
| `sed` | sys-apps | editors/sed | Already exists - verify |

### MEDIUM Priority - Common Admin Tools

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `lsb-release` | sys-apps | system/apps/lsb-release | Already added |
| `hwdata` | sys-apps | system/hardware/hwdata | Hardware IDs database |
| `hwloc` | sys-apps | system/hardware/hwloc | Already added |
| `ethtool` | sys-apps | network/ethtool | Ethernet config |
| `eza` | sys-apps | system/apps/eza | Modern ls replacement |
| `fd` | sys-apps | system/apps/fd | Modern find replacement |
| `bat` | sys-apps | editors/bat | Already exists - verify |
| `ripgrep` | sys-apps | editors/ripgrep | Already exists - verify |
| `keyutils` | sys-apps | system/security/keyutils | Already added |
| `kexec-tools` | sys-apps | system/apps/kexec-tools | Fast reboot |
| `inxi` | sys-apps | system/apps/inxi | Already added |

---

## Section 2: System Libraries (sys-libs)

**Assign to: Agent 2**
**BuckOs base path**: `packages/linux/system/libs/`

### HIGH Priority - Essential Libraries

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `glibc` | sys-libs | core/glibc | GNU C library (alt to musl) |
| `zlib` | sys-libs | core/zlib | Already exists |
| `ncurses` | sys-libs | core/ncurses | Already exists |
| `readline` | sys-libs | core/readline | Already exists |
| `pam` | sys-libs | system/security/auth/pam | Auth modules |
| `libcap` | sys-libs | system/libs/ipc/libcap | Already exists |
| `libseccomp` | sys-libs | system/libs/ipc/libseccomp | Already exists |
| `libunwind` | sys-libs | system/libs/libunwind | Already added |
| `liburing` | sys-libs | system/libs/liburing | Already added |
| `cracklib` | sys-libs | system/security/cracklib | Already added |
| `gdbm` | sys-libs | system/docs/gdbm | Already exists in docs |
| `timezone-data` | sys-libs | system/libs/timezone-data | Already added |

### MEDIUM Priority

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `slang` | sys-libs | system/libs/slang | Already added |
| `talloc` | sys-libs | system/libs/talloc | Already added |
| `tdb` | sys-libs | system/libs/tdb | Trivial database |
| `tevent` | sys-libs | system/libs/tevent | Event system |
| `ldb` | sys-libs | system/libs/ldb | LDAP-like database |
| `efivar` | sys-libs | system/libs/efivar | Already added |
| `mtdev` | sys-libs | system/libs/input/mtdev | Already exists |

---

## Section 3: Archive/Compression (app-arch)

**Assign to: Agent 3**
**BuckOs base path**: `packages/linux/system/libs/compression/`

### HIGH Priority

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `tar` | app-arch | system/apps/tar | Already added |
| `gzip` | app-arch | system/libs/compression/gzip | Already added |
| `bzip2` | app-arch | core/bzip2 | Already exists |
| `xz-utils` | app-arch | core/xz | Already exists |
| `zstd` | app-arch | system/libs/compression/zstd | Already exists |
| `lz4` | app-arch | system/libs/compression/lz4 | Already exists |
| `p7zip` | app-arch | system/libs/compression/p7zip | Already added |
| `unzip` | app-arch | system/libs/compression/unzip | Info-ZIP unzip |
| `zip` | app-arch | system/libs/compression/zip | Already added |
| `cpio` | app-arch | system/libs/cpio | Already exists |
| `libarchive` | app-arch | system/libs/utility/libarchive | Already exists |
| `pigz` | app-arch | system/libs/compression/pigz | Parallel gzip |

### MEDIUM Priority

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `lzip` | app-arch | system/libs/compression/lzip | Already added |
| `lzop` | app-arch | system/libs/compression/lzop | Already added |
| `rar` | app-arch | system/libs/compression/rar | RAR archiver |
| `unrar` | app-arch | system/libs/compression/unrar | RAR extractor |
| `cabextract` | app-arch | system/libs/compression/cabextract | CAB extractor |
| `arj` | app-arch | system/libs/compression/arj | ARJ archiver |
| `pbzip2` | app-arch | system/libs/compression/pbzip2 | Parallel bzip2 |
| `pixz` | app-arch | system/libs/compression/pixz | Parallel xz |

---

## Section 4: Network Analysis Tools (net-analyzer)

**Assign to: Agent 4**
**BuckOs base path**: `packages/linux/network/`

### HIGH Priority

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `nmap` | net-analyzer | network/nmap | Already exists |
| `tcpdump` | net-analyzer | network/tcpdump | Already exists |
| `wireshark` | net-analyzer | network/wireshark | Already added |
| `iftop` | net-analyzer | network/iftop | Already exists |
| `nethogs` | net-analyzer | network/nethogs | Already added |
| `iperf` | net-analyzer | network/iperf | Already added |
| `netcat` | net-analyzer | network/netcat | Already exists |
| `traceroute` | net-analyzer | network/traceroute | Already added |
| `mtr` | net-analyzer | network/mtr | Already exists |
| `arping` | net-analyzer | network/arping | Already exists |
| `fail2ban` | net-analyzer | system/security/fail2ban | Already exists |

### MEDIUM Priority

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `nagios` | net-analyzer | network/monitoring/nagios | Monitoring system |
| `zabbix` | net-analyzer | network/monitoring/zabbix | Monitoring |
| `netdata` | net-analyzer | network/monitoring/netdata | Real-time monitoring |
| `snort` | net-analyzer | network/security/snort | IDS |
| `suricata` | net-analyzer | network/security/suricata | IDS/IPS |
| `hydra` | net-analyzer | network/security/hydra | Login cracker |
| `nikto` | net-analyzer | network/security/nikto | Web scanner |
| `speedtest-cli` | net-analyzer | network/speedtest-cli | Speed test |
| `ntopng` | net-analyzer | network/monitoring/ntopng | Traffic analysis |
| `arpwatch` | net-analyzer | network/arpwatch | ARP monitor |

---

## Section 5: Development Utilities (dev-util)

**Assign to: Agent 5**
**BuckOs base path**: `packages/linux/dev-tools/`

### HIGH Priority

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `cmake` | dev-util | dev-tools/build-systems/cmake | Already exists |
| `meson` | dev-util | dev-tools/build-systems/meson | Already exists |
| `ninja` | dev-util | dev-tools/build-systems/ninja | Already exists |
| `gdb` | dev-util | dev-tools/debuggers/gdb | Already exists |
| `valgrind` | dev-util | dev-tools/profilers/valgrind | Already exists |
| `strace` | dev-util | dev-tools/debuggers/strace | Already exists |
| `ltrace` | dev-util | dev-tools/debuggers/ltrace | Already exists |
| `perf` | dev-util | benchmarks/perf | Already exists |
| `cscope` | dev-util | dev-tools/dev-utils/cscope | Already exists |
| `ctags` | dev-util | dev-tools/dev-utils/ctags | Already exists |
| `global` | dev-util | dev-tools/dev-utils/global | Already exists |
| `shellcheck` | dev-util | dev-tools/dev-utils/shellcheck | Already exists |

### MEDIUM Priority - Need to Add

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `gperf` | dev-util | dev-tools/dev-utils/gperf | Already added |
| `gengetopt` | dev-util | dev-tools/dev-utils/gengetopt | Already added |
| `intltool` | dev-util | dev-tools/dev-utils/intltool | i18n tools |
| `itstool` | dev-util | dev-tools/dev-utils/itstool | XML translation |
| `gtk-doc` | dev-util | dev-tools/dev-utils/gtk-doc | GTK documentation |
| `pkgconf` | dev-util | dev-tools/build-systems/pkgconf | Already added |
| `meld` | dev-util | dev-tools/dev-utils/meld | Already exists |
| `kdevelop` | dev-util | dev-tools/ide/kdevelop | KDE IDE |
| `geany` | dev-util | dev-tools/ide/geany | Lightweight IDE |
| `kcov` | dev-util | dev-tools/dev-utils/kcov | Code coverage |
| `coccinelle` | dev-util | dev-tools/dev-utils/coccinelle | Semantic patching |
| `cloc` | dev-util | dev-tools/dev-utils/cloc | Count lines of code |
| `github-cli` | dev-util | dev-tools/vcs/github-cli | GitHub CLI |
| `heaptrack` | dev-util | dev-tools/profilers/heaptrack | Heap profiler |

---

## Section 6: Admin Tools (app-admin)

**Assign to: Agent 6**
**BuckOs base path**: `packages/linux/system/`

### HIGH Priority

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `sudo` | app-admin | system/apps/sudo | Already exists |
| `doas` | app-admin | system/apps/doas | Already exists |
| `logrotate` | app-admin | system/apps/logrotate | Already exists |
| `sysstat` | app-admin | system/apps/sysstat | Already added |
| `sysklogd` | app-admin | system/apps/sysklogd | Already added |
| `rsyslog` | app-admin | system/apps/rsyslog | Already exists |
| `conky` | app-admin | desktop/conky | System monitor widget |
| `htop` | app-admin | system/apps/htop | Already exists |

### MEDIUM Priority - Need to Add

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `ansible` | app-admin | system/admin/ansible | Automation |
| `puppet` | app-admin | system/admin/puppet | Config management |
| `salt` | app-admin | system/admin/salt | Config management |
| `terraform` | app-admin | system/admin/terraform | Infrastructure |
| `consul` | app-admin | system/admin/consul | Service mesh |
| `vault` | app-admin | system/admin/vault | Secrets management |
| `keepassxc` | app-admin | system/security/keepassxc | Password manager |
| `pass` | app-admin | system/security/pass | Password store |
| `metalog` | app-admin | system/apps/metalog | Modern logger |
| `monit` | app-admin | system/apps/monit | Process supervisor |
| `supervisor` | app-admin | system/apps/supervisor | Process control |
| `lnav` | app-admin | system/apps/lnav | Log navigator |

---

## Section 7: Shells (app-shells)

**Assign to: Agent 7**
**BuckOs base path**: `packages/linux/shells/`

### Already Have
- bash, zsh, dash, fish, mksh

### Need to Add

| Package | Gentoo Category | BuckOs Path | Priority |
|---------|----------------|-------------|----------|
| `tcsh` | app-shells | shells/tcsh | Already added |
| `ksh` | app-shells | shells/ksh | Already added |
| `nushell` | app-shells | shells/nushell | LOW |
| `pwsh` | app-shells | shells/pwsh | LOW |
| `rc` | app-shells | shells/rc | LOW |
| `yash` | app-shells | shells/yash | LOW |
| `bash-completion` | app-shells | shells/bash-completion | HIGH |
| `zsh-completions` | app-shells | shells/zsh-completions | HIGH |
| `gentoo-zsh-completions` | app-shells | shells/gentoo-zsh-completions | LOW |
| `starship` | app-shells | shells/starship | MEDIUM |
| `tmux-bash-completion` | app-shells | shells/tmux-bash-completion | LOW |
| `fzf` | app-shells | editors/fzf | Already exists |
| `atuin` | app-shells | shells/atuin | Shell history |
| `zoxide` | app-shells | shells/zoxide | Smarter cd |
| `mcfly` | app-shells | shells/mcfly | History search |
| `thefuck` | app-shells | shells/thefuck | Command fixer |

---

## Section 8: Text Processing (app-text)

**Assign to: Agent 8**
**BuckOs base path**: `packages/linux/editors/` and `packages/linux/system/docs/`

### HIGH Priority

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `groff` | app-text | system/docs/groff | Already exists |
| `ghostscript` | app-text | editors/ghostscript | PostScript interpreter |
| `poppler` | app-text | editors/poppler | PDF library |
| `mupdf` | app-text | editors/mupdf | PDF viewer |
| `zathura` | app-text | editors/zathura | Document viewer |
| `evince` | app-text | editors/evince | GNOME doc viewer |
| `okular` | app-text | editors/okular | KDE doc viewer |
| `aspell` | app-text | editors/aspell | Already added |
| `hunspell` | app-text | editors/hunspell | Already added |
| `enchant` | app-text | editors/enchant | Spell check wrapper |

### MEDIUM Priority

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `asciidoc` | app-text | dev-tools/dev-utils/asciidoc | Already exists |
| `asciidoctor` | app-text | dev-tools/dev-utils/asciidoctor | Already exists |
| `dos2unix` | app-text | editors/dos2unix | Line ending converter |
| `tree` | app-text | system/apps/tree | Already exists |
| `wdiff` | app-text | editors/wdiff | Word diff |
| `colordiff` | app-text | dev-tools/dev-utils/colordiff | Already exists |
| `csvtool` | app-text | editors/csvtool | CSV processor |
| `discount` | app-text | editors/discount | Markdown |
| `mdp` | app-text | editors/mdp | Markdown presenter |

---

## Section 9: Databases (dev-db)

**Assign to: Agent 9**
**BuckOs base path**: `packages/linux/databases/`

### HIGH Priority - Need to Add Category

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `sqlite` | dev-db | system/libs/database/sqlite | Already exists |
| `postgresql` | dev-db | databases/postgresql | Already added |
| `mariadb` | dev-db | databases/mariadb | MySQL fork |
| `redis` | dev-db | databases/redis | Key-value store |
| `mongodb` | dev-db | databases/mongodb | Document store |
| `memcached` | dev-db | databases/memcached | Already added |
| `lmdb` | dev-db | system/libs/database/lmdb | Already exists |

### MEDIUM Priority

| Package | Gentoo Category | BuckOs Path | Notes |
|---------|----------------|-------------|-------|
| `influxdb` | dev-db | databases/influxdb | Time series |
| `couchdb` | dev-db | databases/couchdb | Document store |
| `neo4j` | dev-db | databases/neo4j | Graph database |
| `etcd` | dev-db | databases/etcd | Key-value store |

---

## Section 10: Web Servers (www-servers)

**Assign to: Agent 10**
**BuckOs base path**: `packages/linux/www/servers/`

### Already Have
- nginx, apache, caddy, lighttpd, haproxy, traefik

### Need to Add

| Package | Gentoo Category | BuckOs Path | Priority |
|---------|----------------|-------------|----------|
| `tomcat` | www-servers | www/servers/tomcat | MEDIUM |
| `jetty` | www-servers | www/servers/jetty | MEDIUM |
| `varnish` | www-servers | www/servers/varnish | Already added |
| `squid` | www-servers | www/servers/squid | HIGH |
| `pound` | www-servers | www/servers/pound | MEDIUM |

---

## Summary Statistics

### Packages by Priority

- **HIGH Priority**: ~80 packages
- **MEDIUM Priority**: ~120 packages
- **LOW Priority**: ~50 packages

### Estimated Work Per Agent

| Agent | Section | Est. Packages to Add |
|-------|---------|---------------------|
| 1 | Core System | 15-20 |
| 2 | System Libraries | 10-15 |
| 3 | Compression | 10-15 |
| 4 | Network Analysis | 15-20 |
| 5 | Dev Utilities | 15-20 |
| 6 | Admin Tools | 15-20 |
| 7 | Shells | 10-15 |
| 8 | Text Processing | 15-20 |
| 9 | Databases | 10-12 |
| 10 | Web Servers | 5-8 |

---

## Template for New Package

```python
load("//defs:package_defs.bzl", "download_source", "configure_make_package")

# package-name - Brief description
download_source(
    name = "package-name-src",
    src_uri = "https://example.com/package-X.Y.Z.tar.gz",
    sha256 = "PLACEHOLDER_HASH",
)

configure_make_package(
    name = "package-name",
    source = ":package-name-src",
    version = "X.Y.Z",
    description = "Package description",
    homepage = "https://example.com",
    license = "LICENSE",
    configure_args = [
        "--prefix=/usr",
    ],
    deps = [
        "//packages/linux/core:musl",
    ],
    visibility = ["PUBLIC"],
)
```

## Notes for Agents

1. **Check Gentoo first**: Look at the ebuild for configure flags, dependencies
2. **Use latest stable version**: Check what version Gentoo marks as stable
3. **Placeholder hashes**: Use placeholder SHA256 (can be verified later)
4. **Add to filegroups**: Update relevant category BUCK files
5. **Add aliases**: Add to root BUCK if commonly used
6. **Document dependencies**: List all build and runtime deps
