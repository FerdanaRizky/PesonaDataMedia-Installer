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
  case "$PKG" in
    apt)
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -y
      apt-get install -y git curl ca-certificates wget
      ;;
    dnf)
      dnf install -y git curl ca-certificates wget
      ;;
    yum)
      yum install -y git curl ca-certificates wget
      ;;
    zypper)
      zypper --non-interactive refresh
      zypper --non-interactive install git curl ca-certificates wget
      ;;
    apk)
      apk add --no-cache git curl ca-certificates wget
      ;;
  esac
}

install_gh(){
  if command -v gh >/dev/null 2>&1; then
    return 0
  fi

  info "Memeriksa GitHub CLI..."

  case "$PKG" in
    apt)
      mkdir -p -m 755 /etc/apt/keyrings
      wget -q -O /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        https://cli.github.com/packages/githubcli-archive-keyring.gpg
      chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list
      apt-get update -y
      apt-get install -y gh
      ;;
    dnf)
      dnf install -y 'dnf-command(config-manager)' || true
      dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo || \
        dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      dnf install -y gh --repo gh-cli || dnf install -y gh
      ;;
    yum)
      yum install -y yum-utils
      yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      yum install -y gh
      ;;
    zypper)
      zypper --non-interactive install gh
      ;;
    apk)
      apk add --no-cache gh
      ;;
    *)
      fail "Tidak dapat memasang GitHub CLI pada OS ini."
      ;;
  esac

  command -v gh >/dev/null 2>&1 || fail "GitHub CLI (gh) tidak tersedia."
}
github_login(){
  if gh auth status --hostname github.com >/dev/null 2>&1; then
    ok "GitHub sudah login untuk sesi installer."
    gh auth setup-git >/dev/null 2>&1 || true
    return 0
  fi

  echo
  echo "============================================================"
  echo "                    GITHUB LOGIN"
  echo "============================================================"
  echo
  echo "Login menggunakan alur interaktif GitHub CLI."
  echo "Pilih HTTPS saat diminta."
  echo "Jawab Yes untuk menggunakan GitHub credentials."
  echo "Kode autentikasi akan muncul di terminal."
  echo
  gh auth login --hostname github.com </dev/tty

  gh auth status --hostname github.com >/dev/null 2>&1 || fail "Login GitHub gagal."
  gh auth setup-git >/dev/null 2>&1 || fail "Gagal mengatur Git credential helper."
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

echo "  OS              : $OS_NAME"
echo "  Package Manager : $PKG"
echo

install_dependencies
install_gh
github_login
fetch_installer

echo
echo "============================================================"
echo "             MENJALANKAN INSTALLER UTAMA"
echo "============================================================"
echo

bash "$TMP"
