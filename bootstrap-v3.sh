#!/usr/bin/env bash
set -euo pipefail

OS_NAME="unknown"
PM=""

[ "$(id -u)" -eq 0 ] || { echo "[ERROR] Jalankan sebagai root."; exit 1; }
[ -d "/www/server/panel" ] || { echo "[ERROR] aaPanel tidak ditemukan."; exit 1; }

if [ -r /etc/os-release ]; then
  . /etc/os-release
  OS_NAME="${PRETTY_NAME:-${ID:-unknown}}"
fi

if command -v apt-get >/dev/null 2>&1; then
  PM="apt"
elif command -v dnf >/dev/null 2>&1; then
  PM="dnf"
elif command -v yum >/dev/null 2>&1; then
  PM="yum"
elif command -v zypper >/dev/null 2>&1; then
  PM="zypper"
elif command -v apk >/dev/null 2>&1; then
  PM="apk"
else
  echo "[ERROR] Package manager tidak didukung."
  exit 1
fi

echo
echo "============================================================"
echo "        PESONA DATA MEDIA - BOOTSTRAP INSTALLER"
echo "============================================================"
echo "  OS              : $OS_NAME"
echo "  Package Manager : $PM"
echo "============================================================"
echo

install_pkg() {
  case "$PM" in
    apt)
      apt-get update -y
      apt-get install -y "$@"
      ;;
    dnf)
      dnf install -y "$@"
      ;;
    yum)
      yum install -y "$@"
      ;;
    zypper)
      zypper --non-interactive refresh
      zypper --non-interactive install "$@"
      ;;
    apk)
      apk add --no-cache "$@"
      ;;
  esac
}

command -v git >/dev/null 2>&1 || install_pkg git
command -v curl >/dev/null 2>&1 || install_pkg curl ca-certificates
command -v gh >/dev/null 2>&1 || install_pkg gh

if ! command -v gh >/dev/null 2>&1; then
  echo "[ERROR] GitHub CLI tidak tersedia pada OS ini."
  exit 1
fi

exec bash <(curl -fsSL https://raw.githubusercontent.com/FerdanaRizky/PesonaDataMedia-Installer/main/bootstrap-v2.sh)
