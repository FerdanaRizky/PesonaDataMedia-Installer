#!/usr/bin/env bash
set -euo pipefail

REPO="FerdanaRizky/installer-pesonawifi"
FILE="install.sh"
TMP="/tmp/pesonawifi-installer.sh"

echo
echo "============================================================"
echo "        PESONA DATA MEDIA - INSTALLER"
echo "============================================================"
echo

if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] Jalankan sebagai root."
  exit 1
fi

if [ ! -d "/www/server/panel" ]; then
  echo "[ERROR] INSTALLER INI KHUSUS UNTUK aaPanel"
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y git
fi

if ! command -v gh >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y gh
fi

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  echo
  echo "GitHub belum login. Browser diperlukan untuk autentikasi satu kali."
  echo
  gh auth login --hostname github.com --web
fi

gh auth setup-git >/dev/null 2>&1 || true

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  echo "[ERROR] Login GitHub gagal."
  exit 1
fi

echo "[ OK ] GitHub login aktif."

rm -f "$TMP"

gh api "repos/$REPO/contents/$FILE" --jq '.content' |
  tr -d '
' |
  base64 -d > "$TMP"

if [ ! -s "$TMP" ]; then
  echo "[ERROR] Installer private gagal diambil."
  rm -f "$TMP"
  exit 1
fi

chmod 700 "$TMP"

echo "[ OK ] Installer utama berhasil diambil."
echo

bash "$TMP"
RC=$?

rm -f "$TMP"
exit "$RC"
