// Render an SDDM theme without SDDM, using fake sddm/userModel/... objects.
//   qml6 tools/sddm-preview.qml -- sddm/win-kde-dark out.png [lock|login]
// With QT_QPA_PLATFORM=offscreen only layout renders; blur and round avatars need a GPU.
import QtQuick
import QtQuick.Window

Window {
    id: win
    width: 1920
    height: 1080
    visible: true

    readonly property var args: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)
    readonly property string themeDir: Qt.resolvedUrl("../" + args[0]).toString()
    readonly property string out: args[1] || "preview.png"
    readonly property string mode: args[2] || "login"

    QtObject {
        id: sddm
        signal loginFailed
        signal loginSucceeded
        property bool canSuspend: true
        property bool canPowerOff: true
        property bool canReboot: true
        function login(user, password, session) { loginFailed(); }
        function suspend() {}
        function powerOff() {}
        function reboot() {}
    }
    ListModel {
        id: userModel
        property int lastIndex: 0
        ListElement { name: "luisagd"; realName: "luisagd"; icon: "" }
        ListElement { name: "papercut"; realName: "papercut"; icon: "" }
    }
    ListModel {
        id: sessionModel
        property int lastIndex: 0
        ListElement { name: "Plasma (Wayland)" }
        ListElement { name: "Plasma (X11)" }
    }
    QtObject { id: keyboard; property bool capsLock: win.mode === "caps" }
    QtObject {
        id: config
        property string background: ""
        property string accentColor: "#0078d4"
        property string font: ""
    }

    Loader {
        id: loader
        anchors.fill: parent
        source: win.themeDir + "/Main.qml"
    }

    Timer {
        interval: 800
        running: true
        onTriggered: {
            if (win.mode !== "lock") loader.item.unlock();
            grab.start();
        }
    }
    Timer {
        id: grab
        interval: 700
        onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(win.out); Qt.quit(); })
    }
}
