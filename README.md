## Win11 KDE

Windows 11 look for KDE Plasma 6, with a left-aligned taskbar.

Inside:

- Global themes (dark, light) with the taskbar layout
- Plasma styles, color schemes and Kvantum themes
- Aurorae window decorations
- SDDM login screens and splash screens
- Wallpapers

## Install

```sh
./install.sh                  # themes, for your user
./install.sh --sddm           # also the login screens (sudo)
./install.sh --deps           # also Win11 icons, Win10OS cursors, Win11 Start menu
./install.sh --apply dark     # apply the dark global theme
./install.sh --apply dark --layout   # ...and replace your panel with the taskbar
```

Packages: [Kvantum](https://github.com/tsujan/Kvantum) and [Klassy](https://github.com/paulmcauley/klassy) (used when installed).

Pinned by `--deps`: [Win11 icons](https://github.com/yeyushengfan258/Win11-icon-theme), [Win10OS cursors](https://github.com/yeyushengfan258/Win10OS-cursors), [Win11 Start menu](https://github.com/wOOtiTv/tv.wooti.win11menu).

## Uninstall

```sh
./install.sh --uninstall --sddm
```

## Credits

Fork of [Win11OS-kde](https://github.com/yeyushengfan258/Win11OS-kde) by yeyushengfan258. See [AUTHORS](AUTHORS).

## License

GNU GPL v3. The Bloom wallpaper is © Microsoft.

## View

![view](screenshots/View-1.png?raw=true)
![view](screenshots/View-2.png?raw=true)
![view](screenshots/View-3.png?raw=true)
