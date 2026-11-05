import QtQuick
import QtQuick.Shapes
import "lib"
import "objects"

// Layout REBOOT: bố cục bất đối xứng kiểu Ueda x NieR.
// Bên trái: vòng tròn mỏng khổng lồ ôm vật thể torus dither + 2 cung xoay ngược chiều.
// Bên phải: chữ Hán lớn, tiêu đề khổng lồ, mô tả, Yes/No dạng tab chữ lớn (như hàng danh mục NieR),
// dải STATUS 4 ô ở dưới.
Item {
    id: lay
    required property var ov
    function px(n) { return ov.px(n) }
    function fs(n) { return ov.fs(n) }

    readonly property real m: px(100)
    readonly property real ringR1: Math.min(px(392), height * 0.37)
    readonly property real cx: m + ringR1 + px(18)
    readonly property real cy: height * 0.53
    readonly property real rightX: Math.max(cx + ringR1 + px(64), width - m - px(780))
    readonly property real colW: width - m - rightX
    readonly property real tabStep: px(300)

    // ---------- Nav gọn bên trái + đồng hồ bên phải ----------
    Item {
        id: nav
        x: lay.m; y: px(62)
        width: lay.width - 2 * lay.m
        height: px(44)
        opacity: ov.contentP
        NavTabs { ov: lay.ov; spread: false; width: px(640); height: parent.height; tabW: px(200); step: px(212) }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(ov.now, "HH:mm")
            color: ov.ink
            font.family: ov.fontData; font.pixelSize: fs(20); font.bold: true
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: px(92)
            anchors.verticalCenter: parent.verticalCenter
            text: ov.hexStream
            color: ov.soft
            font.family: ov.fontData; font.pixelSize: fs(14); font.letterSpacing: 1
        }
    }

    // ---------- Bên trái: vòng tròn + torus ----------
    Item {
        id: stage
        x: lay.cx; y: lay.cy
        width: 0; height: 0
        opacity: ov.contentP
        scale: 0.85 + 0.15 * ov.contentP

        // vòng ngoài + vòng trong mảnh
        Rectangle {
            x: -lay.ringR1; y: -lay.ringR1
            width: lay.ringR1 * 2; height: width; radius: width / 2
            color: "transparent"; border.width: 1; border.color: ov.ink
        }
        Rectangle {
            x: -(lay.ringR1 - px(34)); y: -(lay.ringR1 - px(34))
            width: (lay.ringR1 - px(34)) * 2; height: width; radius: width / 2
            color: "transparent"; border.width: 1; border.color: ov.rule
        }
        // 4 vạch cardinal
        Repeater {
            model: 4
            delegate: Item {
                required property int index
                rotation: index * 90
                Rectangle { x: -1; y: -lay.ringR1 - px(10); width: 2; height: px(26); color: ov.ink }
            }
        }
        // 2 cung xoay ngược chiều
        Item {
            NumberAnimation on rotation { from: 0; to: 360; duration: 4200; loops: Animation.Infinite; running: ov.active && lay.visible }
            Shape {
                readonly property real r: lay.ringR1 - px(17)
                x: -r; y: -r; width: r * 2; height: width
                ShapePath {
                    fillColor: "transparent"; strokeColor: ov.ink
                    strokeWidth: Math.max(3, px(8)); capStyle: ShapePath.FlatCap
                    PathAngleArc { centerX: lay.ringR1 - px(17); centerY: lay.ringR1 - px(17); radiusX: lay.ringR1 - px(17); radiusY: lay.ringR1 - px(17); startAngle: -90; sweepAngle: 96 }
                }
            }
        }
        Item {
            NumberAnimation on rotation { from: 360; to: 0; duration: 6400; loops: Animation.Infinite; running: ov.active && lay.visible }
            Shape {
                readonly property real r: lay.ringR1 - px(17)
                x: -r; y: -r; width: r * 2; height: width
                ShapePath {
                    fillColor: "transparent"; strokeColor: ov.cDanger
                    strokeWidth: Math.max(3, px(8)); capStyle: ShapePath.FlatCap
                    PathAngleArc { centerX: lay.ringR1 - px(17); centerY: lay.ringR1 - px(17); radiusX: lay.ringR1 - px(17); radiusY: lay.ringR1 - px(17); startAngle: 90; sweepAngle: 54 }
                }
            }
        }

        ObjectSlot {
            id: torus
            ov: lay.ov
            fn: "reboot"
            readonly property real half: lay.ringR1 - px(70)
            x: -half; y: -half; width: half * 2; height: width
            running: ov.active && !ov.closing && lay.visible
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -lay.ringR1 + px(52)
            text: "DRAG TO ROTATE"
            color: ov.soft
            font.family: ov.fontLabel; font.pixelSize: fs(14); font.letterSpacing: 2
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: lay.ringR1 - px(70)
            text: "DOUBLE-CLICK: REVERSE"
            color: ov.soft
            font.family: ov.fontLabel; font.pixelSize: fs(14); font.letterSpacing: 2
        }
    }

    // ---------- Bên phải ----------
    // chữ Hán lớn làm hình nền
    ScrambleText {
        x: lay.rightX - px(6); y: px(124)
        full: ov.kanji
        font.family: ov.fontKanji
        active: ov.textOn
        color: ov.rule
        font.pixelSize: fs(120)
        font.letterSpacing: px(14)
    }

    // tiêu đề khổng lồ + bóng tách kênh
    Text {
        x: lay.rightX - ov.gdxNow; y: px(246)
        visible: ov.glitchNow && ov.textOn
        text: title.text
        color: ov.cDanger; opacity: 0.75
        font.family: ov.fontTitle; font.pixelSize: fs(168); font.bold: true
    }
    Text {
        x: lay.rightX + ov.gdxNow; y: px(246)
        visible: ov.glitchNow && ov.textOn
        text: title.text
        color: ov.ghostB; opacity: 0.75
        font.family: ov.fontTitle; font.pixelSize: fs(168); font.bold: true
    }
    ScrambleText {
        id: title
        x: lay.rightX; y: px(246)
        full: "REBOOT"
        active: ov.textOn
        color: ov.ink
        font.family: ov.fontTitle; font.pixelSize: fs(168); font.bold: true
    }
    Rectangle { x: lay.rightX; y: px(462); width: lay.colW; height: 1; color: ov.ink }
    ScrambleText {
        x: lay.rightX + lay.colW - width; y: px(472)
        full: ov.tagText + "   KEY: SPACE"
        active: ov.textOn
        color: ov.soft
        font.family: ov.fontData; font.pixelSize: fs(15); font.letterSpacing: 2
    }
    Text {
        x: lay.rightX; y: px(512)
        width: Math.min(lay.colW, px(700))
        opacity: ov.contentP
        wrapMode: Text.WordWrap
        text: ov.descText
        color: ov.ink
        font.family: ov.fontLabel; font.pixelSize: fs(24)
    }

    // Yes / No: tab chữ lớn (đang chọn = mực đậm + gạch chân, còn lại = xám nhạt)
    Item {
        id: choiceRow
        x: lay.rightX; y: px(640)
        width: lay.colW; height: px(190)
        opacity: ov.contentP

        Rectangle {
            y: px(120); height: px(8); width: px(150)
            x: ov.choice * lay.tabStep + px(4)
            color: ov.ink
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        }
        Repeater {
            model: [ { t: "YES", h: "[Y]  RESTART NOW" }, { t: "NO", h: "[N]  KEEP WORKING" } ]
            delegate: Item {
                required property int index
                required property var modelData
                readonly property bool sel: ov.choice === index
                x: index * lay.tabStep
                width: lay.tabStep - px(24); height: choiceRow.height
                Text {
                    text: modelData.t
                    color: sel ? ov.ink : ov.rule
                    font.family: ov.fontTitle; font.pixelSize: fs(100); font.bold: true
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
                Text {
                    y: px(142)
                    text: modelData.h
                    color: sel ? ov.ink : ov.soft
                    font.family: ov.fontData; font.pixelSize: fs(16); font.letterSpacing: 1.5
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: ov.choiceRequested(index)
                    onClicked: index === 0 ? ov.confirmed() : ov.cancelled()
                }
            }
        }
    }

    // Dải STATUS 4 ô
    Item {
        id: strip
        x: lay.rightX; y: px(860)
        width: lay.colW; height: px(84)
        opacity: ov.contentP
        Rectangle { width: parent.width; height: 1; color: ov.ink }
        Rectangle { y: parent.height; width: parent.width; height: 1; color: ov.ink }
        Repeater {
            model: [
                ["ACTION", "Restart"],
                ["DELAY", "Now"],
                ["SESSION", ov.userName],
                ["TIME", Qt.formatDateTime(ov.now, "HH:mm:ss")]
            ]
            delegate: Item {
                required property int index
                required property var modelData
                x: index * (strip.width / 4)
                width: strip.width / 4; height: strip.height
                Rectangle { visible: index > 0; width: 1; height: parent.height - px(20); y: px(10); color: ov.rule }
                Text {
                    x: px(14); y: px(14)
                    text: modelData[0]
                    color: ov.soft
                    font.family: ov.fontLabel; font.pixelSize: fs(14); font.letterSpacing: 1.5
                }
                Text {
                    x: px(14); y: px(40)
                    text: modelData[1]
                    color: ov.ink
                    font.family: ov.fontLabel; font.pixelSize: fs(24); font.bold: true
                }
            }
        }
    }

    FooterLegend { ov: lay.ov; x: lay.m; y: lay.height - px(100); width: lay.width - 2 * lay.m }
}
