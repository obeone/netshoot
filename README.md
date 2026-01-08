# 🚀 Netshoot: Your Ultimate Network Troubleshooting Docker Image 🐳

[![Docker Pulls](https://img.shields.io/docker/pulls/obeoneorg/netshoot?style=for-the-badge&logo=docker)](https://hub.docker.com/r/obeoneorg/netshoot)
[![GitHub Stars](https://img.shields.io/github/stars/obeone/netshoot?style=for-the-badge&logo=github)](https://github.com/obeone/netshoot)
[![GitHub License](https://img.shields.io/github/license/obeone/netshoot?style=for-the-badge)](https://github.com/obeone/netshoot/blob/main/LICENSE)

**Netshoot** is a powerful, multi-tool Docker image designed for comprehensive network troubleshooting and analysis. Built on **Debian 13 Trixie** (stable), it bundles a vast collection of essential networking utilities, system tools, and multiple container runtimes into a single, convenient package.

Whether you're debugging a complex Kubernetes networking issue, analyzing traffic, or simply need a versatile toolkit, `netshoot` provides a ready-to-use, enhanced shell environment to get the job done efficiently.

---

## ✨ Key Features

- **📦 Rich Toolset**: A vast collection of networking, system, and container tools with detailed descriptions.
- **🔧 Enhanced Shell Experience**: Features **Zsh** with **Oh My Zsh**, **Powerlevel10k** theme, and plugins for auto-suggestions and syntax highlighting.
- **⚙️ Multiple Variants**: Provides specialized images with different container runtimes (**Docker**, **Podman**, **nerdctl**) to fit your needs.
- **🐍 Python Ready**: Equipped with `python3`, `pipx`, and `uv` for fast Python package management.
- **🌐 Based on Debian 13 Trixie**: A stable, modern, and secure foundation.
- **📁 Easy File Transfers**: Includes a handy `transfer.sh` script for quick file sharing.

---

## 🚀 Getting Started

The `latest` tag provides a comprehensive image with all tools but without a pre-installed container runtime to keep it lightweight.

```bash
docker pull obeoneorg/netshoot:latest
```

Launch an interactive session to start troubleshooting:

```bash
docker run -it --rm obeoneorg/netshoot
```

---

## 🏷️ Available Tags & Variants

`Netshoot` comes in several variants, each tailored for a specific use case. Choose the one that best fits your environment.

| Variant           | Docker Tags                               | Description                                                                      |
| ----------------- | ----------------------------------------- | -------------------------------------------------------------------------------- |
| **Base**          | `latest`, `debian`, `debian-latest`       | The standard image with all networking and system tools, but no container runtime. |
| **Docker**        | `docker`, `debian-docker`                 | Includes all base tools plus the **Docker** CLI and `docker-compose`.            |
| **Podman**        | `podman`, `debian-podman`                 | Includes all base tools plus **Podman**.                                         |
| **nerdctl**       | `nerdctl`, `debian-nerdctl`               | Includes all base tools plus **nerdctl** (full version).                         |
| **containerd**    | `containerd`, `debian-containerd`         | Includes all base tools plus **containerd** and its CLI.                         |

**Example:** To pull the variant with Docker support:
```bash
docker pull obeoneorg/netshoot:docker
```

---

## 🛠️ Included Tools

This image is loaded with tools to cover all your troubleshooting needs.

### 🌐 Networking Tools

| Tool              | Description                                                 |
| ----------------- | ----------------------------------------------------------- |
| `apache2-utils`   | Utilities for web server administration (e.g., `ab`).       |
| `bind9-utils`     | DNS utilities like `dig`, `host`, and `nslookup`.           |
| `bird`            | A dynamic IP routing daemon.                                |
| `bridge-utils`    | Utilities for configuring the Linux Ethernet bridge.        |
| `conntrack`       | Command-line interface for connection tracking.             |
| `curl`            | A powerful tool for transferring data with URLs.            |
| `dhcping`         | A tool to check if a DHCP server is running.                |
| `dnsutils`        | Clients for DNS queries (see `bind9-utils`).                |
| `ethtool`         | Utility for displaying or changing Ethernet card settings.  |
| `fping`           | A utility to ping multiple hosts quickly.                   |
| `httpie`          | A user-friendly command-line HTTP client.                   |
| `iftop`           | Displays bandwidth usage on an interface.                   |
| `iperf` / `iperf3`| Tools for network performance measurement and tuning.       |
| `iproute2`        | The modern Linux networking toolkit (`ip`, `ss`, etc.).     |
| `ipset`           | A framework for IP address sets in the Linux kernel.        |
| `iptables`        | Administration tool for IPv4 packet filtering and NAT.      |
| `iputils-ping`    | The standard `ping` utility.                                |
| `ipvsadm`         | IP Virtual Server administration utility.                   |
| `mtr`             | A network diagnostic tool combining `ping` and `traceroute`.|
| `netcat-openbsd`  | A versatile networking utility for reading/writing data.    |
| `net-tools`       | Classic networking tools like `ifconfig`, `netstat`, `route`.|
| `nftables`        | The successor to `iptables` for packet filtering.           |
| `ngrep`           | A network-aware `grep` for packet streams.                  |
| `nmap`            | A powerful network scanner and security auditor.            |
| `openssh-client`  | Secure Shell (SSH) client.                                  |
| `socat`           | A multipurpose relay for bidirectional data transfer.       |
| `speedtest-cli`   | Command-line interface for testing internet bandwidth.      |
| `swaks`           | Swiss Army Knife for SMTP; a flexible SMTP testing tool.    |
| `tcpdump`         | The classic command-line packet analyzer.                   |
| `tcptraceroute`   | A `traceroute` implementation using TCP packets.            |
| `telnet`          | A client for the TELNET protocol.                           |
| `termshark`       | A terminal user interface for `tshark`.                     |
| `tshark`          | The command-line version of Wireshark.                      |
| `traceroute`      | Traces the path packets take to a network host.             |
| `wget`            | A non-interactive network downloader.                       |
| `whois`           | A client for the WHOIS directory service.                   |
| `wireguard-tools` | Utilities for the WireGuard VPN protocol.                   |

### ⚙️ System & Shell Utilities

| Tool             | Description                                                 |
| ---------------- | ----------------------------------------------------------- |
| `bash`           | The GNU Bourne-Again SHell.                                 |
| `btop`           | A modern and feature-rich resource monitor.                 |
| `ca-certificates`| Common CA certificates for SSL/TLS validation.              |
| `coreutils`      | The basic file, shell and text manipulation utilities.      |
| `e2fsprogs`      | Utilities for the ext2, ext3, and ext4 filesystems.         |
| `fail2ban`       | A tool to ban hosts that cause multiple authentication errors.|
| `file`           | A utility to determine file type.                           |
| `fzf`            | A general-purpose command-line fuzzy finder.                |
| `gdisk`          | A GPT fdisk-like partitioning tool.                         |
| `git`            | The distributed version control system.                     |
| `htop`           | An interactive process viewer.                              |
| `iotop`          | A simple top-like I/O monitor.                              |
| `jq`             | A lightweight and flexible command-line JSON processor.     |
| `kitty-terminfo` | Terminfo files for the Kitty terminal emulator.             |
| `logrotate`      | Rotates, compresses, and mails system logs.                 |
| `lsof`           | A utility to list open files.                               |
| `lynx`           | A text-based web browser.                                   |
| `magic-wormhole` | A tool to get things from one computer to another, safely.  |
| `ncdu`           | A disk usage analyzer with an ncurses interface.            |
| `nfs-common`     | NFS support files for client and server.                    |
| `nmon`           | A performance monitoring tool for Linux.                    |
| `openssl`        | A robust, commercial-grade, and full-featured toolkit for TLS.|
| `pipx`           | A tool to install and run Python applications in isolated environments.|
| `procps`         | Utilities for browsing the `/proc` filesystem.              |
| `python3-pip`    | The package installer for Python.                           |
| `rsync`          | A fast, versatile, remote (and local) file-copying tool.    |
| `screen`         | A full-screen window manager that multiplexes a physical terminal.|
| `strace`         | A diagnostic, debugging and instructional userspace tracer. |
| `sudo`           | A tool to execute a command as another user.                |
| `sysstat`        | A collection of performance monitoring tools (`sar`, `iostat`).|
| `tmux`           | A terminal multiplexer.                                     |
| `unzip` / `zip`  | Utilities for compressing and decompressing ZIP archives.   |
| `util-linux`     | A huge collection of essential Linux utilities.             |
| `uv`             | An extremely fast Python package installer from Astral.     |
| `vim`            | A highly configurable text editor.                          |

### 🎨 Shell Enhancements

| Tool                      | Description                                                 |
| ------------------------- | ----------------------------------------------------------- |
| `oh-my-zsh`               | A delightful, open-source, community-driven framework for managing your Zsh configuration.|
| `powerlevel10k`           | A fast and flexible Zsh theme with a slick look.            |
| `zsh-autosuggestions`     | It suggests commands as you type based on history and completions.|
| `zsh-completions`         | Additional completion definitions for Zsh.                  |
| `fast-syntax-highlighting`| A feature-rich syntax highlighting plugin for Zsh.          |

---

## 🔧 Customization

The shell environment is pre-configured with `.zshrc` and `.p10k.zsh` files. You can easily mount your own configuration files to customize the prompt, aliases, and plugins to your liking.

**Example:**

```bash
docker run -it --rm -v /path/to/your/.zshrc:/root/.zshrc obeoneorg/netshoot
```

---

## 🏗️ Building from Source

If you want to build the image yourself, simply clone the repository and use `docker build`.

```bash
git clone https://github.com/obeone/netshoot.git
cd netshoot
docker build -t my-netshoot .
```

The `Dockerfile` is structured with multi-stage builds. You can build a specific variant by using the `--target` flag. For example, to build only the `podman` variant:

```bash
docker build --target podman -t my-netshoot:podman .
```

---

## 🤝 Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request to suggest new tools or improvements.

---

## 📜 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

---

Made with ❤️ by [Grégoire Compagnon (obeone)](https://github.com/obeone)
