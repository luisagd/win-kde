// Windows 11 style taskbar, left-aligned:
// Start | pinned + running apps | system tray | clock

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
tray.writeConfig("hiddenItems", "org.kde.plasma.clipboard,org.kde.kscreen,org.kde.plasma.keyboardlayout,org.kde.plasma.printmanager,org.kde.kdeconnect,org.kde.plasma.vault,org.kde.plasma.brightness,org.kde.plasma.keyboardindicator,org.kde.plasma.mediacontroller,org.kde.plasma.bluetooth,org.kde.plasma.weather,org.kde.plasma.cameraindicator,org.kde.plasma.manage-inputmethod,org.kde.kupapplet,org.kde.plasma.kclock_1x2");
const clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("dateDisplayFormat", 2); // date below time
clock.writeConfig("autoFontAndSize", false); // Win11: two small lines
clock.writeConfig("fontSize", 9);
clock.writeConfig("fontWeight", 400);
clock.writeConfig("fontStyleName", "Regular");

// Wallpaper comes from the Plasma style (plasmarc: defaultWallpaperTheme).
for (const desktop of desktopsForActivity(currentActivity())) {
    desktop.wallpaperPlugin = "org.kde.image";
}
