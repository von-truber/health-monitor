# 🖥️ System Health Monitor

A lightweight, zero-dependency Bash script that gives you an instant snapshot of your system's health — CPU, memory, disk, processes, and more — right in your terminal.

Built as a practical portfolio project by a Support Engineer, this script reflects real-world triage workflows and demonstrates Bash best practices.

---

## ✨ Features

- **CPU Usage** — Overall usage % with top 5 CPU-hungry processes
- **Memory Usage** — Total / used / free in human-readable format with top consumers
- **Disk Usage** — All real mount points with usage % and threshold alerts
- **Process Summary** — Total running processes, zombie detection, top 10 by CPU
- **Uptime & Load** — System uptime and 1/5/15-minute load averages
- **Network Summary** — Primary interface IP and RX/TX byte counts
- **Color-coded output** — Green / Yellow / Red thresholds at a glance
- **File export** — Save plain-text reports with auto-timestamped filenames
- **Fully configurable** — Override all thresholds via CLI flags
- **Cross-platform** — Linux (Ubuntu, Debian, RHEL) and macOS support

---

## 🚀 Quick Start

```bash
# Clone the repo
git clone https://github.com/yourusername/system-health-monitor.git
cd system-health-monitor

# Make the script executable
chmod +x health_monitor.sh

# Run it
./health_monitor.sh
```

---

## 📸 Sample Output

```
╔══════════════════════════════════════════════════════════╗
║             SYSTEM HEALTH MONITOR  v1.0                  ║
║       Host: prod-server-01  |  2026-03-10 14:32:00       ║
╚══════════════════════════════════════════════════════════╝

[ UPTIME & LOAD ]
  Uptime       : 3 days, 4 hours, 12 minutes
  Load Average : 0.45 (1m)  0.61 (5m)  0.58 (15m)  ✅

[ CPU USAGE ]
  CPU Usage    : 23%  ✅
  Top Processes:
    1. node         PID 3821    45.2%
    2. python3      PID 1042    12.1%
    3. postgres     PID 882      5.3%
    4. nginx        PID 541      2.1%
    5. bash         PID 7712     0.8%

[ MEMORY USAGE ]
  Total        : 16.0 GB
  Used         : 13.8 GB  (86%)  ⚠️  WARNING
  Free         : 2.2 GB
  Top Processes:
    1. postgres     PID 882     22.3%
    2. node         PID 3821    18.7%

[ DISK USAGE ]
  /dev/sda1    /          120G    95G    25G    79%  ✅
  /dev/sdb1    /data      500G   430G    70G    86%  🔴  CRITICAL

[ PROCESSES ]
  Total Running : 214
  Zombie Procs  : 0  ✅
  Top 10 by CPU :
    1. node         PID 3821    45.2%
    2. python3      PID 1042    12.1%
    ...

[ NETWORK ]
  Interface    : eth0
  IP Address   : 192.168.1.42
  RX           : 1.2 GB
  TX           : 340 MB
```

---

## ⚙️ Usage

```bash
./health_monitor.sh [OPTIONS]
```

### Options

| Flag | Description | Default |
|---|---|---|
| `-h`, `--help` | Show help message and exit | — |
| `-v`, `--version` | Print version and exit | — |
| `-o`, `--output [file]` | Save report to file (auto-named if no file given) | — |
| `--cpu-threshold <n>` | CPU alert threshold (%) | `85` |
| `--mem-threshold <n>` | Memory alert threshold (%) | `90` |
| `--disk-threshold <n>` | Disk alert threshold (%) | `80` |
| `--no-color` | Disable color output | — |

### Examples

```bash
# Run with default thresholds
./health_monitor.sh

# Save report to a timestamped file
./health_monitor.sh --output

# Save report to a specific file
./health_monitor.sh --output /tmp/report.txt

# Set custom thresholds
./health_monitor.sh --cpu-threshold 75 --mem-threshold 85 --disk-threshold 70

# Pipe-friendly output with no color codes
./health_monitor.sh --no-color | grep "CRITICAL"
```

---

## 🧰 Dependencies

No installation required. Uses only standard Unix utilities:

| Tool | Purpose |
|---|---|
| `ps`, `top` | Process and CPU metrics |
| `free` / `vm_stat` | Memory metrics (Linux / macOS) |
| `df` | Disk usage |
| `awk`, `sed`, `grep` | Text processing |
| `uptime`, `uname` | System info |
| `tput` | Terminal color detection |

---

## 🖥️ Compatibility

| Platform | Status |
|---|---|
| Ubuntu 20.04+ | ✅ Full support |
| Debian 11+ | ✅ Full support |
| CentOS / RHEL 8+ | ✅ Full support |
| macOS 12+ (Monterey+) | ✅ Best-effort |
| Windows WSL2 | ✅ Full support |
| Alpine Linux | ⚠️ Partial (BusyBox) |

---

## 📁 Project Structure

```
system-health-monitor/
├── health_monitor.sh     # Main script
├── README.md             # This file
├── PRD.md                # Product Requirements Document
├── CHANGELOG.md          # Version history
└── LICENSE               # MIT License
```

---

## 🗺️ Roadmap

- [x] CPU, memory, disk, process modules
- [x] Color-coded thresholds
- [x] CLI flags and argument parsing
- [x] File export with auto-timestamped filenames
- [x] macOS compatibility
- [ ] `--watch` live refresh mode
- [ ] JSON output format (`--json`)
- [ ] Slack / email alerting on threshold breach
- [ ] Docker container stats module
- [ ] Historical report logging and trend display

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to open a [GitHub Issue](https://github.com/yourusername/system-health-monitor/issues) or submit a pull request.

1. Fork the repo
2. Create your feature branch: `git checkout -b feature/watch-mode`
3. Commit your changes: `git commit -m 'feat: add --watch live refresh mode'`
4. Push to the branch: `git push origin feature/watch-mode`
5. Open a pull request

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

## 👤 Author

Built by a Support Engineer as a practical Bash portfolio project.
- GitHub: [@yourusername](https://github.com/yourusername)

---

> 💡 **Pro tip:** Add this to your `~/.bashrc` as an alias for quick access:
> ```bash
> alias healthcheck='~/scripts/health_monitor.sh'
> ```
