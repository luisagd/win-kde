#!/usr/bin/env bash
# Install, link or remove Win11 KDE.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

  -l, --link            symlink instead of copy (edits apply live; for development)
  -u, --uninstall       remove everything this script installs
  -s, --sddm            also install the login screens (asks for sudo)
  -d, --deps            also install Win11 icons, Win10OS cursors and the Win11 Start menu
  -a, --apply VARIANT   apply the global theme afterwards: dark or light
      --layout          with --apply, also replace the panel with the Win11 taskbar
  -h, --help            show this help
USAGE
}

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MODE=copy MODE_SET=0 SDDM=0 DEPS=0 APPLY="" LAYOUT=0

while (($#)); do
  case $1 in
    -l|--link) MODE="link" MODE_SET=1 ;;
    -u|--uninstall) MODE="uninstall" MODE_SET=1 ;;
    -s|--sddm) SDDM=1 ;;
    -d|--deps) DEPS=1 ;;
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

# Without --link/--uninstall, keep an existing linked install linked.
if ((!MODE_SET)) && [[ -L $DATA/plasma/look-and-feel/io.github.luisagd.win-kde-dark ]]; then
  MODE="link"
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
# File Explorer style toolbar (user only; Dolphin ships its own copy in resources)
((EUID == 0)) || ITEMS+=("dolphin/dolphinui.rc|$DATA/kxmlgui5/dolphin")

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

# Third-party pieces, pinned to known-good commits.
fetch() { # fetch <github owner/repo> <commit> -> prints checkout dir
  local dir=${XDG_CACHE_HOME:-$HOME/.cache}/win-kde/${1#*/}
  [[ -d $dir/.git ]] || git clone -q "https://github.com/$1" "$dir"
  git -C "$dir" fetch -q origin "$2" 2>/dev/null || true
  git -C "$dir" -c advice.detachedHead=false checkout -q "$2"
  echo "$dir"
}

if ((DEPS)); then
  ICONS=$DATA/icons
  if [[ $MODE == uninstall ]]; then
    rm -rf "$ICONS/Win11" "$ICONS/Win11-dark" "$ICONS/Win10OS-cursors"
    kpackagetool6 --type Plasma/Applet --remove menu.11.next >/dev/null 2>&1 || true
  else
    icons=$(fetch yeyushengfan258/Win11-icon-theme a5b460a407da)
    mkdir -p "$ICONS"
    (cd "$icons" && ./install.sh -d "$ICONS" >/dev/null 2>&1)
    # The Win11 set also ships some file-type names (application-pdf, ...) as app
    # icons; Plasma prefers apps/ on a tie, so a PDF showed the viewer's logo.
    for theme in "$ICONS/Win11" "$ICONS/Win11-dark"; do
      find -L "$theme"/apps* \( -name 'application-*' -o -name 'gnome-mime-*' -o -name 'x-office-*' \) -print 2>/dev/null |
        while read -r f; do
          [[ -n $(find -L "$theme"/mimes* -name "${f##*/}" -print -quit 2>/dev/null) ]] && rm -f "$f"
        done
    done
    cursors=$(fetch yeyushengfan258/Win10OS-cursors 79d13bb90eb9)
    rm -rf "$ICONS/Win10OS-cursors"
    mkdir -p "$ICONS"
    cp -r "$cursors/dist" "$ICONS/Win10OS-cursors"
    # Win11 Start menu with Recommended, patched for Win11 wording and layout,
    # no update checks, and working links (patches/menu-11-next.patch).
    menu=$(fetch Eisteed/menu-11-next eda5490)
    git -C "$menu" checkout -q -- .
    git -C "$menu" apply "$SRC/patches/menu-11-next.patch"
    kpackagetool6 --type Plasma/Applet --upgrade "$menu" >/dev/null 2>&1 ||
      kpackagetool6 --type Plasma/Applet --install "$menu" >/dev/null
  fi
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
  # Klassy draws real rounded corners and blurred title bars; Aurorae is the fallback.
  if command -v klassy-settings >/dev/null; then
    preset=$(find /usr/lib*/qt6/plugins -name Defenestrated_11.klpw -print -quit 2>/dev/null)
    [[ -n $preset ]] && klassy-settings --import-preset "$preset" >/dev/null 2>&1 || true
    klassy-settings --load-windeco-preset "Defenestrated 11" >/dev/null 2>&1 || true
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.klassy
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme Klassy
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft ""
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight IAX
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  fi
  # Dolphin like File Explorer: Details, newest first, grouped by date, for all
  # folders (bumping ViewPropsTimestamp resets folders' remembered views).
  install -Dm644 "$SRC/dolphin/view-defaults.directory" "$DATA/dolphin/view_properties/global/.directory"
  kwriteconfig6 --file dolphinrc --group General --key ViewPropsTimestamp "$(date '+%Y,%-m,%-d,%-H,%-M,%-S')"
  # Drop Dolphin's saved toolbar placement so the two-row command bar applies.
  kwriteconfig6 --file "${XDG_STATE_HOME:-$HOME/.local/state}/dolphinstaterc" --group State --key State --delete
  # The global theme selects Kvantum but cannot pick the Kvantum theme itself.
  if command -v kvantummanager >/dev/null; then
    kvantummanager --set "win-kde-$APPLY"
  else
    echo "Kvantum is not installed; widgets keep the default style." >&2
  fi
fi
