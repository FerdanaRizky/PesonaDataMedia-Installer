#!/usr/bin/env bash
set -euo pipefail

REPO="FerdanaRizky/installer-pesonawifi"
FILE="install.sh"
TMP="/tmp/pesonawifi-installer.sh"

echo
echo "============================================================"
echo "        PESONA DATA MEDIA - BOOTSTRAP INSTALLER"
echo "============================================================"
echo

[ "$(id -u)" -eq 0 ] || { echo "[ERROR] Jalankan sebagai root."; exit 1; }
[ -d "/www/server/panel" ] || { echo "[ERROR] INSTALLER INI KHUSUS UNTUK aaPanel"; exit 1; }

if ! command -v git >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y git
fi

if ! command -v gh >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y gh
fi

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  gh auth login --hostname github.com --git-protocol https
fi

gh auth setup-git >/dev/null 2>&1 || true
gh auth status --hostname github.com >/dev/null 2>&1 || {
  echo "[ERROR] GitHub login gagal."
  exit 1
}

rm -f "$TMP"
gh api "repos/$REPO/contents/$FILE" --jq '.content' | tr -d '\n' | base64 -d > "$TMP"

[ -s "$TMP" ] || { echo "[ERROR] Gagal mengambil installer private."; rm -f "$TMP"; exit 1; }

chmod 700 "$TMP"
bash "$TMP"
RC=$?
rm -f "$TMP"
exit "$RC"
