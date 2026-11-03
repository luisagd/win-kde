#!/usr/bin/env bash
# Install, link or remove Win11 KDE.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

  -l, --link            symlink instead of copy (edits apply live; for development)
  -u, --uninstall       remove everything this script installs
  -s, --sddm            also install the login screens (asks for sudo)
  -a, --apply VARIANT   apply the global theme afterwards: dark or light
      --layout          with --apply, also replace the panel with the Win11 taskbar
  -h, --help            show this help
USAGE
}

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MODE=copy SDDM=0 APPLY="" LAYOUT=0

while (($#)); do
  case $1 in
    -l|--link) MODE="link" ;;
    -u|--uninstall) MODE="uninstall" ;;
    -s|--sddm) SDDM=1 ;;
    -a|--apply) APPLY=${2:-}; shift ;;
    --layout) LAYOUT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done
[[ -z $APPLY || $APPLY == dark || $APPLY == light ]] || { echo "--apply takes dark or light" >&2; exit 2; }

if ((EUID == 0)); then
  DATA=/usr/share KVANTUM=/usr/share/Kvantum
else
  DATA=${XDG_DATA_HOME:-$HOME/.local/share} KVANTUM=${XDG_CONFIG_HOME:-$HOME/.config}/Kvantum
fi

# source (relative to repo) -> destination directory
ITEMS=()
for v in dark light; do
  V=${v^}
  ITEMS+=(
    "aurorae/win-kde-$v|$DATA/aurorae/themes"
    "color-schemes/WinKDE$V.colors|$DATA/color-schemes"
    "Kvantum/win-kde-$v|$KVANTUM"
    "plasma/desktoptheme/win-kde-$v|$DATA/plasma/desktoptheme"
    "plasma/look-and-feel/io.github.luisagd.win-kde-$v|$DATA/plasma/look-and-feel"
    "wallpaper/win-kde-$v|$DATA/wallpapers"
  )
done

for item in "${ITEMS[@]}"; do
  src=$SRC/${item%%|*} dest=${item#*|}/$(basename "${item%%|*}")
  rm -rf "$dest"
  case $MODE in
    copy) mkdir -p "${dest%/*}"; cp -r "$src" "$dest" ;;
    link) mkdir -p "${dest%/*}"; ln -s "$src" "$dest" ;;
  esac
done

if ((SDDM)); then
  for v in dark light; do
    dest=/usr/share/sddm/themes/win-kde-$v
    sudo rm -rf "$dest"
    [[ $MODE == uninstall ]] || sudo cp -r "$SRC/sddm/win-kde-$v" "$dest"
  done
fi

if [[ $MODE == uninstall ]]; then
  echo "Removed Win11 KDE."
  exit 0
fi
echo "Installed Win11 KDE ($MODE)."

if [[ -n $APPLY ]]; then
  args=(--apply "io.github.luisagd.win-kde-$APPLY")
  ((LAYOUT)) && args+=(--resetLayout)
  plasma-apply-lookandfeel "${args[@]}"
  # The global theme selects Kvantum but cannot pick the Kvantum theme itself.
  if command -v kvantummanager >/dev/null; then
    kvantummanager --set "win-kde-$APPLY"
  else
    echo "Kvantum is not installed; widgets keep the default style." >&2
  fi
fi
