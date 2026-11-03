import QtQuick
import QtQuick.Shapes
import "lib"

// Thẻ đếm giờ nhỏ ở góc màn hình (thay cho chấm tròn chất lỏng): giấy kem + mực, T-mm:ss mono,
// thanh tiến trình pixel, vát góc dưới phải. Hover = đảo màu (mực nền, giấy chữ). Bấm = mở lại overlay.
Item {
    id: card

    property string bgColor: "#14161a"
    property string fgColor: "#e3e1e6"
    property string accentColor: "#a9b8f0"
    property string dangerColor: "#E63946"
    property string fontData: "monospace"
    property string fontNumeral: "monospace"
    property string remainingText: "00:00"
    property real fraction: 1
    property bool nearEnd: false
    property real scaleU: 1
    signal clicked()

    readonly property bool hovered: mouse.containsMouse
    width: Math.round(196 * scaleU)
    height: Math.round(72 * scaleU)

    SumiTheme { id: pal; bgColor: card.bgColor; fgColor: card.fgColor; accentColor: card.accentColor }
    readonly property color bodyC: hovered ? pal.ink : pal.paper
    readonly property color textC: hovered ? pal.paper : pal.ink
    readonly property color subC: hovered ? pal.rule : pal.soft
    readonly property color lineC: nearEnd ? dangerColor : pal.ink

    // Hiện ra: nhấp nháy ngắn như CRT bật
    property real flick: 0
    Component.onCompleted: { if (visible) flickAnim.start() }
    onVisibleChanged: { if (visible) flickAnim.restart() }
    NumberAnimation { id: flickAnim; target: card; property: "flick"; from: 0; to: 1; duration: 420 }
    opacity: flick < 0.05 ? 0 : (flick < 0.6 && Math.floor(flick * 40) % 2 === 1 ? 0.4 : 1)

    Shape {
        anchors.fill: parent
        ShapePath {
            id: sp
            readonly property real c: Math.round(16 * card.scaleU)
            fillColor: card.bodyC
            strokeColor: card.lineC
            strokeWidth: card.nearEnd ? 2 : 1
            startX: 0; startY: 0
            PathLine { x: card.width; y: 0 }
            PathLine { x: card.width; y: card.height - sp.c }
            PathLine { x: card.width - sp.c; y: card.height }
            PathLine { x: 0; y: card.height }
            PathLine { x: 0; y: 0 }
        }
    }

    Text {
        x: Math.round(12 * card.scaleU); y: Math.round(8 * card.scaleU)
        text: card.hovered ? "MANAGE" : (card.nearEnd ? "FINAL" : "TIMER")
        color: card.nearEnd && !card.hovered ? card.dangerColor : card.subC
        font.family: card.fontData
        font.pixelSize: Math.round(10 * card.scaleU)
        font.bold: true
        font.letterSpacing: 2
    }
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: Math.round(12 * card.scaleU)
        y: Math.round(10 * card.scaleU)
        width: Math.round(8 * card.scaleU); height: width
        color: card.nearEnd ? card.dangerColor : card.textC
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: card.visible
            NumberAnimation { to: 0.15; duration: 480 }
            NumberAnimation { to: 1; duration: 480 }
        }
    }
    Text {
        x: Math.round(12 * card.scaleU); y: Math.round(22 * card.scaleU)
        text: "T-" + card.remainingText
        color: card.textC
        font.family: card.fontNumeral
        font.pixelSize: Math.round(26 * card.scaleU)
        font.bold: true
    }
    PixelBar {
        x: Math.round(12 * card.scaleU)
        y: card.height - Math.round(18 * card.scaleU)
        width: card.width - Math.round(24 * card.scaleU) - sp.c * 0.6
        height: Math.round(6 * card.scaleU)
        cells: 26
        gap: Math.max(1, Math.round(2 * card.scaleU))
        value: card.fraction
        onColor: card.nearEnd ? card.dangerColor : card.textC
        offColor: card.subC
        headColor: card.nearEnd ? card.dangerColor : card.textC
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.clicked()
    }
}
