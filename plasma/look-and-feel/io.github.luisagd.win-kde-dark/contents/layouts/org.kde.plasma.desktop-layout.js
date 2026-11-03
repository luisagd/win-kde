// Windows 11 style taskbar, left-aligned:
// Start | pinned + running apps | system tray | clock | show desktop

// First installed launcher wins; Kickoff ships with Plasma.
const startMenus = ["tv.wooti.win11menu", "org.kde.plasma.kickoff"];
const start = startMenus.find(id => knownWidgetTypes.indexOf(id) !== -1) || "org.kde.plasma.kickoff";

const panel = new Panel;
panel.location = "bottom";
panel.height = 2 * Math.ceil(gridUnit * 2.7 / 2);
panel.floating = false;

panel.addWidget(start);

const tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", "preferred://filemanager,preferred://browser");

panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");
const clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("dateDisplayFormat", 2); // date below time
panel.addWidget("org.kde.plasma.showdesktop");

// Wallpaper comes from the Plasma style (plasmarc: defaultWallpaperTheme).
for (const desktop of desktopsForActivity(currentActivity())) {
    desktop.wallpaperPlugin = "org.kde.image";
}
