import QtQuick

// Thanh tiến trình pixel: hàng ô vuông, ô cuối của phần đã đầy nhấp nháy nhẹ.
Item {
    id: pb
    property real value: 0.5            // 0..1
    property int cells: 24
    property real gap: 2
    property color onColor: "#111111"
    property color offColor: "#999999"
    property color headColor: onColor
    property bool blinkHead: true
    readonly property real cw: (width - gap * (cells - 1)) / cells
    readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * cells)
    property bool blinkOn: true
    Timer { interval: 420; repeat: true; running: pb.blinkHead && pb.visible; onTriggered: pb.blinkOn = !pb.blinkOn }

    Repeater {
        model: pb.cells
        delegate: Rectangle {
            required property int index
            x: index * (pb.cw + pb.gap)
            width: pb.cw
            height: pb.height
            readonly property bool isHead: index === pb.lit - 1
            color: index < pb.lit ? (isHead ? pb.headColor : pb.onColor) : pb.offColor
            opacity: index < pb.lit ? (isHead && !pb.blinkOn ? 0.35 : 1) : 0.45
        }
    }
}
