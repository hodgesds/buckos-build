# Gentoo to BuckOs Package Migration

This document tracks packages migrated from Gentoo to BuckOs as buck targets.

## Package Format

Each package entry contains:
- **Package name**: The Gentoo package name
- **Gentoo category**: Source location in Gentoo (e.g., `sys-apps/package`)
- **BuckOs path**: Location of the BUCK file
- **Status**: Migration status

---

## Section 1: Core System Utilities (sys-apps)

**BuckOs base path**: `packages/linux/system/apps/`

### Essential System Tools

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `baselayout` | sys-apps | system/apps/baselayout | Added |
| `kbd` | sys-apps | system/apps/kbd | Added |
| `kmod` | sys-apps | system/libs/kmod | Exists |
| `dbus` | sys-apps | system/libs/ipc/dbus | Exists |
| `haveged` | sys-apps | system/apps/haveged | Added |
| `pciutils` | sys-apps | system/hardware/pciutils | Exists |
| `usbutils` | sys-apps | system/hardware/usbutils | Exists |
| `systemd-utils` | sys-apps | system/apps/systemd-utils | Added |
| `iproute2` | sys-apps | network/iproute2 | Exists |
| `openrc` | sys-apps | system/init/openrc | Exists |
| `file` | sys-apps | core/file | Exists |
| `ed` | sys-apps | editors/ed | Added |
| `gawk` | sys-apps | editors/gawk | Exists |
| `grep` | sys-apps | editors/grep | Exists |
| `sed` | sys-apps | editors/sed | Exists |

### Common Admin Tools

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `lsb-release` | sys-apps | system/apps/lsb-release | Added |
| `hwdata` | sys-apps | system/hardware/hwdata | Added |
| `hwloc` | sys-apps | system/hardware/hwloc | Added |
| `ethtool` | sys-apps | network/ethtool | Added |
| `eza` | sys-apps | system/apps/eza | Pending |
| `fd` | sys-apps | system/apps/fd | Pending |
| `bat` | sys-apps | editors/bat | Exists |
| `ripgrep` | sys-apps | editors/ripgrep | Exists |
| `keyutils` | sys-apps | system/security/keyutils | Added |
| `kexec-tools` | sys-apps | system/apps/kexec-tools | Pending |
| `inxi` | sys-apps | system/apps/inxi | Added |

---

## Section 2: System Libraries (sys-libs)

**BuckOs base path**: `packages/linux/system/libs/`

### Essential Libraries

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `glibc` | sys-libs | core/glibc | Pending |
| `zlib` | sys-libs | core/zlib | Exists |
| `ncurses` | sys-libs | core/ncurses | Exists |
| `readline` | sys-libs | core/readline | Exists |
| `pam` | sys-libs | system/security/auth/pam | Added |
| `libcap` | sys-libs | system/libs/ipc/libcap | Exists |
| `libseccomp` | sys-libs | system/libs/ipc/libseccomp | Exists |
| `libunwind` | sys-libs | system/libs/libunwind | Added |
| `liburing` | sys-libs | system/libs/liburing | Added |
| `cracklib` | sys-libs | system/security/cracklib | Added |
| `gdbm` | sys-libs | system/docs/gdbm | Exists |
| `timezone-data` | sys-libs | system/libs/timezone-data | Added |

### Additional Libraries

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `slang` | sys-libs | system/libs/slang | Added |
| `talloc` | sys-libs | system/libs/talloc | Added |
| `tdb` | sys-libs | system/libs/tdb | Added |
| `tevent` | sys-libs | system/libs/tevent | Added |
| `ldb` | sys-libs | system/libs/ldb | Added |
| `efivar` | sys-libs | system/libs/efivar | Added |
| `mtdev` | sys-libs | system/libs/input/mtdev | Exists |

---

## Section 3: Archive/Compression (app-arch)

**BuckOs base path**: `packages/linux/system/libs/compression/`

### Core Compression Tools

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `tar` | app-arch | system/apps/tar | Added |
| `gzip` | app-arch | system/libs/compression/gzip | Added |
| `bzip2` | app-arch | core/bzip2 | Exists |
| `xz-utils` | app-arch | core/xz | Exists |
| `zstd` | app-arch | system/libs/compression/zstd | Exists |
| `lz4` | app-arch | system/libs/compression/lz4 | Exists |
| `p7zip` | app-arch | system/libs/compression/p7zip | Added |
| `unzip` | app-arch | system/libs/compression/unzip | Added |
| `zip` | app-arch | system/libs/compression/zip | Added |
| `cpio` | app-arch | system/libs/cpio | Exists |
| `libarchive` | app-arch | system/libs/utility/libarchive | Exists |
| `pigz` | app-arch | system/libs/compression/pigz | Added |

### Additional Compression Tools

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `lzip` | app-arch | system/libs/compression/lzip | Added |
| `lzop` | app-arch | system/libs/compression/lzop | Added |
| `rar` | app-arch | system/libs/compression/rar | Pending |
| `unrar` | app-arch | system/libs/compression/unrar | Added |
| `cabextract` | app-arch | system/libs/compression/cabextract | Added |
| `arj` | app-arch | system/libs/compression/arj | Added |
| `pbzip2` | app-arch | system/libs/compression/pbzip2 | Added |
| `pixz` | app-arch | system/libs/compression/pixz | Added |

---

## Section 4: Network Analysis Tools (net-analyzer)

**BuckOs base path**: `packages/linux/network/`

### Core Network Tools

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `nmap` | net-analyzer | network/nmap | Exists |
| `tcpdump` | net-analyzer | network/tcpdump | Exists |
| `wireshark` | net-analyzer | network/wireshark | Added |
| `iftop` | net-analyzer | network/iftop | Exists |
| `nethogs` | net-analyzer | network/nethogs | Added |
| `iperf` | net-analyzer | network/iperf | Added |
| `netcat` | net-analyzer | network/netcat | Exists |
| `traceroute` | net-analyzer | network/traceroute | Added |
| `mtr` | net-analyzer | network/mtr | Exists |
| `arping` | net-analyzer | network/arping | Exists |
| `fail2ban` | net-analyzer | system/security/fail2ban | Exists |

### Monitoring and Security

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `nagios` | net-analyzer | network/monitoring/nagios | Added |
| `zabbix` | net-analyzer | network/monitoring/zabbix | Added |
| `netdata` | net-analyzer | network/monitoring/netdata | Added |
| `snort` | net-analyzer | network/security/snort | Added |
| `suricata` | net-analyzer | network/security/suricata | Added |
| `hydra` | net-analyzer | network/security/hydra | Added |
| `nikto` | net-analyzer | network/security/nikto | Added |
| `speedtest-cli` | net-analyzer | network/speedtest-cli | Added |
| `ntopng` | net-analyzer | network/monitoring/ntopng | Added |
| `arpwatch` | net-analyzer | network/arpwatch | Added |

---

## Section 5: Development Utilities (dev-util)

**BuckOs base path**: `packages/linux/dev-tools/`

### Core Development Tools

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `cmake` | dev-util | dev-tools/build-systems/cmake | Exists |
| `meson` | dev-util | dev-tools/build-systems/meson | Exists |
| `ninja` | dev-util | dev-tools/build-systems/ninja | Exists |
| `gdb` | dev-util | dev-tools/debuggers/gdb | Exists |
| `valgrind` | dev-util | dev-tools/profilers/valgrind | Exists |
| `strace` | dev-util | dev-tools/debuggers/strace | Exists |
| `ltrace` | dev-util | dev-tools/debuggers/ltrace | Exists |
| `perf` | dev-util | benchmarks/perf | Exists |
| `cscope` | dev-util | dev-tools/dev-utils/cscope | Exists |
| `ctags` | dev-util | dev-tools/dev-utils/ctags | Exists |
| `global` | dev-util | dev-tools/dev-utils/global | Exists |
| `shellcheck` | dev-util | dev-tools/dev-utils/shellcheck | Exists |

### Additional Development Tools

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `gperf` | dev-util | dev-tools/dev-utils/gperf | Added |
| `gengetopt` | dev-util | dev-tools/dev-utils/gengetopt | Added |
| `intltool` | dev-util | dev-tools/dev-utils/intltool | Added |
| `itstool` | dev-util | dev-tools/dev-utils/itstool | Added |
| `gtk-doc` | dev-util | dev-tools/dev-utils/gtk-doc | Added |
| `pkgconf` | dev-util | dev-tools/build-systems/pkgconf | Added |
| `meld` | dev-util | dev-tools/dev-utils/meld | Exists |
| `kdevelop` | dev-util | dev-tools/ide/kdevelop | Added |
| `geany` | dev-util | dev-tools/ide/geany | Added |
| `kcov` | dev-util | dev-tools/dev-utils/kcov | Added |
| `coccinelle` | dev-util | dev-tools/dev-utils/coccinelle | Added |
| `cloc` | dev-util | dev-tools/dev-utils/cloc | Added |
| `github-cli` | dev-util | dev-tools/vcs/github-cli | Added |
| `heaptrack` | dev-util | dev-tools/profilers/heaptrack | Added |

---

## Section 6: Admin Tools (app-admin)

**BuckOs base path**: `packages/linux/system/`

### Core Admin Tools

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `sudo` | app-admin | system/apps/sudo | Exists |
| `doas` | app-admin | system/apps/doas | Exists |
| `logrotate` | app-admin | system/apps/logrotate | Exists |
| `sysstat` | app-admin | system/apps/sysstat | Added |
| `sysklogd` | app-admin | system/apps/sysklogd | Added |
| `rsyslog` | app-admin | system/apps/rsyslog | Exists |
| `conky` | app-admin | desktop/conky | Added |
| `htop` | app-admin | system/apps/htop | Exists |

### Configuration Management and Security

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `ansible` | app-admin | system/admin/ansible | Added |
| `puppet` | app-admin | system/admin/puppet | Added |
| `salt` | app-admin | system/admin/salt | Added |
| `terraform` | app-admin | system/admin/terraform | Added |
| `consul` | app-admin | system/admin/consul | Added |
| `vault` | app-admin | system/admin/vault | Added |
| `keepassxc` | app-admin | system/security/keepassxc | Added |
| `pass` | app-admin | system/security/pass | Added |
| `metalog` | app-admin | system/apps/metalog | Added |
| `monit` | app-admin | system/apps/monit | Added |
| `supervisor` | app-admin | system/apps/supervisor | Added |
| `lnav` | app-admin | system/apps/lnav | Added |

---

## Section 7: Shells (app-shells)

**BuckOs base path**: `packages/linux/shells/`

### Pre-existing Shells
- bash, zsh, dash, fish, mksh

### Migrated Shells and Tools

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `tcsh` | app-shells | shells/tcsh | Added |
| `ksh` | app-shells | shells/ksh | Added |
| `nushell` | app-shells | shells/nushell | Added |
| `pwsh` | app-shells | shells/pwsh | Added |
| `rc` | app-shells | shells/rc | Added |
| `yash` | app-shells | shells/yash | Added |
| `bash-completion` | app-shells | shells/bash-completion | Added |
| `zsh-completions` | app-shells | shells/zsh-completions | Added |
| `gentoo-zsh-completions` | app-shells | shells/gentoo-zsh-completions | Added |
| `starship` | app-shells | shells/starship | Added |
| `tmux-bash-completion` | app-shells | shells/tmux-bash-completion | Added |
| `fzf` | app-shells | editors/fzf | Exists |
| `atuin` | app-shells | shells/atuin | Added |
| `zoxide` | app-shells | shells/zoxide | Added |
| `mcfly` | app-shells | shells/mcfly | Added |
| `thefuck` | app-shells | shells/thefuck | Added |

---

## Section 8: Text Processing (app-text)

**BuckOs base path**: `packages/linux/editors/` and `packages/linux/system/docs/`

### Document Processing

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `groff` | app-text | system/docs/groff | Exists |
| `ghostscript` | app-text | editors/ghostscript | Added |
| `poppler` | app-text | editors/poppler | Added |
| `mupdf` | app-text | editors/mupdf | Added |
| `zathura` | app-text | editors/zathura | Added |
| `evince` | app-text | editors/evince | Added |
| `okular` | app-text | editors/okular | Added |
| `aspell` | app-text | editors/aspell | Added |
| `hunspell` | app-text | editors/hunspell | Added |
| `enchant` | app-text | editors/enchant | Added |

### Text Utilities

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `asciidoc` | app-text | dev-tools/dev-utils/asciidoc | Exists |
| `asciidoctor` | app-text | dev-tools/dev-utils/asciidoctor | Exists |
| `dos2unix` | app-text | editors/dos2unix | Added |
| `tree` | app-text | system/apps/tree | Exists |
| `wdiff` | app-text | editors/wdiff | Added |
| `colordiff` | app-text | dev-tools/dev-utils/colordiff | Exists |
| `csvtool` | app-text | editors/csvtool | Added |
| `discount` | app-text | editors/discount | Added |
| `mdp` | app-text | editors/mdp | Added |

---

## Section 9: Databases (dev-db)

**BuckOs base path**: `packages/linux/databases/`

### Core Databases

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `sqlite` | dev-db | system/libs/database/sqlite | Exists |
| `postgresql` | dev-db | databases/postgresql | Added |
| `mariadb` | dev-db | databases/mariadb | Added |
| `redis` | dev-db | databases/redis | Added |
| `mongodb` | dev-db | databases/mongodb | Added |
| `memcached` | dev-db | databases/memcached | Added |
| `lmdb` | dev-db | system/libs/database/lmdb | Exists |

### Additional Databases

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `influxdb` | dev-db | databases/influxdb | Added |
| `couchdb` | dev-db | databases/couchdb | Added |
| `neo4j` | dev-db | databases/neo4j | Added |
| `etcd` | dev-db | databases/etcd | Added |

---

## Section 10: Web Servers (www-servers)

**BuckOs base path**: `packages/linux/www/servers/`

### Pre-existing Servers
- nginx, apache, caddy, lighttpd, haproxy, traefik

### Migrated Servers

| Package | Gentoo Category | BuckOs Path | Status |
|---------|----------------|-------------|--------|
| `tomcat` | www-servers | www/servers/tomcat | Added |
| `jetty` | www-servers | www/servers/jetty | Added |
| `varnish` | www-servers | www/servers/varnish | Added |
| `squid` | www-servers | www/servers/squid | Added |
| `pound` | www-servers | www/servers/pound | Added |

---

## Template for New Packages

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

## Adding New Packages

1. **Check Gentoo first**: Look at the ebuild for configure flags and dependencies
2. **Use latest stable version**: Check what version Gentoo marks as stable
3. **Placeholder hashes**: Use placeholder SHA256 (can be verified later)
4. **Add to filegroups**: Update relevant category BUCK files
5. **Add aliases**: Add to root BUCK if commonly used
6. **Document dependencies**: List all build and runtime deps
