import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

TextField {
    placeholderTextColor: config.color
    palette.text: config.color
    font.pointSize: config.fontSize
    font.family: config.font || Qt.application.font.family
    width: parent.width
    background: Rectangle {
        color: parent.focus ? "#ffffff" : "#dddddd"
        radius: 100
        opacity: 0.45
    }
}
