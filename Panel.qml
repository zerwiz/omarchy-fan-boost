import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
    id: root
    moduleName: "io.github.zerwiz.fan-boost"
    ipcTarget: "io.github.zerwiz.fan-boost"
    manageIpc: false
    property var status: ({ mode: "auto", until: 0, fans: [], profile: "", platform: "" })
    property string lastError: ""
    property double nowEpoch: Date.now() / 1000
    readonly property var fans: status.fans || []
    readonly property string mode: status.mode || "auto"
    readonly property bool boosted: mode === "max"
    readonly property int refreshIntervalSec: Math.max(1, parseInt(setting("refreshIntervalSec", 3), 10) || 3)
    readonly property int boostMinutes: Math.max(1, parseInt(setting("boostMinutes", 5), 10) || 5)
    readonly property string fanctlPath: "/usr/local/bin/fanctl"

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function refresh() {
        if (!statusProc.running) statusProc.running = true
    }

    function act(command) {
        if (actionProc.running) return
        lastError = ""
        actionProc.command = ["sudo", "-n", fanctlPath].concat(command)
        actionProc.running = true
    }

    function boostTimed() { act(["max", String(boostMinutes * 60)]) }
    function boostHeld() { act(["max", "hold"]) }
    function release() { act(["auto"]) }

    function deliveryFailure(code, err) {
        var text = String(err || "").trim()
        if (code === 127 || text.indexOf("sudo:") === 0 || text.indexOf("command not found") >= 0) {
            return "fanctl is not installed — run install.sh once with sudo"
        }
        if (text !== "") return text.split("\n")[0]
        return "fanctl exited " + code
    }

    IpcHandler {
        target: "io.github.zerwiz.fan-boost"
        function open() { root.open() }
        function close() { root.close() }
        function show() { root.open() }
        function hide() { root.close() }
        function toggle() { root.toggle() }
        function boost() { root.boostTimed() }
        function auto() { root.release() }
    }

    onOpenedChanged: {
        if (opened) refresh()
    }

    Process {
        id: statusProc
        command: ["sh", "-c", "[ -x " + root.fanctlPath + " ] && exec " + root.fanctlPath + " status"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.status = Model.parseStatus(text)
        }
    }

    Process {
        id: actionProc
        stderr: StdioCollector {
            id: actionErr
            waitForEnd: true
        }
        onExited: function(code) {
            if (code !== 0) root.lastError = root.deliveryFailure(code, actionErr.text)
            root.refresh()
        }
    }

    Timer {
        interval: root.refreshIntervalSec * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1000
        running: root.boosted && root.status.until > 0
        repeat: true
        onTriggered: root.nowEpoch = Date.now() / 1000
    }

    Component.onCompleted: refresh()

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: Model.barText(root.mode, root.fans)
        fontSize: Style.font.caption
        horizontalMargin: 6
        tooltipText: {
            var line = "Fans: " + Model.modeText(root.mode, root.status.until, root.nowEpoch)
            var rpm = Model.averageRpm(root.fans)
            if (rpm > 0) line += " · " + rpm + " rpm"
            if (root.lastError !== "") line += " · " + root.lastError
            return line
        }
        onPressed: function(b) {
            if (b === Qt.LeftButton) root.toggle()
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(320))
        contentHeight: panel.fittedContentHeight(column.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()

            Column {
                id: column
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Style.space(14)

                Column {
                    width: parent.width
                    spacing: Style.space(8)

                    PanelSectionHeader {
                        text: "FANS"
                        foreground: root.bar.foreground
                        fontFamily: root.bar.fontFamily
                    }

                    InfoPair {
                        label: "Mode"
                        value: Model.modeText(root.mode, root.status.until, root.nowEpoch)
                    }

                    Repeater {
                        model: root.fans

                        Column {
                            required property var modelData
                            width: parent.width
                            spacing: Style.spacing.labelGap

                            InfoPair {
                                label: Model.fanLabel(modelData)
                                value: Model.fanDetail(modelData)
                            }
                            Bar {
                                visible: modelData.pwm > 0
                                fraction: Model.pwmPercent(modelData) / 100
                            }
                        }
                    }

                    InfoPair {
                        visible: root.fans.length === 0
                        label: "Driver"
                        value: root.status.profile !== ""
                            ? "asusctl · " + root.status.profile
                            : (root.status.platform !== "" ? "platform · " + root.status.platform : "no fan door found")
                    }

                    Row {
                        width: parent.width
                        spacing: Style.space(6)
                        readonly property real cellWidth: (width - spacing * 2) / 3

                        Button {
                            width: parent.cellWidth
                            iconText: "󰈐"
                            iconSize: Style.font.title
                            text: root.boostMinutes + " min"
                            fontSize: Style.font.bodySmall
                            foreground: root.bar.foreground
                            fontFamily: root.bar.fontFamily
                            horizontalPadding: Style.spacing.controlPaddingX
                            verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                            bordered: true
                            active: root.boosted && root.status.until > 0
                            onClicked: root.boostTimed()
                        }

                        Button {
                            width: parent.cellWidth
                            iconText: "󰓅"
                            iconSize: Style.font.title
                            text: "Hold max"
                            fontSize: Style.font.bodySmall
                            foreground: root.bar.foreground
                            fontFamily: root.bar.fontFamily
                            horizontalPadding: Style.spacing.controlPaddingX
                            verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                            bordered: true
                            active: root.boosted && root.status.until === 0
                            onClicked: root.boostHeld()
                        }

                        Button {
                            width: parent.cellWidth
                            iconText: "󰚥"
                            iconSize: Style.font.title
                            text: "Auto"
                            fontSize: Style.font.bodySmall
                            foreground: root.bar.foreground
                            fontFamily: root.bar.fontFamily
                            horizontalPadding: Style.spacing.controlPaddingX
                            verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                            bordered: true
                            active: !root.boosted
                            onClicked: root.release()
                        }
                    }

                    InfoLabelRow {
                        text: root.lastError !== ""
                            ? root.lastError
                            : "A timed boost returns the fans to the firmware when it ends"
                        hint: root.status.platform !== "" ? "Platform profile: " + root.status.platform : ""
                    }
                }
            }
        }
    }

    component InfoPair: Column {
        property string label: ""
        property string value: ""

        width: parent.width
        spacing: Style.spacing.labelGap

        Row {
            width: parent.width
            spacing: Style.space(8)

            Text {
                text: label
                color: root.bar.foreground
                opacity: 0.6
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                textFormat: Text.PlainText
            }
            Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
            Text {
                text: value
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                textFormat: Text.PlainText
            }
        }
    }

    component InfoLabelRow: Column {
        property string text: ""
        property string hint: ""

        width: parent.width
        spacing: Style.space(2)
        visible: text !== "" || hint !== ""

        Text {
            width: parent.width
            text: parent.text
            color: root.bar.foreground
            opacity: 0.6
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            textFormat: Text.PlainText
        }

        Text {
            width: parent.width
            text: parent.hint
            color: root.bar.foreground
            opacity: 0.9
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            textFormat: Text.PlainText
        }
    }

    component Bar: Item {
        property real fraction: 0

        width: parent.width
        implicitHeight: Style.space(6)

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            radius: height / 2
            color: root.bar.foreground
            width: Math.max(height, parent.width * Math.max(0, Math.min(1, fraction)))

            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }
    }
}
