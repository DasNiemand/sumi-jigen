import QtQuick
import QtQuick.Shapes
import "lib"
import "objects"

// Layout SHUTDOWN (và màn cảnh báo cuối): NieR cổ điển 3 cột
// danh sách trái / quả cầu dither giữa / bảng STATUS phải.
Item {
    id: lay
    required property var ov
    function px(n) { return ov.px(n) }
    function fs(n) { return ov.fs(n) }

    readonly property real m: px(100)
    readonly property real sideW: px(470)
    readonly property real colGap: px(56)
    readonly property real topY: px(196)
    readonly property real leftX: m
    readonly property real rightX: width - m - sideW
    readonly property real centerX: leftX + sideW + colGap
    readonly property real centerW: rightX - colGap - centerX
    readonly property real globeCX: centerX + centerW / 2
    readonly property real globeCY: topY + px(418)

    // ---------- Chữ Hán dọc ở lề trái ----------
    ScrambleText {
        x: px(46)
        y: lay.topY + px(8)
        full: ov.kanji.split("").join("\n")
        font.family: ov.fontKanji
        active: ov.textOn
        color: ov.soft
        lineHeight: 1.15
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: fs(26)
        font.letterSpacing: 2
    }

    // ---------- Thanh nav ----------
    Item {
        id: nav
        x: 0; y: px(62)
        width: lay.width
        height: px(44)
        opacity: ov.contentP

        NavTabs { ov: lay.ov; spread: true; width: parent.width; height: parent.height; tabW: px(240) }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: lay.m
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(ov.now, "HH:mm")
            color: ov.ink
            font.family: ov.fontData
            font.pixelSize: fs(20)
            font.bold: true
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: lay.m + px(92)
            anchors.verticalCenter: parent.verticalCenter
            text: ov.hexStream
            color: ov.soft
            font.family: ov.fontData
            font.pixelSize: fs(14)
            font.letterSpacing: 1
        }
    }

    // ===================================================================
    // CỘT TRÁI: danh sách + sequence
    // ===================================================================
    Item {
        id: leftCol
        x: lay.leftX
        y: lay.topY
        width: lay.sideW
        height: lay.height - lay.topY - px(150)
        opacity: ov.contentP
        readonly property real rowH: px(56)

        Rectangle { width: parent.width; height: 1; color: ov.ink }

        Repeater {
            model: ov.listRows
            delegate: Item {
                id: lrow
                required property int index
                required property var modelData
                readonly property bool sel: index === ov.listSel
                y: 1 + index * leftCol.rowH
                width: leftCol.width
                height: leftCol.rowH

                Rectangle {
                    x: lrow.sel ? 0 : -px(8)
                    width: parent.width
                    height: parent.height - 1
                    color: lrow.sel ? ov.ink
                         : (lmouse.containsMouse ? ov.wash : "transparent")
                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 110 } }
                }
                Text {
                    x: px(14)
                    anchors.verticalCenter: parent.verticalCenter
                    text: lrow.modelData.label
                    color: lrow.sel ? ov.paper : ov.ink
                    font.family: ov.fontLabel
                    font.pixelSize: fs(23)
                    font.bold: true
                    Behavior on color { ColorAnimation { duration: 110 } }
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: px(14)
                    anchors.verticalCenter: parent.verticalCenter
                    text: lrow.modelData.right
                    color: lrow.sel ? ov.paper : ov.soft
                    font.family: ov.fontData
                    font.pixelSize: fs(20)
                    font.bold: true
                    Behavior on color { ColorAnimation { duration: 110 } }
                }
                MouseArea {
                    id: lmouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: if (!ov.isTimer) ov.choiceRequested(lrow.index)
                    onClicked: {
                        if (ov.isTimer) ov.indexRequested(lrow.index)
                        else if (lrow.index === 0) ov.confirmed()
                        else ov.cancelled()
                    }
                }
            }
        }

        // Đường kẻ cuối danh sách + thanh cuộn trang trí (như ref NieR)
        Rectangle {
            y: 1 + ov.listRows.length * leftCol.rowH
            width: parent.width
            height: 1
            color: ov.ink
            visible: ov.listRows.length > 0
        }
        Rectangle {
            x: parent.width + px(10)
            y: 0
            width: 1
            height: Math.max(px(112), ov.listRows.length * leftCol.rowH)
            color: ov.rule
            visible: ov.listRows.length > 0
        }
        Rectangle {
            x: parent.width + px(9)
            y: 0
            width: px(3)
            height: px(52)
            color: ov.ink
            visible: ov.listRows.length > 0
        }

        // Sequence (mono)
        Item {
            id: seq
            x: 0
            y: (ov.listRows.length > 0 ? 1 + ov.listRows.length * leftCol.rowH : 0) + px(46)
            width: parent.width

            Text {
                text: "SEQUENCE"
                color: ov.ink
                font.family: ov.fontLabel
                font.pixelSize: fs(20)
                font.bold: true
                font.letterSpacing: 1.5
            }
            Rectangle { y: px(34); width: parent.width; height: 1; color: ov.ink }
            Repeater {
                model: ov.seqLines
                delegate: Item {
                    required property int index
                    required property string modelData
                    y: px(46) + index * px(40)
                    width: seq.width
                    height: px(40)
                    ScrambleText {
                        anchors.verticalCenter: parent.verticalCenter
                        x: px(2)
                        full: modelData
                        active: ov.textOn
                        color: ov.ink
                        font.family: ov.fontData
                        font.pixelSize: fs(18)
                        font.letterSpacing: 1
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: ov.rule; opacity: 0.6 }
                }
            }
        }
    }

    // ===================================================================
    // CỘT GIỮA: tiêu đề + quả cầu + mô tả
    // ===================================================================
    Item {
        id: centerCol
        x: lay.centerX
        y: lay.topY
        width: lay.centerW
        height: lay.height - lay.topY - px(150)

        Rectangle { width: parent.width; height: 1; color: ov.ink }

        // Tiêu đề + 2 lớp bóng tách kênh màu
        Text {
            x: px(2) - ov.gdxNow; y: px(4)
            visible: ov.glitchNow && ov.textOn
            text: titleText.text
            color: ov.cDanger
            opacity: 0.75
            font.family: ov.fontTitle
            font.pixelSize: fs(90)
            font.bold: true
        }
        Text {
            x: px(2) + ov.gdxNow; y: px(4)
            visible: ov.glitchNow && ov.textOn
            text: titleText.text
            color: ov.ghostB
            opacity: 0.75
            font.family: ov.fontTitle
            font.pixelSize: fs(90)
            font.bold: true
        }
        ScrambleText {
            id: titleText
            x: px(2); y: px(4)
            full: ov.titleText
            active: ov.textOn
            color: ov.ink
            font.family: ov.fontTitle
            font.pixelSize: fs(90)
            font.bold: true
        }
        ScrambleText {
            anchors.right: parent.right
            y: px(112)
            full: ov.tagText
            active: ov.textOn
            color: ov.ink
            font.family: ov.fontLabel
            font.pixelSize: fs(15)
            font.bold: true
            font.letterSpacing: 1.5
        }
        Rectangle { y: px(138); width: parent.width; height: 1; color: ov.ink }
        Text {
            anchors.right: parent.right
            y: px(148)
            opacity: ov.contentP
            text: ov.isWarn ? "ABORT: ESC" : "KEY: SPACE"
            color: ov.soft
            font.family: ov.fontLabel
            font.pixelSize: fs(15)
            font.letterSpacing: 1.5
        }
    }

    // ---------- Quả cầu + các vòng trang trí ----------
    Item {
        id: globeBox
        x: lay.globeCX
        y: lay.globeCY
        width: 0; height: 0
        opacity: ov.contentP
        scale: 0.85 + 0.15 * ov.contentP

        readonly property real gR: px(150)     // bán kính quả cầu
        readonly property real arcR: px(180)   // vòng tiến trình / vòng mảnh
        readonly property real tickR: px(228)  // mép ngoài vòng vạch chia

        // Vòng tròn mảnh (Ueda)
        Rectangle {
            x: -globeBox.arcR; y: -globeBox.arcR
            width: globeBox.arcR * 2; height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: ov.rule
        }

        // Vòng vạch chia, xoay rất chậm
        Item {
            id: ticks
            NumberAnimation on rotation { from: 0; to: 360; duration: 120000; loops: Animation.Infinite; running: ov.active }
            Repeater {
                model: 72
                delegate: Item {
                    required property int index
                    rotation: index * 5
                    Rectangle {
                        readonly property bool major: index % 6 === 0
                        x: -width / 2
                        y: -globeBox.tickR
                        width: major ? Math.max(2, px(2)) : 1
                        height: major ? px(16) : px(8)
                        color: major ? ov.ink : ov.soft
                    }
                }
            }
        }

        // Vòng tiến trình (timer & warning): vết mờ + cung đậm + chấm quét đỏ
        Shape {
            visible: ov.isTimer || ov.isWarn
            x: -globeBox.arcR; y: -globeBox.arcR
            width: globeBox.arcR * 2; height: width
            ShapePath {
                fillColor: "transparent"
                strokeColor: ov.ink
                strokeWidth: Math.max(3, px(7))
                capStyle: ShapePath.FlatCap
                PathAngleArc {
                    centerX: globeBox.arcR; centerY: globeBox.arcR
                    radiusX: globeBox.arcR; radiusY: globeBox.arcR
                    startAngle: -90
                    sweepAngle: Math.min(359.9, 360 * ov.ringFracAnim)
                }
            }
        }
        Item {
            visible: ov.isTimer || ov.isWarn
            rotation: ov.scanPos * 360
            Rectangle {
                x: -px(6); y: -globeBox.arcR - px(6)
                width: px(12); height: px(12)
                color: ov.cDanger
            }
        }

        // Reboot: 2 cung xoay ngược chiều nhau
        Item {
            visible: ov.isReboot
            NumberAnimation on rotation { from: 0; to: 360; duration: 3600; loops: Animation.Infinite; running: ov.active && ov.isReboot }
            Shape {
                x: -globeBox.arcR; y: -globeBox.arcR
                width: globeBox.arcR * 2; height: width
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: ov.ink
                    strokeWidth: Math.max(3, px(7))
                    capStyle: ShapePath.FlatCap
                    PathAngleArc { centerX: globeBox.arcR; centerY: globeBox.arcR; radiusX: globeBox.arcR; radiusY: globeBox.arcR; startAngle: -90; sweepAngle: 110 }
                }
            }
        }
        Item {
            visible: ov.isReboot
            NumberAnimation on rotation { from: 360; to: 0; duration: 5400; loops: Animation.Infinite; running: ov.active && ov.isReboot }
            Shape {
                x: -globeBox.arcR; y: -globeBox.arcR
                width: globeBox.arcR * 2; height: width
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: ov.cDanger
                    strokeWidth: Math.max(3, px(7))
                    capStyle: ShapePath.FlatCap
                    PathAngleArc { centerX: globeBox.arcR; centerY: globeBox.arcR; radiusX: globeBox.arcR; radiusY: globeBox.arcR; startAngle: 90; sweepAngle: 60 }
                }
            }
        }

        // Quả cầu (kéo để xoay, bấm đúp đổi chiều)
        GlobeObject {
            x: -globeBox.gR; y: -globeBox.gR
            width: globeBox.gR * 2; height: width
            ink: ov.ink
            soft: ov.soft
            running: ov.active && !ov.closing && lay.visible
        }
    }

    // ---------- Dòng thông tin + mô tả dưới quả cầu ----------
    Item {
        id: descBox
        x: lay.centerX
        y: lay.globeCY + px(244)
        width: lay.centerW
        opacity: ov.contentP

        Text {
            text: ov.isTimer ? ("SELECTED: " + (ov.selectedIndex + 1) + "/" + ov.checkpoints.length)
                : ov.isWarn ? "STATUS: ARMED"
                : ("SELECTED: " + (ov.choice + 1) + "/2")
            color: ov.ink
            font.family: ov.fontLabel
            font.pixelSize: fs(17)
            font.bold: true
        }
        Text {
            anchors.right: parent.right
            text: "DRAG TO ROTATE"
            color: ov.soft
            font.family: ov.fontLabel
            font.pixelSize: fs(15)
            font.letterSpacing: 1.5
        }
        Rectangle { y: px(28); width: parent.width; height: 1; color: ov.ink }
        Text {
            y: px(38)
            width: parent.width
            wrapMode: Text.WordWrap
            text: ov.descText
            color: ov.ink
            font.family: ov.fontLabel
            font.pixelSize: fs(18)
        }
        Rectangle { y: px(104); width: parent.width; height: 1; color: ov.ink }
    }

    // ===================================================================
    // CỘT PHẢI: STATUS + phím
    // ===================================================================
    Item {
        id: rightCol
        x: lay.rightX
        y: lay.topY
        width: lay.sideW
        opacity: ov.contentP

        Text {
            text: "STATUS"
            color: ov.ink
            font.family: ov.fontLabel
            font.pixelSize: fs(20)
            font.bold: true
            font.letterSpacing: 1.5
        }
        Rectangle { y: px(34); width: parent.width; height: 1; color: ov.ink }
        Repeater {
            model: ov.statusRows
            delegate: Item {
                required property int index
                required property var modelData
                y: px(42) + index * px(44)
                width: rightCol.width
                height: px(44)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData[0]
                    color: ov.soft
                    font.family: ov.fontLabel
                    font.pixelSize: fs(18)
                    font.letterSpacing: 1
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData[1]
                    color: ov.ink
                    font.family: ov.fontLabel
                    font.pixelSize: fs(19)
                    font.bold: true
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: ov.rule; opacity: 0.7 }
            }
        }

        Text {
            y: px(42) + 5 * px(44) + px(20)
            text: "Controls:"
            color: ov.soft
            font.family: ov.fontLabel
            font.pixelSize: fs(18)
        }
        Grid {
            id: keyGrid
            y: px(42) + 5 * px(44) + px(58)
            columns: 4
            spacing: px(14)
            Repeater {
                model: ["A", "D", "Q", "E", "Y", "N", "SPC", "ESC"]
                delegate: Rectangle {
                    required property string modelData
                    width: px(98); height: px(62)
                    color: "transparent"
                    border.width: 1
                    border.color: ov.ink
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: ov.ink
                        font.family: ov.fontData
                        font.pixelSize: fs(modelData.length > 1 ? 17 : 22)
                        font.bold: true
                    }
                }
            }
        }
        Text {
            y: keyGrid.y + px(62) * 2 + px(14) + px(24)
            text: "AWAITING INPUT" + (blink.on ? "_" : " ")
            color: ov.soft
            font.family: ov.fontData
            font.pixelSize: fs(17)
            font.letterSpacing: 3
            Timer { id: blink; property bool on: true; interval: 520; repeat: true; running: ov.active; onTriggered: on = !on }
        }
    }


    FooterLegend { ov: lay.ov; x: lay.m; y: lay.height - px(100); width: lay.width - 2 * lay.m }
}
