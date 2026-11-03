/*
    SPDX-FileCopyrightText: 2014 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: yeyushengfan258
    SPDX-FileCopyrightText: 2026 luisagd

    SPDX-License-Identifier: GPL-3.0-or-later
*/

// Windows 11 style splash: wallpaper with five dots orbiting below the center.
import QtQuick

Rectangle {
    id: root
    color: "black"

    // Set by ksplashqml as the session starts (1..6).
    property int stage

    Image {
        anchors.fill: parent
        source: "images/background.jpg"
        fillMode: Image.PreserveAspectCrop
    }

    Item {
        id: spinner
        readonly property real dot: Math.max(4, Math.round(Math.min(root.width, root.height) / 180))

        width: dot * 9
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.height / 5

        Repeater {
            model: 5

            Item {
                id: orbit
                required property int index
                anchors.fill: parent

                Rectangle {
                    width: spinner.dot
                    height: width
                    radius: width / 2
                    color: "white"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                SequentialAnimation on rotation {
                    loops: Animation.Infinite
                    PauseAnimation { duration: orbit.index * 110 }
                    NumberAnimation { from: 0; to: 360; duration: 1800; easing.type: Easing.InOutCubic }
                    PauseAnimation { duration: (4 - orbit.index) * 110 }
                }
            }
        }
    }
}
