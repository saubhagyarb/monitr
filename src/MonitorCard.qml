import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Card showing one monitor's current state and controls to change it.
Item {
    id: root

    required property var monitor
    property real cardWidth: 860

    implicitHeight: card.implicitHeight + 24
    width: cardWidth

    // Derived state ───────────────────────────────────────────────────────────

    // Build a map from "WxH" resolution → list of refresh rates available.
    property var resolutionMap: {
        const map = {}
        const modes = monitor.availableModes || []
        for (let i = 0; i < modes.length; ++i) {
            const m = modes[i]
            const at = m.lastIndexOf("@")
            if (at < 0) continue
            const res = m.substring(0, at)           // "2560x1440"
            const hz  = parseFloat(m.substring(at + 1)) // 143.86
            if (!map[res]) map[res] = []
            map[res].push(hz)
        }
        return map
    }

    property var resolutions: Object.keys(resolutionMap).sort()

    // Index into resolutions[] that matches the monitor's current resolution.
    property int currentResIndex: {
        const cur = monitor.width + "x" + monitor.height
        const idx = resolutions.indexOf(cur)
        return idx >= 0 ? idx : 0
    }

    // Currently-selected resolution string.
    property string selectedResolution: resolutions.length > 0 ? resolutions[resCb.currentIndex] : ""

    // Refresh rates available for the selected resolution.
    property var availableRates: selectedResolution !== "" ? (resolutionMap[selectedResolution] || []) : []

    // Index of the current refresh rate in availableRates.
    property int currentRateIndex: {
        const r = monitor.refreshRate
        for (let i = 0; i < availableRates.length; ++i)
            if (Math.abs(availableRates[i] - r) < 0.1) return i
        return 0
    }

    // Rotation choices
    readonly property var rotationLabels: ["0°", "90°", "180°", "270°"]
    readonly property var rotationValues: [0, 90, 180, 270]

    property int currentRotIndex: {
        const idx = rotationValues.indexOf(monitor.rotation)
        return idx >= 0 ? idx : 0
    }

    // ─────────────────────────────────────────────────────────────────────────

    Rectangle {
        id: card
        anchors {
            left: parent.left; right: parent.right
            top: parent.top
            margins: 12
        }
        color: "#18181c"
        radius: Math.max(6, theme.radius)
        implicitHeight: content.implicitHeight + 32

        ColumnLayout {
            id: content
            anchors {
                left: parent.left; right: parent.right
                top: parent.top
                margins: 20
            }
            spacing: 16

            // Monitor name & description ──────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    Label {
                        text: monitor.name
                        font.pixelSize: 15
                        font.bold: true
                        color: "#ffffff"
                    }
                    Label {
                        text: monitor.description
                        font.pixelSize: 12
                        color: "#888"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // Controls grid ───────────────────────────────────────────────────
            GridLayout {
                columns: 2
                columnSpacing: 20
                rowSpacing: 14
                Layout.fillWidth: true

                // Resolution
                Label { text: qsTr("Resolution"); color: "#aaa"; font.pixelSize: 13 }
                ComboBox {
                    id: resCb
                    model: root.resolutions
                    currentIndex: root.currentResIndex
                    Layout.fillWidth: true
                    Material.roundedScale: Math.min(4, theme.radius)
                    // Reset rate selection when resolution changes.
                    onCurrentIndexChanged: rateCb.currentIndex = root.currentRateIndex
                }

                // Refresh rate
                Label { text: qsTr("Refresh Rate"); color: "#aaa"; font.pixelSize: 13 }
                ComboBox {
                    id: rateCb
                    model: root.availableRates.map(function(r) { return r.toFixed(2) + " Hz" })
                    currentIndex: root.currentRateIndex
                    Layout.fillWidth: true
                    Material.roundedScale: Math.min(4, theme.radius)
                }

                // Position
                Label { text: qsTr("Position (X, Y)"); color: "#aaa"; font.pixelSize: 13 }
                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    SpinBox {
                        id: posXSpin
                        from: -32768; to: 32767
                        value: monitor.posX
                        editable: true
                        Layout.fillWidth: true
                        Material.roundedScale: Math.min(4, theme.radius)
                    }
                    SpinBox {
                        id: posYSpin
                        from: -32768; to: 32767
                        value: monitor.posY
                        editable: true
                        Layout.fillWidth: true
                        Material.roundedScale: Math.min(4, theme.radius)
                    }
                }

                // Rotation
                Label { text: qsTr("Rotation"); color: "#aaa"; font.pixelSize: 13 }
                ComboBox {
                    id: rotCb
                    model: root.rotationLabels
                    currentIndex: root.currentRotIndex
                    Layout.fillWidth: true
                    Material.roundedScale: Math.min(4, theme.radius)
                }

                // Scale — displayed as 0.50x … 3.00x in steps of 0.25.
                Label { text: qsTr("Scale"); color: "#aaa"; font.pixelSize: 13 }
                SpinBox {
                    id: scaleSpin
                    from: 50; to: 300; stepSize: 25
                    // Stored as integer percentage × 100 (50 = 0.50, 100 = 1.00).
                    value: Math.round(monitor.scale * 100)
                    editable: true
                    Layout.fillWidth: true
                    Material.roundedScale: Math.min(4, theme.radius)

                    textFromValue: function(val) { return (val / 100).toFixed(2) + "x" }
                    valueFromText: function(text) { return Math.round(parseFloat(text) * 100) }

                    validator: RegularExpressionValidator { regularExpression: /[0-9]*\.?[0-9]*x?/ }
                }
            }

            // Apply button ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Apply")
                    enabled: !backend.busy
                    highlighted: true
                    Material.roundedScale: Math.min(4, theme.radius)

                    onClicked: {
                        const res = root.selectedResolution   // "2560x1440"
                        const hz  = root.availableRates.length > 0
                                    ? root.availableRates[rateCb.currentIndex]
                                    : monitor.refreshRate
                        const rot = root.rotationValues[rotCb.currentIndex]
                        const sc  = scaleSpin.value / 100.0

                        backend.applyMonitor(
                            monitor.name,
                            res,
                            hz,
                            posXSpin.value,
                            posYSpin.value,
                            rot,
                            sc
                        )
                    }
                }
            }
        }
    }
}
