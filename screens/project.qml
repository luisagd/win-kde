/*
    SPDX-FileCopyrightText: 2026 luisagd
    SPDX-License-Identifier: GPL-3.0-or-later
*/

// Windows 11 style "Project" panel (Meta+P): PC screen only, Duplicate,
// Extend, Second screen only. A transparent full-screen overlay catches clicks
// outside the panel, so clicking anywhere else (or Esc) closes it.
//
// Run by win-kde-project:  qml6 project.qml -- <current mode> <has external 0|1>
// Exits with 10-13 for the chosen mode, 0 to leave things unchanged.
import QtQuick
import QtQuick.Layouts
import org.kde.layershell as LayerShell

Window {
    id: win
    visible: true
    color: "transparent"

    LayerShell.Window.scope: "win-kde-project"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                             | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive
    LayerShell.Window.wantsToBeOnActiveScreen: true

    readonly property var args: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)
    readonly property bool hasExternal: args[1] === "1"
    readonly property var modes: [
        { id: "pc",        code: 10, label: qsTr("PC screen only") },
        { id: "duplicate", code: 11, label: qsTr("Duplicate") },
        { id: "extend",    code: 12, label: qsTr("Extend") },
        { id: "second",    code: 13, label: qsTr("Second screen only") },
    ]
    readonly property int current: Math.max(0, modes.findIndex(m => m.id === (args[0] || "pc")))
    property int selected: current

    function usable(i) { return hasExternal || modes[i].id === "pc"; }
    function choose(i) { Qt.exit(i !== current && usable(i) ? modes[i].code : 0); }
    function move(step) {
        for (let n = 1; n <= modes.length; n++) {
            const i = (selected + step * n + modes.length * 4) % modes.length;
            if (usable(i)) { selected = i; return; }
        }
    }

    SystemPalette { id: pal; colorGroup: SystemPalette.Active }
    function tint(alpha) { return Qt.rgba(pal.windowText.r, pal.windowText.g, pal.windowText.b, alpha); }

    // Never hold the keyboard for long if nothing happens.
    Timer { interval: 30000; running: true; onTriggered: Qt.exit(0) }

    // Anywhere outside the panel: close without changes.
    MouseArea { anchors.fill: parent; onClicked: Qt.exit(0) }

    Rectangle {
        id: panel
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 12; bottomMargin: 48 + 12 }
        width: 360
        height: content.implicitHeight + 32
        radius: 8
        color: pal.window
        border.width: 1
        border.color: win.tint(0.08)

        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape: Qt.exit(0); break;
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: win.choose(win.selected); break;
            case Qt.Key_Left: case Qt.Key_Up: win.move(-1); break;
            case Qt.Key_Right: case Qt.Key_Down: case Qt.Key_P: win.move(1); break;
            case Qt.Key_1: case Qt.Key_2: case Qt.Key_3: case Qt.Key_4: win.choose(event.key - Qt.Key_1); break;
            default: return;
            }
            event.accepted = true;
        }

        MouseArea { anchors.fill: parent } // clicks on the panel itself do not close it

        ColumnLayout {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 12

            Text {
                text: qsTr("Project")
                color: pal.windowText
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                Repeater {
                    model: win.modes
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool active: index === win.selected
                        readonly property bool usable: win.usable(index)

                        Layout.fillWidth: true
                        Layout.preferredHeight: 92
                        radius: 6
                        color: active ? pal.highlight : hover.containsMouse && usable ? win.tint(0.09) : win.tint(0.05)
                        border.width: index === win.current && !active ? 1 : 0
                        border.color: pal.highlight

                        Column {
                            anchors.centerIn: parent
                            opacity: tile.usable ? 1 : 0.35
                            spacing: 10
                            Glyph {
                                anchors.horizontalCenter: parent.horizontalCenter
                                kind: tile.modelData.id
                                ink: tile.active ? pal.highlightedText : pal.windowText
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.label
                                color: tile.active ? pal.highlightedText : pal.windowText
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: if (tile.usable) win.selected = tile.index
                            onClicked: win.choose(tile.index)
                        }
                    }
                }
            }

            Text {
                visible: !win.hasExternal
                text: qsTr("No second screen connected")
                color: win.tint(0.6)
                font.pixelSize: 12
            }
        }
    }

    // Two small screens: the laptop on the left, the second screen on the right.
    component Glyph: Row {
        property string kind
        property color ink
        spacing: kind === "extend" ? 0 : 6

        Repeater {
            model: 2
            Rectangle {
                required property int index
                readonly property bool lit: !((kind === "pc" && index === 1) || (kind === "second" && index === 0))
                width: 26
                height: 18
                radius: 2
                color: lit ? Qt.rgba(ink.r, ink.g, ink.b, 0.25) : "transparent"
                border.width: 1.5
                border.color: Qt.rgba(ink.r, ink.g, ink.b, lit ? 1 : 0.35)
                Text {
                    anchors.centerIn: parent
                    visible: kind === "duplicate"
                    text: "1"
                    color: ink
                    font.pixelSize: 10
                }
            }
        }
    }
}
