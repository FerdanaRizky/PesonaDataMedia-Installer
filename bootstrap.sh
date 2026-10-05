#!/usr/bin/env bash
set -euo pipefail

REPO="FerdanaRizky/installer-pesonawifi"
FILE="install.sh"
TMP="/tmp/pesonawifi-installer.sh"
GH_TMP="/tmp/pesonawifi-gh-session-$"
export GH_CONFIG_DIR="$GH_TMP/gh"
export GIT_CONFIG_GLOBAL="$GH_TMP/gitconfig"

OS_NAME="unknown"
PKG=""

info(){ echo "[INFO] $1"; }
ok(){ echo "[ OK ] $1"; }
fail(){ echo "[ERROR] $1"; exit 1; }

detect_os(){
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    OS_NAME="${PRETTY_NAME:-${ID:-unknown}}"
  fi

  if command -v apt-get >/dev/null 2>&1; then
    PKG="apt"
  elif command -v dnf >/dev/null 2>&1; then
    PKG="dnf"
  elif command -v yum >/dev/null 2>&1; then
    PKG="yum"
  elif command -v zypper >/dev/null 2>&1; then
    PKG="zypper"
  elif command -v apk >/dev/null 2>&1; then
    PKG="apk"
  else
    fail "Package manager tidak didukung."
  fi
}

install_pkg(){
  case "$PKG" in
    apt)
      export DEBIAN_FRONTEND=noninteractive
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

check_aapanel(){
  [ -d "/www/server/panel" ] || fail "INSTALLER INI KHUSUS UNTUK aaPanel. aaPanel tidak ditemukan."
}

install_dependencies(){
  command -v git >/dev/null 2>&1 || install_pkg git
  command -v curl >/dev/null 2>&1 || install_pkg curl ca-certificates

  if ! command -v gh >/dev/null 2>&1; then
    install_pkg gh || true
  fi

  command -v gh >/dev/null 2>&1 || fail "GitHub CLI (gh) tidak tersedia pada OS ini."
}

github_login(){
  if gh auth status --hostname github.com >/dev/null 2>&1; then
    ok "GitHub sudah login."
  else
    echo
    echo "============================================================"
    echo "                    PERMINTAAN AKSES"
    echo "============================================================"
    echo
    echo "Kode token akan muncul di bawah."
    echo "Konfirmasi owner untuk lanjut."
    echo
    mkdir -p "$GH_CONFIG_DIR"
    mkdir -p "$(dirname "$GIT_CONFIG_GLOBAL")"
    gh config set git_protocol https --host github.com
    GH_BROWSER=echo gh auth login --hostname github.com --web </dev/tty
  fi

  gh auth status --hostname github.com >/dev/null 2>&1 || fail "Login GitHub gagal."
  gh auth setup-git >/dev/null 2>&1 || true
  ok "GitHub authentication aktif."
}

fetch_installer(){
  rm -f "$TMP"

  info "Mengambil installer utama Private..."

  gh api "repos/$REPO/contents/$FILE" --jq ".content" |
    tr -d "\n" |
    base64 -d > "$TMP"

  [ -s "$TMP" ] || fail "Gagal mengambil installer utama Private."

  chmod 700 "$TMP"
  ok "Installer utama berhasil diambil."
}

cleanup(){
  rm -f "$TMP" 2>/dev/null || true
  rm -rf "$GH_TMP" 2>/dev/null || true
  unset GH_CONFIG_DIR GIT_CONFIG_GLOBAL GITHUB_TOKEN GITHUB_USERNAME
  echo
  ok "Sesi GitHub sementara telah dihapus dari server."
}
trap cleanup EXIT

echo
echo "============================================================"
echo "        PESONA DATA MEDIA - INSTALLER"
echo "============================================================"
echo

[ "$(id -u)" -eq 0 ] || fail "Jalankan sebagai root."
detect_os
check_aapanel

echo "  OS              : $OS_NAME"
echo "  Package Manager : $PKG"
echo

install_dependencies
github_login
fetch_installer

echo
echo "============================================================"
echo "             MENJALANKAN INSTALLER UTAMA"
echo "============================================================"
echo

bash "$TMP"
