##!/usr/bin/env bash
# =============================================================
# System Security Audit Script
# Author: von-truber
# Version: v1.0
# Description: Security and configuration audit for Linux systems
# =============================================================

VERSION="1.0"
SCRIPT_NAME="System Security Audit"
OUTPUT_FILE=""
USE_COLOR=true

# -------------------------------------------------------------
# Color setup
# -------------------------------------------------------------
setup_colors() {
  if $USE_COLOR && [ -t 1 ] && command -v tput &>/dev/null; then
    RED=$(tput setaf 1); YELLOW=$(tput setaf 3); GREEN=$(tput setaf 2)
    BOLD=$(tput bold); RESET=$(tput sgr0)
  else
    RED=""; YELLOW=""; GREEN=""; BOLD=""; RESET=""
  fi
}

# -------------------------------------------------------------
# Output helpers
# -------------------------------------------------------------
print_line() {
  echo -e "$1"
  [[ -n "$OUTPUT_FILE" ]] && echo -e "$1" >> "$OUTPUT_FILE"
}

ok()      { print_line "  ${GREEN}✅  $1${RESET}"; }
warn()    { print_line "  ${YELLOW}⚠️   WARNING   $1${RESET}"; }
crit()    { print_line "  ${RED}🔴  CRITICAL  $1${RESET}"; }
info()    { print_line "  $1"; }
section() { print_line ""; print_line "[ $1 ]"; }

# -------------------------------------------------------------
# Argument parsing
# -------------------------------------------------------------
usage() {
  cat <<EOF
Usage: ./audit.sh [OPTIONS]

Options:
  -h, --help              Show this help message and exit
  -v, --version           Print version and exit
  -o, --output [file]     Save report to file (auto-named if no file given)
  --no-color              Disable color output

Examples:
  ./audit.sh
  ./audit.sh --output
  ./audit.sh --output /tmp/audit-report.txt
  ./audit.sh --no-color
EOF
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)    usage ;;
      -v|--version) echo "$SCRIPT_NAME v$VERSION"; exit 0 ;;
      --no-color)   USE_COLOR=false; shift ;;
      -o|--output)
        if [[ -n "$2" && "$2" != --* ]]; then
          OUTPUT_FILE="$2"; shift 2
        else
          OUTPUT_FILE="audit_$(hostname)_$(date +%Y%m%d_%H%M%S).txt"; shift
        fi
        ;;
      *) echo "Unknown option: $1"; usage ;;
    esac
  done
}

# -------------------------------------------------------------
# Report init
# -------------------------------------------------------------
init_report() {
  [[ -n "$OUTPUT_FILE" ]] && > "$OUTPUT_FILE"
}

# -------------------------------------------------------------
# Header
# -------------------------------------------------------------
print_header() {
  local host date_str width=60
  host=$(hostname)
  date_str=$(date '+%Y-%m-%d %H:%M:%S')
  print_line "╔$(printf '═%.0s' $(seq 1 $width))╗"
  print_line "║$(printf '%-60s' "             $SCRIPT_NAME  v$VERSION")║"
  print_line "║$(printf '%-60s' "       Host: $host  |  $date_str")║"
  print_line "╚$(printf '═%.0s' $(seq 1 $width))╝"
}

# -------------------------------------------------------------
# Audit modules
# -------------------------------------------------------------

audit_open_ports() {
  section "OPEN PORTS"
  if command -v ss &>/dev/null; then
    local ports
    ports=$(ss -tlnp 2>/dev/null | awk 'NR>1 {print $4, $6}')
    if [[ -z "$ports" ]]; then
      ok "No listening TCP ports detected"
    else
      info "Listening TCP ports:"
      while IFS= read -r line; do
        info "    $line"
      done < <(ss -tlnp 2>/dev/null | awk 'NR>1 {printf "%-30s %s\n", $4, $6}')
    fi
  else
    warn "ss not available; install iproute2 to enable port scanning"
  fi
}

audit_sudo_users() {
  section "SUDO ACCESS"
  local sudo_users=()
  while IFS= read -r user; do
    sudo_users+=("$user")
  done < <(grep -Po '^[^:]+' /etc/passwd | while read -r u; do
    groups "$u" 2>/dev/null | grep -qw sudo && echo "$u"
  done)

  if [[ ${#sudo_users[@]} -eq 0 ]]; then
    warn "No users found in the sudo group"
  else
    info "Users with sudo access:"
    for u in "${sudo_users[@]}"; do
      info "    $u"
    done
    ok "${#sudo_users[@]} sudo user(s) found"
  fi
}

audit_failed_logins() {
  section "FAILED SSH LOGIN ATTEMPTS"
  local count=0
  local source="journalctl"

  for f in /var/log/auth.log /var/log/secure; do
    if [[ -f "$f" ]]; then
      count=$(grep -c "Failed password" "$f" 2>/dev/null || echo 0)
      source="$f"
      break
    fi
  done

  if [[ "$source" == "journalctl" ]]; then
    if command -v journalctl &>/dev/null; then
      count=$(journalctl _SYSTEMD_UNIT=ssh.service 2>/dev/null \
        | grep -c "Failed password" 2>/dev/null | tr -d '[:space:]' || echo 0)
    else
      warn "No auth log or journalctl available; cannot check failed logins"
      return
    fi
  fi

  if [[ "$count" -eq 0 ]]; then
    ok "No failed SSH login attempts found (source: $source)"
    return
  elif [[ "$count" -lt 10 ]]; then
    warn "$count failed login attempt(s) detected (source: $source)"
  else
    crit "$count failed login attempt(s) detected (source: $source)"
  fi

  info "Top source IPs:"
  if [[ "$source" != "journalctl" ]]; then
    while IFS= read -r line; do
      info "    $line"
    done < <(grep "Failed password" "$source" 2>/dev/null \
      | grep -oP 'from \K[\d.]+' \
      | sort | uniq -c | sort -rn | head -5 \
      | awk '{printf "%s attempt(s) from %s\n", $1, $2}')
  else
    while IFS= read -r line; do
      info "    $line"
    done < <(journalctl _SYSTEMD_UNIT=ssh.service 2>/dev/null \
      | grep "Failed password" \
      | grep -oP 'from \K[\d.]+' \
      | sort | uniq -c | sort -rn | head -5 \
      | awk '{printf "%s attempt(s) from %s\n", $1, $2}')
  fi
}

audit_world_writable() {
  section "WORLD-WRITABLE FILES"
  info "Scanning / (excluding /proc, /sys, /dev) ..."
  local ww_files
  ww_files=$(find / -xdev \
    -not \( -path /proc -prune \) \
    -not \( -path /sys -prune \) \
    -not \( -path /dev -prune \) \
    -type f -perm -o+w 2>/dev/null)

  if [[ -z "$ww_files" ]]; then
    ok "No world-writable files found"
  else
    local count
    count=$(echo "$ww_files" | wc -l)
    crit "$count world-writable file(s) found:"
    while IFS= read -r line; do
      info "    $line"
    done < <(echo "$ww_files" | head -20)
    [[ "$count" -gt 20 ]] && info "    ... and $((count - 20)) more"
  fi
}

audit_running_services() {
  section "RUNNING SERVICES"
  if command -v systemctl &>/dev/null; then
    local services
    services=$(systemctl list-units --type=service --state=running \
      --no-legend --no-pager 2>/dev/null | awk '{print $1}')
    local count
    count=$(echo "$services" | grep -c . || true)
    info "$count active service(s):"
    while IFS= read -r line; do
      info "    $line"
    done <<< "$services"
  else
    warn "systemctl not available; cannot list services"
  fi
}

audit_ssh_hardening() {
  section "SSH HARDENING"
  local sshd_config="/etc/ssh/sshd_config"

  if [[ ! -f "$sshd_config" ]]; then
    warn "sshd_config not found at $sshd_config"
    return
  fi

  local root_login
  root_login=$(grep -iE "^PermitRootLogin" "$sshd_config" | awk '{print $2}')
  if [[ "${root_login,,}" == "no" ]]; then
    ok "PermitRootLogin is set to no"
  elif [[ -z "$root_login" ]]; then
    warn "PermitRootLogin not explicitly set (default may allow root)"
  else
    crit "PermitRootLogin is set to: $root_login"
  fi

  local pass_auth
  pass_auth=$(grep -iE "^PasswordAuthentication" "$sshd_config" | awk '{print $2}')
  if [[ "${pass_auth,,}" == "no" ]]; then
    ok "PasswordAuthentication is set to no"
  elif [[ -z "$pass_auth" ]]; then
    warn "PasswordAuthentication not explicitly set (default allows passwords)"
  else
    crit "PasswordAuthentication is set to: $pass_auth"
  fi

  local ssh_port
  ssh_port=$(grep -iE "^Port" "$sshd_config" | awk '{print $2}')
  if [[ -z "$ssh_port" ]]; then
    warn "SSH port not explicitly set; defaulting to 22"
  elif [[ "$ssh_port" == "22" ]]; then
    warn "SSH running on default port 22; consider changing it"
  else
    ok "SSH running on non-default port $ssh_port"
  fi
}

audit_unattended_upgrades() {
  section "AUTOMATIC SECURITY UPDATES"
  if dpkg -l unattended-upgrades &>/dev/null 2>&1; then
    ok "unattended-upgrades is installed"
    if systemctl is-active --quiet unattended-upgrades 2>/dev/null; then
      ok "unattended-upgrades service is active"
    else
      warn "unattended-upgrades installed but service is not active"
    fi
  else
    warn "unattended-upgrades is not installed"
    info "    Install with: sudo apt install unattended-upgrades"
  fi
}

audit_last_logins() {
  section "RECENT LOGIN HISTORY"
  if command -v last &>/dev/null; then
    info "Last 10 logins:"
    while IFS= read -r line; do
      info "    $line"
    done < <(last -n 10 2>/dev/null)
  else
    warn "last command not available"
  fi
}

# -------------------------------------------------------------
# Footer
# -------------------------------------------------------------
print_footer() {
  print_line ""
  print_line "────────────────────────────────────────────────────────────"
  print_line "  Audit complete: $(date '+%Y-%m-%d %H:%M:%S')"
  [[ -n "$OUTPUT_FILE" ]] && print_line "  Report saved to: $OUTPUT_FILE"
  print_line "────────────────────────────────────────────────────────────"
}

# -------------------------------------------------------------
# Main
# -------------------------------------------------------------
main() {
  parse_args "$@"
  setup_colors
  init_report
  print_header
  audit_open_ports
  audit_sudo_users
  audit_failed_logins
  audit_world_writable
  audit_running_services
  audit_ssh_hardening
  audit_unattended_upgrades
  audit_last_logins
  print_footer
}

main "$@"
