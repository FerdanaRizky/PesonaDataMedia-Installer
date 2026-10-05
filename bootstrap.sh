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
    ok "GitHub sudah login untuk sesi installer."
    return 0
  fi

  echo
  echo "============================================================"
  echo "                    GITHUB LOGIN"
  echo "============================================================"
  echo
  echo "Metode Git: HTTPS saja. SSH tidak digunakan."
  echo
  read -r -p "GitHub Username: " GITHUB_USERNAME </dev/tty
  read -r -s -p "GitHub Token   : " GITHUB_TOKEN </dev/tty
  echo

  if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    fail "Username atau token kosong."
  fi

  gh config set git_protocol https --host github.com

  if ! printf "%s\n" "$GITHUB_TOKEN" | gh auth login --hostname github.com --with-token >/dev/null 2>&1; then
    fail "Login GitHub gagal."
  fi

  gh auth setup-git >/dev/null 2>&1 || true

  AUTH_USER="$(gh api user --jq ".login" 2>/dev/null || true)"
  if [ "$AUTH_USER" != "$GITHUB_USERNAME" ]; then
    gh auth logout --hostname github.com >/dev/null 2>&1 || true
    fail "Username tidak cocok dengan token GitHub."
  fi

  ok "GitHub authentication aktif melalui HTTPS."
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
