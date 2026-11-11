import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win
    width: 900
    height: 640
    minimumWidth: 900
    minimumHeight: 640
    visible: true
    title: qsTr("Monitr")
    color: "#0e0e10"

    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius

    property bool helpVisible: false

    // Keyboard shortcuts — keyboard-first design.
    Shortcut {
        sequence: "?"
        context: Qt.ApplicationShortcut
        onActivated: win.helpVisible = !win.helpVisible
    }
    Shortcut {
        sequence: "Q"
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }
    Shortcut {
        sequence: "R"
        context: Qt.ApplicationShortcut
        onActivated: backend.refresh()
    }
    Shortcut {
        sequences: [StandardKey.Undo]
        context: Qt.ApplicationShortcut
        onActivated: backend.resetLastChange()
    }

    // Right-to-left languages mirror the window; the Translator sets the
    // application's layout direction.
    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Header bar ──────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 52
                color: "#18181c"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 16
                    spacing: 12

                    Label {
                        text: qsTr("Monitr")
                        font.pixelSize: 18
                        font.bold: true
                        color: "#ffffff"
                        Layout.fillWidth: true
                    }

                    // Status indicator — shows error text or a spinner.
                    Label {
                        text: backend.status
                        color: "#ff5555"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        Layout.maximumWidth: 300
                        visible: !backend.busy && backend.status !== ""
                    }

                    BusyIndicator {
                        running: backend.busy
                        visible: backend.busy
                        implicitWidth: 28
                        implicitHeight: 28
                    }

                    Button {
                        text: qsTr("Refresh")
                        enabled: !backend.busy
                        onClicked: backend.refresh()
                        Material.roundedScale: Math.min(4, theme.radius)
                    }
                }
            }

            // ── Monitor list ─────────────────────────────────────────────────
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: backend.monitors
                        delegate: MonitorCard {
                            required property var modelData
                            monitor: modelData
                            cardWidth: parent ? parent.width : 0
                            Layout.fillWidth: true
                        }
                    }

                    // Empty state when no monitors are detected.
                    Label {
                        visible: backend.monitors.length === 0 && !backend.busy
                        text: qsTr("No monitors detected.\nMake sure Hyprland is running and try refreshing.")
                        horizontalAlignment: Text.AlignHCenter
                        color: "#888"
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.topMargin: 80
                    }

                    // Bottom padding
                    Item { Layout.preferredHeight: 24 }
                }
            }
        }

        // ── Help overlay ──────────────────────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            color: "#cc000000"
            visible: win.helpVisible
            radius: theme.radius

            MouseArea {
                anchors.fill: parent
                onClicked: win.helpVisible = false
            }

            Rectangle {
                anchors.centerIn: parent
                width: 420
                height: helpContent.implicitHeight + 48
                color: "#1e1e22"
                radius: Math.max(8, theme.radius)

                ColumnLayout {
                    id: helpContent
                    anchors.centerIn: parent
                    width: parent.width - 48
                    spacing: 10

                    Label {
                        text: qsTr("Keyboard Shortcuts")
                        font.pixelSize: 16
                        font.bold: true
                        color: "#ffffff"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.bottomMargin: 6
                    }

                    Repeater {
                        model: [
                            { key: "R",      desc: qsTr("Refresh monitor list") },
                            { key: "Ctrl+Z", desc: qsTr("Reset last change") },
                            { key: "?",      desc: qsTr("Show / hide this help") },
                            { key: "Q",      desc: qsTr("Quit") }
                        ]
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 12

                            Label {
                                text: modelData.key
                                color: theme.accent
                                font.pixelSize: 13
                                font.family: "monospace"
                                Layout.preferredWidth: 80
                            }
                            Label {
                                text: modelData.desc
                                color: "#cccccc"
                                font.pixelSize: 13
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Button {
                        text: qsTr("Close")
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        onClicked: win.helpVisible = false
                        Material.roundedScale: Math.min(4, theme.radius)
                    }
                }
            }
        }
    }
}
