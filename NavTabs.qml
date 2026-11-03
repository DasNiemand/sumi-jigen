import QtQuick

// Thanh tab chức năng SHUTDOWN / REBOOT / TIMER (bấm được để chuyển ngay trong overlay).
Item {
    id: nt
    required property var ov
    property bool spread: false           // true: rải đều theo chiều ngang (kiểu NieR) | false: gọn, sát trái
    property real tabW: ov.px(200)
    property real step: ov.px(212)
    readonly property bool navEnabled: !ov.isWarn && !ov.managing
    readonly property var modes: ["shutdown", "reboot", "shutdown30"]

    Repeater {
        model: ["SHUTDOWN", "REBOOT", "TIMER"]
        delegate: Item {
            id: tab
            required property int index
            required property string modelData
            readonly property bool on: index === nt.ov.navIndex
            width: nt.tabW
            height: nt.height
            x: nt.spread ? nt.width * (0.2 + index * 0.2) - width / 2 : index * nt.step

            Rectangle {
                anchors.fill: parent
                color: tab.on ? nt.ov.ink : (tabMouse.containsMouse && nt.navEnabled ? nt.ov.wash : "transparent")
                Behavior on color { ColorAnimation { duration: 110 } }
            }
            Text {
                anchors.centerIn: parent
                text: tab.modelData
                color: tab.on ? nt.ov.paper : (nt.navEnabled ? nt.ov.ink : nt.ov.soft)
                font.family: nt.ov.fontLabel
                font.pixelSize: nt.ov.fs(19)
                font.bold: true
                font.letterSpacing: 1.5
            }
            MouseArea {
                id: tabMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: nt.navEnabled && !tab.on
                cursorShape: Qt.PointingHandCursor
                onClicked: nt.ov.switchRequested(nt.modes[tab.index])
            }
        }
    }
}
