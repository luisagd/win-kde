/*
    SPDX-FileCopyrightText: 2026 luisagd
    SPDX-License-Identifier: GPL-3.0-or-later
*/

// Windows 11 style sign-in: a lock screen with a clock, then a centered
// avatar and password box. Any key or click unlocks; Esc locks again.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "black"

    readonly property real s: Math.max(0.5, height / 1080)
    readonly property color accent: config.accentColor || "#0078d4"
    readonly property string fontFamily: config.font || Qt.application.font.family
    readonly property url defaultFace: Qt.resolvedUrl("faces/.face.icon")

    property bool locked: config.startUnlocked !== "true"
    property int userIndex: Math.max(0, userModel.lastIndex)
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    property string message: ""
    property date now: new Date()

    readonly property Item user: users.count > userIndex ? users.itemAt(userIndex) : null
    readonly property Item session: sessions.count > sessionIndex ? sessions.itemAt(sessionIndex) : null

    function unlock() {
        locked = false;
        password.forceActiveFocus();
    }

    function lock() {
        locked = true;
        password.text = "";
        message = "";
        powerMenu.visible = sessionMenu.visible = false;
        root.forceActiveFocus();
    }

    function login() {
        if (!user || busy.running)
            return;
        message = "";
        busy.running = true;
        sddm.login(user.userName, password.text, sessionIndex);
    }

    function face(path) {
        return path ? path : defaultFace;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Timer {
        id: busy // guards double submits until SDDM answers
        interval: 15000
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            busy.stop();
            root.message = qsTr("The password is incorrect. Try again.");
            password.text = "";
            password.forceActiveFocus();
        }
    }

    // SDDM models, flattened so the current user/session can be read by index.
    Item {
        visible: false
        Repeater {
            id: users
            model: userModel
            delegate: Item {
                property string userName: model.name
                property string displayName: model.realName || model.name
                property string avatar: model.icon || ""
            }
        }
        Repeater {
            id: sessions
            model: sessionModel
            delegate: Item {
                property string sessionName: model.name
            }
        }
    }

    // ── Background ──────────────────────────────────────────────────────
    Image {
        id: wallpaper
        anchors.fill: parent
        source: Qt.resolvedUrl(config.background || "background.jpeg")
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: root.locked ? 0 : 1
        Behavior on blur { NumberAnimation { duration: 250 } }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.locked ? 0.08 : 0.3
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.locked ? root.unlock() : (powerMenu.visible = sessionMenu.visible = false)
    }

    focus: true
    Keys.onPressed: event => {
        if (root.locked) {
            root.unlock();
            event.accepted = true;
        }
    }

    // ── Lock screen clock ───────────────────────────────────────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.11
        opacity: root.locked ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, "h:mm")
            color: "white"
            font.family: root.fontFamily
            font.pixelSize: 128 * root.s
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, MMMM d")
            color: "white"
            font.family: root.fontFamily
            font.pixelSize: 26 * root.s
            font.weight: Font.Medium
        }
    }

    // ── Sign-in ─────────────────────────────────────────────────────────
    component Avatar: Item {
        property url source
        Image {
            id: avatarImage
            anchors.fill: parent
            source: parent.source
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectCrop
            visible: false
            onStatusChanged: if (status === Image.Error && source != root.defaultFace) source = root.defaultFace
        }
        Rectangle {
            id: avatarMask
            anchors.fill: parent
            radius: width / 2
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            source: avatarImage
            maskEnabled: true
            maskSource: avatarMask
        }
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -30 * root.s
        spacing: 14 * root.s
        opacity: root.locked ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Avatar {
            width: 192 * root.s
            height: width
            anchors.horizontalCenter: parent.horizontalCenter
            source: root.face(root.user ? root.user.avatar : "")
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.user ? root.user.displayName : ""
            color: "white"
            font.family: root.fontFamily
            font.pixelSize: 28 * root.s
            font.weight: Font.DemiBold
            bottomPadding: 10 * root.s
        }

        QQC2.TextField {
            id: password
            width: 296 * root.s
            height: 32 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            echoMode: TextInput.Password
            placeholderText: qsTr("Password")
            placeholderTextColor: Qt.rgba(1, 1, 1, 0.65)
            color: "white"
            selectionColor: root.accent
            font.family: root.fontFamily
            font.pixelSize: 15 * root.s
            leftPadding: 10 * root.s
            rightPadding: height
            verticalAlignment: TextInput.AlignVCenter
            enabled: !busy.running
            onAccepted: root.login()
            Keys.onEscapePressed: root.lock()

            background: Rectangle {
                radius: 4 * root.s
                color: password.activeFocus ? Qt.rgba(0.118, 0.118, 0.118, 0.7) : Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.07)
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 2 * root.s
                    radius: height / 2
                    color: root.accent
                    visible: password.activeFocus
                }
            }

            Rectangle {
                width: parent.height - 8 * root.s
                height: width
                anchors { right: parent.right; rightMargin: 4 * root.s; verticalCenter: parent.verticalCenter }
                radius: 3 * root.s
                visible: password.text.length > 0
                color: submit.pressed ? Qt.darker(root.accent, 1.2) : submit.containsMouse ? Qt.lighter(root.accent, 1.15) : root.accent
                Text {
                    anchors.centerIn: parent
                    text: "→"
                    color: "white"
                    font.pixelSize: 17 * root.s
                }
                MouseArea {
                    id: submit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.login()
                }
            }
        }

        Text {
            width: 296 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.message || (keyboard.capsLock ? qsTr("Caps Lock is on") : "")
            color: Qt.rgba(1, 1, 1, 0.9)
            font.family: root.fontFamily
            font.pixelSize: 13 * root.s
            height: 20 * root.s
        }
    }

    // ── Other accounts (bottom-left) ────────────────────────────────────
    Column {
        anchors { left: parent.left; bottom: parent.bottom; margins: 24 * root.s }
        spacing: 2 * root.s
        visible: !root.locked && users.count > 1

        Repeater {
            model: userModel
            delegate: Rectangle {
                width: 240 * root.s
                height: 52 * root.s
                radius: 4 * root.s
                color: index === root.userIndex ? Qt.rgba(1, 1, 1, 0.16)
                     : pick.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                Avatar {
                    id: smallFace
                    width: 36 * root.s
                    height: width
                    anchors { left: parent.left; leftMargin: 8 * root.s; verticalCenter: parent.verticalCenter }
                    source: root.face(model.icon)
                }
                Text {
                    anchors { left: smallFace.right; leftMargin: 12 * root.s; right: parent.right; verticalCenter: parent.verticalCenter }
                    text: model.realName || model.name
                    elide: Text.ElideRight
                    color: "white"
                    font.family: root.fontFamily
                    font.pixelSize: 14 * root.s
                }
                MouseArea {
                    id: pick
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.userIndex = index;
                        root.message = "";
                        password.text = "";
                        password.forceActiveFocus();
                    }
                }
            }
        }
    }

    // ── Session and power (bottom-right) ────────────────────────────────
    component FlatButton: Rectangle {
        id: flat
        property alias text: label.text
        property alias iconSource: glyph.source
        signal clicked
        implicitWidth: Math.max(height, row.implicitWidth + 20 * root.s)
        implicitHeight: 40 * root.s
        radius: 4 * root.s
        color: area.pressed ? Qt.rgba(1, 1, 1, 0.06) : area.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8 * root.s
            Image {
                id: glyph
                width: 22 * root.s
                height: width
                sourceSize: Qt.size(width * 2, height * 2)
                visible: source != ""
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: label
                visible: text !== ""
                color: "white"
                font.family: root.fontFamily
                font.pixelSize: 14 * root.s
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: flat.clicked()
        }
    }

    component Menu: Rectangle {
        default property alias entries: list.children
        width: 200 * root.s
        height: list.implicitHeight + 8 * root.s
        radius: 8 * root.s
        color: Qt.rgba(0.13, 0.13, 0.13, 0.96)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
        visible: false
        Column {
            id: list
            anchors { fill: parent; margins: 4 * root.s }
        }
    }

    Row {
        id: corner
        anchors { right: parent.right; bottom: parent.bottom; margins: 24 * root.s }
        spacing: 4 * root.s
        visible: !root.locked

        FlatButton {
            text: root.session ? root.session.sessionName : ""
            visible: sessions.count > 1
            onClicked: {
                powerMenu.visible = false;
                sessionMenu.visible = !sessionMenu.visible;
            }
        }
        FlatButton {
            iconSource: "assets/shutdown_primary.svgz"
            onClicked: {
                sessionMenu.visible = false;
                powerMenu.visible = !powerMenu.visible;
            }
        }
    }

    Menu {
        id: sessionMenu
        anchors { right: corner.right; bottom: corner.top; bottomMargin: 8 * root.s }
        Repeater {
            model: sessionModel
            delegate: FlatButton {
                width: sessionMenu.width - 8 * root.s
                text: model.name
                color: index === root.sessionIndex ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                onClicked: {
                    root.sessionIndex = index;
                    sessionMenu.visible = false;
                }
            }
        }
    }

    Menu {
        id: powerMenu
        anchors { right: corner.right; bottom: corner.top; bottomMargin: 8 * root.s }
        FlatButton {
            width: powerMenu.width - 8 * root.s
            iconSource: "assets/suspend_primary.svgz"
            text: qsTr("Sleep")
            visible: sddm.canSuspend
            onClicked: sddm.suspend()
        }
        FlatButton {
            width: powerMenu.width - 8 * root.s
            iconSource: "assets/shutdown_primary.svgz"
            text: qsTr("Shut down")
            visible: sddm.canPowerOff
            onClicked: sddm.powerOff()
        }
        FlatButton {
            width: powerMenu.width - 8 * root.s
            iconSource: "assets/restart_primary.svgz"
            text: qsTr("Restart")
            visible: sddm.canReboot
            onClicked: sddm.reboot()
        }
    }
}
