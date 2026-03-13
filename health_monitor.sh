#!/usr/bin/env bash
# =============================================================================
# health_monitor.sh — System Health Monitor v1.0
# Author : Your Support Engineer, Me
# Date   : 2026-03-10
# Desc   : Displays CPU, memory, disk, process, network, and uptime metrics
#          with color-coded threshold alerts.
# Usage  : ./health_monitor.sh [OPTIONS]
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Constants & Defaults
# -----------------------------------------------------------------------------
readonly VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
readonly HOSTNAME="$(hostname)"

# Default thresholds (%)
CPU_THRESHOLD=85
MEM_THRESHOLD=90
DISK_THRESHOLD=80

# Output options
NO_COLOR=false
OUTPUT_FILE=""
SAVE_REPORT=false

# Detect OS
OS_TYPE="$(uname -s)"

# -----------------------------------------------------------------------------
# Colors (disabled automatically if --no-color or non-interactive terminal)
# -----------------------------------------------------------------------------
setup_colors() {
  if [[ "$NO_COLOR" == true ]] || [[ ! -t 1 ]] && [[ -z "${OUTPUT_FILE}" ]]; then
    RED=""; YELLOW=""; GREEN=""; CYAN=""; BOLD=""; RESET=""
  else
    RED="\033[0;31m"
    YELLOW="\033[0;33m"
    GREEN="\033[0;32m"
    CYAN="\033[0;36m"
    BOLD="\033[1m"
    RESET="\033[0m"
  fi
}

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
print_line() {
  echo "──────────────────────────────────────────────────────────────────────"
}

section_header() {
  echo ""
  echo -e "${BOLD}${CYAN}[ $1 ]${RESET}"
  print_line
}

status_icon() {
  local value="$1"
  local threshold="$2"
  local warn_threshold=$(( threshold - 10 ))

  if (( value >= threshold )); then
    echo -e "${RED}🔴  CRITICAL${RESET}"
  elif (( value >= warn_threshold )); then
    echo -e "${YELLOW}⚠️   WARNING${RESET}"
  else
    echo -e "${GREEN}✅  OK${RESET}"
  fi
}

strip_colors() {
  sed 's/\x1b\[[0-9;]*m//g' | sed 's/\x1b\[[0-9]*m//g'
}

err() {
  echo "[ERROR] $*" >&2
}

# -----------------------------------------------------------------------------
# Usage / Help
# -----------------------------------------------------------------------------
usage() {
  cat <<EOF

${BOLD}SYSTEM HEALTH MONITOR v${VERSION}${RESET}

${BOLD}USAGE:${RESET}
  $SCRIPT_NAME [OPTIONS]

${BOLD}OPTIONS:${RESET}
  -h, --help                  Show this help message and exit
  -v, --version               Print version and exit
  -o, --output [FILE]         Save report to file (auto-named if FILE omitted)
  --cpu-threshold  <n>        CPU alert threshold in % (default: 85)
  --mem-threshold  <n>        Memory alert threshold in % (default: 90)
  --disk-threshold <n>        Disk alert threshold in % (default: 80)
  --no-color                  Disable color output

${BOLD}EXAMPLES:${RESET}
  $SCRIPT_NAME
  $SCRIPT_NAME --output
  $SCRIPT_NAME --output /tmp/report.txt
  $SCRIPT_NAME --cpu-threshold 75 --mem-threshold 85
  $SCRIPT_NAME --no-color | grep CRITICAL

EOF
}

# -----------------------------------------------------------------------------
# Argument Parsing
# -----------------------------------------------------------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage; exit 0 ;;
      -v|--version)
        echo "health_monitor.sh v${VERSION}"; exit 0 ;;
      -o|--output)
        SAVE_REPORT=true
        if [[ -n "${2:-}" && "${2}" != --* ]]; then
          OUTPUT_FILE="$2"; shift
        else
          OUTPUT_FILE="health_report_$(date '+%Y-%m-%d_%H-%M-%S').txt"
        fi
        ;;
      --cpu-threshold)
        validate_threshold "$2" "--cpu-threshold"
        CPU_THRESHOLD="$2"; shift ;;
      --mem-threshold)
        validate_threshold "$2" "--mem-threshold"
        MEM_THRESHOLD="$2"; shift ;;
      --disk-threshold)
        validate_threshold "$2" "--disk-threshold"
        DISK_THRESHOLD="$2"; shift ;;
      --no-color)
        NO_COLOR=true ;;
      *)
        err "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
  done
}

validate_threshold() {
  local val="$1"
  local flag="$2"
  if ! [[ "$val" =~ ^[0-9]+$ ]] || (( val < 1 || val > 100 )); then
    err "Invalid value for $flag: '$val'. Must be an integer between 1 and 100."
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Dependency Check
# -----------------------------------------------------------------------------
check_dependencies() {
  local missing=()
  local required_tools=("ps" "df" "awk" "grep" "sed" "uptime" "uname" "hostname")

  if [[ "$OS_TYPE" == "Linux" ]]; then
    required_tools+=("free")
  fi

  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      missing+=("$tool")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    err "Missing required tools: ${missing[*]}"
    err "Please install them and try again."
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Header
# -----------------------------------------------------------------------------
print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
  printf "${BOLD}${CYAN}║${RESET}  %-68s${BOLD}${CYAN}║${RESET}\n" "SYSTEM HEALTH MONITOR  v${VERSION}"
  printf "${BOLD}${CYAN}║${RESET}  %-68s${BOLD}${CYAN}║${RESET}\n" "Host: ${HOSTNAME}   |   ${TIMESTAMP}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
}

# -----------------------------------------------------------------------------
# Uptime & Load Average
# -----------------------------------------------------------------------------
check_uptime_load() {
  section_header "UPTIME & LOAD"

  # Uptime
  local uptime_str
  uptime_str="$(uptime -p 2>/dev/null || uptime)"
  echo -e "  ${BOLD}Uptime       :${RESET} ${uptime_str}"

  # Load averages
  local load_1 load_5 load_15 cpu_cores
  if [[ "$OS_TYPE" == "Darwin" ]]; then
    read -r load_1 load_5 load_15 < <(sysctl -n vm.loadavg | awk '{print $2, $3, $4}')
    cpu_cores=$(sysctl -n hw.ncpu)
  else
    read -r load_1 load_5 load_15 < <(awk '{print $1, $2, $3}' /proc/loadavg)
    cpu_cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)
  fi

  # Warn if load_1 > cpu_cores
  local load_int="${load_1%%.*}"
  local load_icon
  if (( load_int > cpu_cores )); then
    load_icon="${YELLOW}⚠️   HIGH (cores: ${cpu_cores})${RESET}"
  else
    load_icon="${GREEN}✅  OK (cores: ${cpu_cores})${RESET}"
  fi

  echo -e "  ${BOLD}Load Average :${RESET} ${load_1} (1m)   ${load_5} (5m)   ${load_15} (15m)   $(echo -e "$load_icon")"
}

# -----------------------------------------------------------------------------
# CPU Usage
# -----------------------------------------------------------------------------
check_cpu() {
  section_header "CPU USAGE"

  local cpu_idle cpu_used
  if [[ "$OS_TYPE" == "Darwin" ]]; then
    cpu_idle=$(top -l 1 -n 0 | awk '/CPU usage/ {gsub(/%/,""); print $7}')
  else
    cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%id,')
    # Fallback for different top formats
    if [[ -z "$cpu_idle" ]]; then
      cpu_idle=$(top -bn1 | grep "Cpu(s)" | sed 's/.*, *\([0-9.]*\)%* id.*/\1/')
    fi
  fi

  # Round idle to integer
  cpu_idle="${cpu_idle%%.*}"
  cpu_idle="${cpu_idle:-0}"
  cpu_used=$(( 100 - cpu_idle ))

  local icon
  icon=$(status_icon "$cpu_used" "$CPU_THRESHOLD")

  echo -e "  ${BOLD}CPU Usage    :${RESET} ${cpu_used}%   ${icon}"
  echo ""
  echo -e "  ${BOLD}Top 5 Processes by CPU:${RESET}"
  printf "    %-6s  %-20s  %s\n" "PID" "NAME" "CPU%"
  printf "    %-6s  %-20s  %s\n" "------" "--------------------" "----"
  ps -eo pid,comm,%cpu --sort=-%cpu 2>/dev/null | \
    awk 'NR>1 && NR<=6 {printf "    %-6s  %-20s  %s%%\n", $1, $2, $3}'
}

# -----------------------------------------------------------------------------
# Memory Usage
# -----------------------------------------------------------------------------
check_memory() {
  section_header "MEMORY USAGE"

  local mem_total mem_used mem_free mem_pct

  if [[ "$OS_TYPE" == "Darwin" ]]; then
    # macOS: use vm_stat + sysctl
    local page_size
    page_size=$(pagesize 2>/dev/null || echo 4096)
    mem_total=$(sysctl -n hw.memsize)
    local pages_active pages_wired pages_compressed
    pages_active=$(vm_stat | awk '/Pages active/ {gsub(/\./,"",$3); print $3}')
    pages_wired=$(vm_stat | awk '/Pages wired down/ {gsub(/\./,"",$4); print $4}')
    pages_compressed=$(vm_stat | awk '/Pages occupied by compressor/ {gsub(/\./,"",$5); print $5}')
    pages_active=${pages_active:-0}
    pages_wired=${pages_wired:-0}
    pages_compressed=${pages_compressed:-0}
    mem_used=$(( (pages_active + pages_wired + pages_compressed) * page_size ))
    mem_free=$(( mem_total - mem_used ))
    mem_pct=$(( mem_used * 100 / mem_total ))

    local total_gb used_gb free_gb
    total_gb=$(echo "scale=1; $mem_total/1073741824" | bc)
    used_gb=$(echo "scale=1; $mem_used/1073741824" | bc)
    free_gb=$(echo "scale=1; $mem_free/1073741824" | bc)
  else
    # Linux: use free
    read -r mem_total mem_used mem_free < <(
      free -b | awk '/^Mem:/ {print $2, $3, $4}'
    )
    mem_pct=$(( mem_used * 100 / mem_total ))

    local total_gb used_gb free_gb
    total_gb=$(echo "scale=1; $mem_total/1073741824" | bc)
    used_gb=$(echo "scale=1; $mem_used/1073741824" | bc)
    free_gb=$(echo "scale=1; $mem_free/1073741824" | bc)
  fi

  local icon
  icon=$(status_icon "$mem_pct" "$MEM_THRESHOLD")

  echo -e "  ${BOLD}Total        :${RESET} ${total_gb} GB"
  echo -e "  ${BOLD}Used         :${RESET} ${used_gb} GB  (${mem_pct}%)   ${icon}"
  echo -e "  ${BOLD}Free         :${RESET} ${free_gb} GB"
  echo ""
  echo -e "  ${BOLD}Top 5 Processes by Memory:${RESET}"
  printf "    %-6s  %-20s  %s\n" "PID" "NAME" "MEM%"
  printf "    %-6s  %-20s  %s\n" "------" "--------------------" "----"
  ps -eo pid,comm,%mem --sort=-%mem 2>/dev/null | \
    awk 'NR>1 && NR<=6 {printf "    %-6s  %-20s  %s%%\n", $1, $2, $3}'
}

# -----------------------------------------------------------------------------
# Disk Usage
# -----------------------------------------------------------------------------
check_disk() {
  section_header "DISK USAGE"

  printf "  %-15s  %-12s  %6s  %6s  %6s  %5s  %s\n" \
    "DEVICE" "MOUNT" "TOTAL" "USED" "AVAIL" "USE%" "STATUS"
  printf "  %-15s  %-12s  %6s  %6s  %6s  %5s  %s\n" \
    "---------------" "------------" "------" "------" "------" "-----" "------"

  df -h 2>/dev/null | awk 'NR>1' | grep -v -E '^(tmpfs|devtmpfs|udev|overlay|shm|none|/dev/loop)' | \
  while read -r device size used avail pct mountpoint; do
    # Strip % from pct
    local pct_int="${pct//%/}"
    pct_int="${pct_int:-0}"

    local status
    if (( pct_int >= DISK_THRESHOLD )); then
      status="${RED}🔴  CRITICAL${RESET}"
    elif (( pct_int >= DISK_THRESHOLD - 10 )); then
      status="${YELLOW}⚠️   WARNING${RESET}"
    else
      status="${GREEN}✅  OK${RESET}"
    fi

    printf "  %-15s  %-12s  %6s  %6s  %6s  %5s  " \
      "$device" "$mountpoint" "$size" "$used" "$avail" "$pct"
    echo -e "$status"
  done
}

# -----------------------------------------------------------------------------
# Running Processes
# -----------------------------------------------------------------------------
check_processes() {
  section_header "PROCESSES"

  local total_procs zombie_count
  total_procs=$(ps aux 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')

  if [[ "$OS_TYPE" == "Darwin" ]]; then
    zombie_count=$(ps aux 2>/dev/null | awk '$8=="Z"' | wc -l | tr -d ' ')
  else
    zombie_count=$(ps aux 2>/dev/null | awk '$8~/^Z/' | wc -l | tr -d ' ')
  fi

  echo -e "  ${BOLD}Total Running :${RESET} ${total_procs}"

  if (( zombie_count > 0 )); then
    echo -e "  ${BOLD}Zombie Procs  :${RESET} ${RED}${zombie_count} ⚠️  ZOMBIE PROCESSES DETECTED${RESET}"
  else
    echo -e "  ${BOLD}Zombie Procs  :${RESET} 0   ${GREEN}✅  OK${RESET}"
  fi

  echo ""
  echo -e "  ${BOLD}Top 10 Processes by CPU:${RESET}"
  printf "    %-6s  %-6s  %-20s  %6s  %6s\n" "RANK" "PID" "NAME" "CPU%" "MEM%"
  printf "    %-6s  %-6s  %-20s  %6s  %6s\n" "------" "------" "--------------------" "------" "------"
  local rank=1
  ps -eo pid,comm,%cpu,%mem --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=11' | \
  while read -r pid comm cpu mem; do
    printf "    %-6s  %-6s  %-20s  %6s  %6s\n" "$rank" "$pid" "$comm" "${cpu}%" "${mem}%"
    (( rank++ )) || true
  done
}

# -----------------------------------------------------------------------------
# Network Summary
# -----------------------------------------------------------------------------
check_network() {
  section_header "NETWORK"

  local iface ip_addr rx_bytes tx_bytes

  if [[ "$OS_TYPE" == "Darwin" ]]; then
    iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
    ip_addr=$(ipconfig getifaddr "$iface" 2>/dev/null || echo "N/A")
    rx_bytes=$(netstat -ib 2>/dev/null | awk -v iface="$iface" '$1==iface && $10!="Ibytes" {sum+=$7} END{print sum+0}')
    tx_bytes=$(netstat -ib 2>/dev/null | awk -v iface="$iface" '$1==iface && $10!="Ibytes" {sum+=$10} END{print sum+0}')
  else
    iface=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
    if [[ -z "$iface" ]]; then
      iface=$(route -n 2>/dev/null | awk '/^0.0.0.0/{print $8; exit}')
    fi
    ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet /{split($2,a,"/"); print a[1]}' | head -1)
    rx_bytes=$(cat "/sys/class/net/${iface}/statistics/rx_bytes" 2>/dev/null || echo 0)
    tx_bytes=$(cat "/sys/class/net/${iface}/statistics/tx_bytes" 2>/dev/null || echo 0)
  fi

  # Convert bytes to human readable
  human_bytes() {
    local bytes="$1"
    if (( bytes >= 1073741824 )); then
      echo "$(echo "scale=1; $bytes/1073741824" | bc) GB"
    elif (( bytes >= 1048576 )); then
      echo "$(echo "scale=1; $bytes/1048576" | bc) MB"
    else
      echo "$(echo "scale=1; $bytes/1024" | bc) KB"
    fi
  }

  echo -e "  ${BOLD}Interface    :${RESET} ${iface:-N/A}"
  echo -e "  ${BOLD}IP Address   :${RESET} ${ip_addr:-N/A}"
  echo -e "  ${BOLD}RX (recv)    :${RESET} $(human_bytes "${rx_bytes:-0}")"
  echo -e "  ${BOLD}TX (sent)    :${RESET} $(human_bytes "${tx_bytes:-0}")"
}

# -----------------------------------------------------------------------------
# Summary Footer
# -----------------------------------------------------------------------------
print_summary() {
  echo ""
  print_line
  echo -e "  ${BOLD}Report generated :${RESET} ${TIMESTAMP}   |   ${BOLD}Host :${RESET} ${HOSTNAME}"
  if [[ "$SAVE_REPORT" == true ]]; then
    echo -e "  ${BOLD}Saved to         :${RESET} ${OUTPUT_FILE}"
  fi
  print_line
  echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  parse_args "$@"
  setup_colors
  check_dependencies

  if [[ "$SAVE_REPORT" == true ]]; then
    # Run and tee to file, stripping color codes in the file
    {
      print_header
      check_uptime_load
      check_cpu
      check_memory
      check_disk
      check_processes
      check_network
      print_summary
    } | tee >(strip_colors > "$OUTPUT_FILE")
  else
    print_header
    check_uptime_load
    check_cpu
    check_memory
    check_disk
    check_processes
    check_network
    print_summary
  fi
}

main "$@"
