/*
    SPDX-FileCopyrightText: 2026 luisagd
    SPDX-License-Identifier: GPL-3.0-or-later
*/

// A thin area at the end of the taskbar that toggles the desktop, like Windows 11.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property int thickness: 12

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: i18n("Show desktop")

    // Runs KWin's own "Show Desktop" toggle.
    P5Support.DataSource {
        id: run
        engine: "executable"
        onNewData: sourceName => disconnectSource(sourceName)
    }

    fullRepresentation: MouseArea {
        Layout.minimumWidth: root.thickness
        Layout.preferredWidth: root.thickness
        Layout.maximumWidth: root.thickness
        Layout.fillHeight: true
        hoverEnabled: true

        onClicked: run.connectSource("qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Show Desktop'")

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: parent.height * 0.5
            color: Kirigami.Theme.textColor
            opacity: parent.containsMouse ? 0.4 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        }
    }
}
