// Windows 11 style taskbar, left-aligned:
// Start | pinned + running apps | system tray | clock | (invisible) show desktop

// First installed launcher wins; Kickoff ships with Plasma.
const startMenus = ["menu.11.next", "org.kde.plasma.kickoff"];
const start = startMenus.find(id => knownWidgetTypes.indexOf(id) !== -1) || "org.kde.plasma.kickoff";

const panel = new Panel;
panel.location = "bottom";
panel.height = 48; // Win11 taskbar height
panel.floating = false;

const menu = panel.addWidget(start);
if (start === "menu.11.next") {
    menu.currentConfigGroup = ["General"];
    menu.writeConfig("icon", "start-here");      // Windows logo in the Win11 icon theme
    menu.writeConfig("displayPosition", 0);      // open above the Start button
    menu.writeConfig("showAtCenter", false);
}

const tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", "preferred://filemanager,preferred://browser");

panel.addWidget("org.kde.plasma.marginsseparator");
// Win11 tray: network, volume, battery and notifications; the rest under the ^.
const tray = panel.addWidget("org.kde.plasma.systemtray");
tray.currentConfigGroup = ["General"];
const quickSettings = "com.github.luciotorelli.quicksettings";
const hasQuickSettings = knownWidgetTypes.indexOf(quickSettings) !== -1;
// Network and volume always show; with Quick Settings, battery and Bluetooth live in it.
tray.writeConfig("hiddenItems", "org.kde.plasma.clipboard,org.kde.kscreen,org.kde.plasma.keyboardlayout,org.kde.plasma.printmanager,org.kde.kdeconnect,org.kde.plasma.vault,org.kde.plasma.brightness,org.kde.plasma.keyboardindicator,org.kde.plasma.mediacontroller,org.kde.plasma.bluetooth,org.kde.plasma.weather,org.kde.plasma.cameraindicator,org.kde.plasma.manage-inputmethod,org.kde.kupapplet,org.kde.plasma.kclock_1x2"
    + (hasQuickSettings ? ",org.kde.plasma.battery,org.kde.plasma.bluetooth" : ""));
tray.writeConfig("shownItems", "org.kde.plasma.networkmanagement,org.kde.plasma.volume"
    + (hasQuickSettings ? "" : ",org.kde.plasma.battery"));

// Win11 Quick Settings button between the tray and the clock.
if (hasQuickSettings) {
    const qs = panel.addWidget(quickSettings);
    qs.currentConfigGroup = ["General"];
    const qsConfig = {
        panelShowPercentage: true, pillRadius: 4, useThemeAccent: true,
        showWifi: true, showBluetooth: true, showAirplane: true, showNightLight: true, showPower: true,
        showVolume: true, showBrightness: true,
        showFan: false, showAwake: false, showWired: false, showVpn: false, showMonitorContrast: false,
    };
    for (const key in qsConfig) qs.writeConfig(key, qsConfig[key]);
}
const clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("dateDisplayFormat", 2); // date below time
clock.writeConfig("autoFontAndSize", false); // Win11: two small lines
clock.writeConfig("fontSize", 9);
clock.writeConfig("fontWeight", 400);
clock.writeConfig("fontStyleName", "Regular");
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "M/d/yyyy"); // 11/3/2026, as in Win11

// Win11: clicking the far right of the taskbar shows the desktop (invisible button).
const showDesktop = panel.addWidget("org.kde.plasma.showdesktop");
showDesktop.currentConfigGroup = ["General"];
showDesktop.writeConfig("icon", "");

// Wallpaper comes from the Plasma style (plasmarc: defaultWallpaperTheme).
// Desktop right-click, Win11 style: the folder actions (New, Sort, Refresh, Undo),
// Display settings, Personalize and Open in Terminal; no panel/activity/session items.
const desktopMenu = {
    "_context": true, "_display_settings": true, "_wallpaper": true, "_open_terminal": true,
    "_add panel": false, "_run_command": false, "_lock_screen": false, "_logout": false,
    "edit mode": false, "manage activities": false, "remove": false,
};
for (const desktop of desktopsForActivity(currentActivity())) {
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["ActionPlugins", "0", "RightButton;NoModifier"];
    for (const key in desktopMenu) desktop.writeConfig(key, desktopMenu[key]);
}
