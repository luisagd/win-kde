/*
    SPDX-FileCopyrightText: 2026 luisagd
    SPDX-License-Identifier: GPL-3.0-or-later
*/

// Claude and Codex usage left, next to the tray. The taskbar shows each
// account's logo, percentage left and a green -> amber -> red bar; clicking
// opens a flyout laid out like Plasma's own (Power & Battery) with every
// limit and when it resets.
// Data: ~/.cache/ai-usage.json, written every few minutes by the ai-usage
// script (dotfiles).
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string readCmd: 'cat "${XDG_CACHE_HOME:-$HOME/.cache}/ai-usage.json"'
    readonly property string refreshCmd: "systemctl --user start ai-usage.service"
    property var accounts: []
    property real updated: 0
    property bool missing: false
    property bool refreshing: false
    property real now: Date.now()
    // Older than three missed refreshes: the timer or the network is down.
    readonly property bool stale: updated > 0 && (now / 1000 - updated) > 600

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.icon: "utilities-system-monitor"

    toolTipMainText: i18n("AI Usage")
    toolTipSubText: missing ? i18n("No data yet")
        : accounts.map(a => title(a) + ": " + (leftOf(a) < 0 ? "?" : i18n("%1% left", Math.round(leftOf(a))))).join("\n")

    // The usage endpoints rate-limit; don't refresh again within a minute.
    onExpandedChanged: if (root.expanded && root.now / 1000 - root.updated > 60) root.refresh()

    // Helpers --------------------------------------------------------------

    function leftOf(a) {
        return a.used === undefined ? -1 : Math.max(0, Math.min(100, 100 - a.used))
    }

    // Red (empty) -> amber -> green (plenty), softer than pure hues.
    function colour(left) {
        if (left < 0)
            return Kirigami.Theme.disabledTextColor
        const stops = [[0, "#e5484d"], [10, "#e5484d"], [35, "#f5a524"], [55, "#3fb950"], [100, "#3fb950"]]
        let i = 0
        while (i < stops.length - 2 && left > stops[i + 1][0]) i++
        const t = (left - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
        const a = Qt.color(stops[i][1]), b = Qt.color(stops[i + 1][1])
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }

    function logo(a) {
        return Qt.resolvedUrl(a.id === "codex" ? "../images/logo-openai.svg" : "../images/logo-claude.svg")
    }

    function title(a) {
        return a.id === "codex" ? "Codex" : a.id === "claude-personal" ? i18n("Claude (personal)") : "Claude"
    }

    function plan(a) {
        return a.plan ? a.plan.charAt(0).toUpperCase() + a.plan.slice(1) : ""
    }

    function windowName(n) {
        return ({ "5h": i18n("5-hour limit"), "week": i18n("Weekly limit"), "weekly": i18n("Weekly limit") })[n] || n
    }

    function resets(iso) {
        if (!iso)
            return ""
        const mins = Math.round((new Date(iso) - now) / 60000)
        if (mins <= 0)
            return i18n("Resetting")
        if (mins < 60)
            return i18n("Resets in %1 min", mins)
        if (mins < 24 * 60)
            return i18n("Resets in %1 h %2 min", Math.floor(mins / 60), mins % 60)
        return i18n("Resets %1", Qt.formatDateTime(new Date(iso), "ddd h:mm AP"))
    }

    function lowerFirst(s) {
        return s ? s.charAt(0).toLowerCase() + s.slice(1) : s
    }

    function ago(secs) {
        const mins = Math.round((now / 1000 - secs) / 60)
        return mins < 1 ? i18n("just now") : i18np("1 minute ago", "%1 minutes ago", mins)
    }

    function problem(a) {
        if (!a.error)
            return ""
        const cli = a.id === "codex" ? "codex" : a.id === "claude-personal" ? "luis-claude" : "claude"
        const last = a.checked ? i18n("Showing the value from %1.", ago(a.checked)) : ""
        if (a.error === "HTTP 429")
            return i18n("Usage service is busy.") + " " + last
        if (a.error === "HTTP 401")
            return i18n("Login expired; run %1 once to renew it.", cli) + " " + last
        return i18n("Couldn't update (%1).", a.error) + " " + last
    }

    // Data -----------------------------------------------------------------

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source === root.refreshCmd) {
                spinDone.restart()
                connectSource(root.readCmd)
                return
            }
            try {
                const j = JSON.parse(data.stdout)
                root.accounts = j.accounts || []
                root.updated = j.updated || 0
                root.missing = false
            } catch (e) {
                root.missing = true
            }
            root.now = Date.now()
        }
    }

    // Keep the spinner up long enough to be seen; the fetch takes under a second.
    Timer { id: spinDone; interval: 600; onTriggered: root.refreshing = false }

    function refresh() {
        if (refreshing)
            return
        refreshing = true
        exec.connectSource(refreshCmd)
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now()
            exec.connectSource(root.readCmd)
        }
    }

    // Shared bits ------------------------------------------------------------

    component Bar: Rectangle {
        property real value: -1
        implicitHeight: 3
        radius: height / 2
        color: Qt.alpha(Kirigami.Theme.textColor, 0.18)
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: parent.value < 0 ? 0 : Math.max(parent.height, parent.width * parent.value / 100)
            radius: parent.radius
            color: root.colour(parent.value)
            Behavior on width { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Kirigami.Units.longDuration } }
        }
    }

    component Logo: Kirigami.Icon {
        property var account
        source: root.logo(account)
        // The OpenAI knot follows the theme; the Claude spark keeps its orange.
        isMask: account.id === "codex"
        color: Kirigami.Theme.textColor

        // Tell the two Claude accounts apart.
        Rectangle {
            visible: parent.account.id === "claude-personal"
            anchors { right: parent.right; bottom: parent.bottom; margins: -2 }
            width: Math.round(parent.width * 0.55)
            height: width
            radius: width / 2
            color: Kirigami.Theme.highlightColor
            border.width: 1
            border.color: Kirigami.Theme.backgroundColor
            PlasmaComponents.Label {
                anchors.centerIn: parent
                text: "P"
                color: Kirigami.Theme.highlightedTextColor
                font.pixelSize: parent.height * 0.7
                font.weight: Font.Bold
            }
        }
    }

    // Taskbar ----------------------------------------------------------------

    compactRepresentation: MouseArea {
        id: button
        Layout.fillHeight: true
        Layout.minimumWidth: row.implicitWidth + Kirigami.Units.largeSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        // Hover like the tray icons; while open, Plasma draws its own highlight.
        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.textColor
            opacity: root.expanded ? 0 : button.pressed ? 0.05 : button.containsMouse ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
            opacity: root.stale ? 0.6 : 1

            Repeater {
                model: root.accounts
                delegate: RowLayout {
                    id: acct
                    required property var modelData
                    readonly property real pct: root.leftOf(modelData)
                    spacing: Kirigami.Units.smallSpacing + 2

                    Logo {
                        account: acct.modelData
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small + 2
                        Layout.preferredHeight: Layout.preferredWidth
                    }

                    ColumnLayout {
                        spacing: 3
                        PlasmaComponents.Label {
                            id: pctLabel
                            text: acct.pct < 0 ? "–" : Math.round(acct.pct) + "%"
                            font.pointSize: 9
                            font.features: { "tnum": 1 }
                            // Same width for 5% and 100% so the taskbar doesn't jump.
                            Layout.minimumWidth: metrics.width
                            TextMetrics { id: metrics; font: pctLabel.font; text: "100%" }
                        }
                        Bar {
                            value: acct.pct
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Kirigami.Icon {
                visible: root.missing || root.accounts.length === 0
                source: "utilities-system-monitor"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Layout.preferredWidth
                opacity: 0.6
            }
        }
    }

    // Flyout -----------------------------------------------------------------

    fullRepresentation: PlasmaExtras.Representation {
        id: flyout
        collapseMarginsHint: true
        Layout.minimumWidth: Kirigami.Units.gridUnit * 15
        Layout.preferredWidth: Kirigami.Units.gridUnit * 17
        Layout.minimumHeight: Layout.preferredHeight
        Layout.preferredHeight: body.implicitHeight + Kirigami.Units.largeSpacing * 3

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    level: 1
                    text: i18n("AI Usage")
                    elide: Text.ElideRight
                }
                PlasmaComponents.ToolButton {
                    id: refreshButton
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Refresh")
                    enabled: !root.refreshing
                    onClicked: root.refresh()
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    contentItem: Item {
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: implicitWidth
                        Kirigami.Icon {
                            id: spinIcon
                            anchors.fill: parent
                            source: "view-refresh"
                            RotationAnimator on rotation {
                                running: root.refreshing
                                from: 0; to: 360
                                duration: 800
                                loops: Animation.Infinite
                                onRunningChanged: if (!running) spinIcon.rotation = 0
                            }
                        }
                    }
                }
                PlasmaComponents.ToolButton {
                    display: PlasmaComponents.AbstractButton.IconOnly
                    icon.name: "window-pin"
                    text: i18n("Keep Open")
                    checkable: true
                    checked: !root.hideOnWindowDeactivate
                    onToggled: root.hideOnWindowDeactivate = !checked
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }

        ColumnLayout {
            id: body
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                margins: Kirigami.Units.largeSpacing
                topMargin: Kirigami.Units.largeSpacing * 2
            }
            spacing: Kirigami.Units.gridUnit

            PlasmaExtras.PlaceholderMessage {
                visible: root.missing
                Layout.fillWidth: true
                iconName: "utilities-system-monitor"
                text: i18n("No usage data yet")
                explanation: i18n("The ai-usage timer writes it every few minutes.")
            }

            Repeater {
                model: root.accounts
                delegate: RowLayout {
                    id: item
                    required property var modelData
                    readonly property real pct: root.leftOf(modelData)
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.gridUnit

                    Logo {
                        account: item.modelData
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Layout.preferredWidth
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        // "Claude              Resets in 4 h 12 min  61%"
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            PlasmaComponents.Label {
                                text: root.title(item.modelData)
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            PlasmaComponents.Label {
                                text: root.resets(item.modelData.resets_at)
                                color: Kirigami.Theme.disabledTextColor
                            }
                            PlasmaComponents.Label {
                                text: item.pct < 0 ? "–" : Math.round(item.pct) + "%"
                                font.features: { "tnum": 1 }
                            }
                        }

                        PlasmaComponents.ProgressBar {
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            value: Math.max(0, item.pct)
                        }

                        // Details, like "Battery Health: 87%".
                        GridLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            columns: 2
                            columnSpacing: Kirigami.Units.largeSpacing
                            rowSpacing: 0

                            PlasmaComponents.Label {
                                visible: !!item.modelData.plan
                                text: i18n("Plan:")
                                color: Kirigami.Theme.disabledTextColor
                            }
                            PlasmaComponents.Label {
                                visible: !!item.modelData.plan
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: root.plan(item.modelData)
                                color: Kirigami.Theme.disabledTextColor
                            }

                            Repeater {
                                model: (item.modelData.windows || []).length > 1 ? item.modelData.windows : []
                                delegate: PlasmaComponents.Label {
                                    required property var modelData
                                    required property int index
                                    Layout.row: index + 1
                                    Layout.column: 0
                                    text: root.windowName(modelData.name) + ":"
                                    color: Kirigami.Theme.disabledTextColor
                                }
                            }
                            Repeater {
                                model: (item.modelData.windows || []).length > 1 ? item.modelData.windows : []
                                delegate: PlasmaComponents.Label {
                                    required property var modelData
                                    required property int index
                                    Layout.row: index + 1
                                    Layout.column: 1
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignRight
                                    text: i18n("%1% left", Math.round(100 - modelData.used)) + " · "
                                          + root.lowerFirst(root.resets(modelData.resets_at))
                                    color: Kirigami.Theme.disabledTextColor
                                    font.features: { "tnum": 1 }
                                }
                            }
                        }

                        // Like the battery's "configured to charge up to 80%" line.
                        RowLayout {
                            visible: !!item.modelData.error
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Icon {
                                source: "dialog-information"
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Layout.preferredWidth
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: root.problem(item.modelData)
                            }
                        }
                    }
                }
            }

            PlasmaComponents.Label {
                visible: root.updated > 0
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: root.refreshing ? i18n("Refreshing…") : i18n("Updated %1", root.ago(root.updated))
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
            }
        }
    }
}
