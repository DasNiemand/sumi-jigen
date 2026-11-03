import QtQuick
import QtQuick.Shapes
import "lib"
import "objects"

// Layout TIMER (shutdown after time): bố cục trục thời gian.
// Hàng thời lượng cỡ lớn ở trên + đường timeline có mốc, đồng hồ cát dither ở giữa,
// sequence dạng timeline dọc bên trái, giờ "FIRES AT" khổng lồ bên phải, 2 thanh hành động ở đáy.
Item {
    id: lay
    required property var ov
    function px(n) { return ov.px(n) }
    function fs(n) { return ov.fs(n) }

    readonly property real m: px(100)
    readonly property real innerW: width - 2 * m
    readonly property real tabW: innerW / ov.checkpoints.length
    readonly property real cx: width / 2
    readonly property real cy: px(600)
    readonly property real ringR: px(262)
    readonly property real objHalf: px(214)
    readonly property real sideW: px(430)

    // ---------- Thanh trên kiểu terminal ----------
    Item {
        id: top
        x: lay.m; y: px(60)
        width: lay.innerW; height: px(40)
        opacity: ov.contentP
        NavTabs { ov: lay.ov; spread: false; width: px(640); height: parent.height; tabW: px(200); step: px(212) }
        Text {
            anchors.centerIn: parent
            text: ov.hexStream
            color: ov.soft
            font.family: ov.fontData; font.pixelSize: fs(14); font.letterSpacing: 1.5
        }
        Rectangle {
            id: armedDot
            anchors.right: armedText.left; anchors.rightMargin: px(10)
            anchors.verticalCenter: parent.verticalCenter
            width: px(11); height: width; color: ov.cDanger
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: ov.active && lay.visible
                NumberAnimation { to: 0.15; duration: 480 }
                NumberAnimation { to: 1; duration: 480 }
            }
        }
        Text {
            id: armedText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: (ov.managing ? "RUNNING  " : "ARMED  ") + Qt.formatDateTime(ov.now, "HH:mm")
            color: ov.ink
            font.family: ov.fontData; font.pixelSize: fs(17); font.bold: true; font.letterSpacing: 1.5
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: ov.rule }
    }

    // ---------- Hàng thời lượng cỡ lớn ----------
    Item {
        id: tabs
        x: lay.m; y: px(122)
        width: lay.innerW; height: px(112)
        opacity: ov.contentP

        Repeater {
            model: ov.checkpoints
            delegate: Item {
                id: tab
                required property int index
                required property var modelData
                readonly property bool sel: index === ov.selectedIndex
                x: index * lay.tabW
                width: lay.tabW; height: tabs.height
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData + " MIN"
                    color: tab.sel ? ov.ink : ov.rule
                    font.family: ov.fontTitle; font.pixelSize: fs(84); font.bold: true
                    Behavior on color { ColorAnimation { duration: 140 } }
                    scale: tab.sel ? 1.0 : 0.88
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ov.indexRequested(tab.index)
                }
            }
        }
    }

    // ---------- Timeline: đường kẻ + mốc + đoạn đã chọn ----------
    Item {
        id: line
        x: lay.m; y: px(256)
        width: lay.innerW; height: px(20)
        opacity: ov.contentP
        readonly property real selX: (ov.selectedIndex + 0.5) * lay.tabW
        Rectangle { y: px(9); width: parent.width; height: 1; color: ov.rule }
        Rectangle {
            y: px(8); height: px(3); color: ov.ink
            width: line.selX
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }
        Repeater {
            model: ov.checkpoints
            delegate: Rectangle {
                required property int index
                x: (index + 0.5) * lay.tabW - width / 2
                y: px(2); width: px(14); height: width
                rotation: 45
                color: index <= ov.selectedIndex ? ov.ink : ov.paper
                border.width: 2
                border.color: index <= ov.selectedIndex ? ov.ink : ov.rule
                Behavior on color { ColorAnimation { duration: 140 } }
            }
        }
    }
    Text {
        x: 0; y: px(284)
        width: lay.width
        horizontalAlignment: Text.AlignHCenter
        opacity: ov.contentP
        text: ov.descText
        color: ov.soft
        font.family: ov.fontLabel; font.pixelSize: fs(19)
    }

    // ---------- Giữa: đồng hồ cát + vòng tiến trình ----------
    Item {
        id: stage
        x: lay.cx; y: lay.cy
        width: 0; height: 0
        opacity: ov.contentP
        scale: 0.85 + 0.15 * ov.contentP

        Rectangle {
            x: -lay.ringR; y: -lay.ringR
            width: lay.ringR * 2; height: width; radius: width / 2
            color: "transparent"; border.width: 1; border.color: ov.rule
        }
        Shape {
            x: -lay.ringR; y: -lay.ringR
            width: lay.ringR * 2; height: width
            ShapePath {
                fillColor: "transparent"; strokeColor: ov.ink
                strokeWidth: Math.max(3, px(8)); capStyle: ShapePath.FlatCap
                PathAngleArc {
                    centerX: lay.ringR; centerY: lay.ringR; radiusX: lay.ringR; radiusY: lay.ringR
                    startAngle: -90; sweepAngle: Math.min(359.9, 360 * ov.ringFracAnim)
                }
            }
        }
        Item {
            rotation: ov.scanPos * 360
            Rectangle { x: -px(7); y: -lay.ringR - px(7); width: px(14); height: width; color: ov.cDanger }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -lay.ringR + px(26)
            text: "DRAG TO ROTATE"
            color: ov.soft
            font.family: ov.fontLabel; font.pixelSize: fs(14); font.letterSpacing: 2
        }

        PointObject {
            shape: "hourglass"
            x: -lay.objHalf; y: -lay.objHalf; width: lay.objHalf * 2; height: width
            ink: ov.ink
            soft: ov.soft
            cells: 56
            idleSpeed: 0.014
            tilt: 0.22
            rotX: 0.22
            running: ov.active && !ov.closing && lay.visible
        }
    }

    // ---------- Trái: SEQUENCE dạng timeline dọc ----------
    Item {
        id: seq
        x: lay.m; y: px(352)
        width: lay.sideW; height: px(380)
        opacity: ov.contentP
        Text {
            text: "SEQUENCE"
            color: ov.ink
            font.family: ov.fontLabel; font.pixelSize: fs(20); font.bold: true; font.letterSpacing: 1.5
        }
        Rectangle { y: px(34); width: parent.width; height: 1; color: ov.ink }
        Rectangle { x: px(7); y: px(78); width: 1; height: px(2 * 96); color: ov.rule }
        Repeater {
            model: ov.seqLines
            delegate: Item {
                required property int index
                required property string modelData
                y: px(66) + index * px(96)
                width: seq.width; height: px(60)
                Rectangle {
                    y: px(6); width: px(15); height: width
                    color: index === 0 ? ov.ink : ov.paper
                    border.width: 2; border.color: ov.ink
                }
                ScrambleText {
                    x: px(40); y: px(0)
                    full: modelData.split("   ")[0]
                    active: ov.textOn
                    color: ov.ink
                    font.family: ov.fontData; font.pixelSize: fs(26); font.bold: true
                }
                ScrambleText {
                    x: px(40); y: px(34)
                    full: modelData.split("   ")[1]
                    active: ov.textOn
                    color: ov.soft
                    font.family: ov.fontData; font.pixelSize: fs(16); font.letterSpacing: 1.5
                }
            }
        }
    }

    // ---------- Phải: giờ kích hoạt khổng lồ ----------
    Item {
        id: fires
        x: lay.width - lay.m - lay.sideW; y: px(352)
        width: lay.sideW; height: px(380)
        opacity: ov.contentP
        Text {
            text: ov.managing ? "REMAINING" : "FIRES AT"
            color: ov.ink
            font.family: ov.fontLabel; font.pixelSize: fs(20); font.bold: true; font.letterSpacing: 1.5
        }
        Rectangle { y: px(34); width: parent.width; height: 1; color: ov.ink }

        // giờ khổng lồ + bóng tách kênh khi glitch
        Text {
            x: -ov.gdxNow; y: px(46)
            visible: ov.glitchNow && ov.textOn
            text: bigTime.text
            color: ov.cDanger; opacity: 0.75
            font.family: ov.fontNumeral; font.pixelSize: fs(128); font.bold: true
        }
        Text {
            x: ov.gdxNow; y: px(46)
            visible: ov.glitchNow && ov.textOn
            text: bigTime.text
            color: ov.ghostB; opacity: 0.75
            font.family: ov.fontNumeral; font.pixelSize: fs(128); font.bold: true
        }
        ScrambleText {
            id: bigTime
            y: px(46)
            full: ov.managing ? ov.countdownText : ov.firesAt
            active: ov.textOn
            color: ov.ink
            font.family: ov.fontNumeral; font.pixelSize: fs(128); font.bold: true
        }
        Repeater {
            model: [
                [ov.managing ? "RE-ARM TO" : "DELAY", ov.minutes + " min"],
                [ov.managing ? "ENDS AT" : "NOW", ov.managing ? ov.endsAt : Qt.formatDateTime(ov.now, "HH:mm:ss")],
                ["SESSION", ov.userName],
                ["DATE", Qt.formatDateTime(ov.now, "dd.MM.yyyy")]
            ]
            delegate: Item {
                required property int index
                required property var modelData
                y: px(210) + index * px(42)
                width: fires.width; height: px(42)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData[0]
                    color: ov.soft
                    font.family: ov.fontLabel; font.pixelSize: fs(17); font.letterSpacing: 1
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData[1]
                    color: ov.ink
                    font.family: ov.fontLabel; font.pixelSize: fs(19); font.bold: true
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: ov.rule; opacity: 0.7 }
            }
        }
    }

    // ---------- Đáy: 2 thanh hành động ----------
    Item {
        id: actions
        x: (lay.width - width) / 2
        y: lay.height - px(196)
        width: px(430) * 2 + px(24); height: px(64)
        opacity: ov.contentP

        Rectangle {
            id: armBtn
            width: px(430); height: parent.height
            color: armMouse.containsMouse ? Qt.lighter(ov.ink, 1.3) : ov.ink
            Behavior on color { ColorAnimation { duration: 90 } }
            Text {
                anchors.centerIn: parent
                text: ov.managing ? ("[Y]  RE-ARM " + ov.minutes + " MIN") : "[Y]  ARM TIMER"
                color: ov.paper
                font.family: ov.fontData; font.pixelSize: fs(22); font.bold: true; font.letterSpacing: 2
            }
            MouseArea { id: armMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ov.confirmed() }
        }
        Rectangle {
            x: armBtn.width + px(24)
            width: px(430); height: parent.height
            color: cancelMouse.containsMouse ? ov.wash : "transparent"
            border.width: 2
            border.color: ov.ink
            Behavior on color { ColorAnimation { duration: 90 } }
            Text {
                anchors.centerIn: parent
                text: ov.managing ? "[N]  CANCEL TIMER" : "[N]  CANCEL"
                color: ov.ink
                font.family: ov.fontData; font.pixelSize: fs(22); font.bold: true; font.letterSpacing: 2
            }
            MouseArea { id: cancelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ov.cancelled() }
        }
    }

    FooterLegend { ov: lay.ov; x: lay.m; y: lay.height - px(100); width: lay.width - 2 * lay.m }
}
