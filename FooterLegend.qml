import QtQuick

// Chân trang dùng chung: ⊗ CONFIRM  ◎ BACK ... gợi ý bên phải (kiểu NieR).
Item {
    id: f
    required property var ov
    height: ov.px(34)
    opacity: ov.contentP

    Row {
        spacing: f.ov.px(34)
        anchors.verticalCenter: parent.verticalCenter
        Row {
            spacing: f.ov.px(12)
            Rectangle {
                width: f.ov.px(28); height: width; radius: width / 2
                color: "transparent"; border.width: 2; border.color: f.ov.ink
                Text { anchors.centerIn: parent; text: "×"; color: f.ov.ink; font.pixelSize: f.ov.fs(20); font.bold: true }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: f.ov.confirmLabel; color: f.ov.ink
                font.family: f.ov.fontLabel; font.pixelSize: f.ov.fs(19); font.bold: true; font.letterSpacing: 1
            }
        }
        Row {
            spacing: f.ov.px(12)
            Rectangle {
                width: f.ov.px(28); height: width; radius: width / 2
                color: "transparent"; border.width: 2; border.color: f.ov.ink
                Rectangle { anchors.centerIn: parent; width: f.ov.px(10); height: width; radius: width / 2; color: f.ov.ink }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: f.ov.backLabel; color: f.ov.ink
                font.family: f.ov.fontLabel; font.pixelSize: f.ov.fs(19); font.bold: true; font.letterSpacing: 1
            }
        }
    }
    Row {
        visible: f.ov.canSwitch
        anchors.centerIn: parent
        spacing: f.ov.px(12)
        Repeater {
            model: ["Q", "E"]
            delegate: Rectangle {
                required property string modelData
                width: f.ov.px(30); height: width
                color: "transparent"; border.width: 1; border.color: f.ov.ink
                Text { anchors.centerIn: parent; text: modelData; color: f.ov.ink
                    font.family: f.ov.fontData; font.pixelSize: f.ov.fs(15); font.bold: true }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "SWITCH FUNCTION"
            color: f.ov.soft
            font.family: f.ov.fontLabel; font.pixelSize: f.ov.fs(17); font.letterSpacing: 1.5
        }
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: f.ov.px(70)
        anchors.verticalCenter: parent.verticalCenter
        text: f.ov.footerHint
        color: f.ov.soft
        font.family: f.ov.fontLabel
        font.pixelSize: f.ov.fs(19)
    }
}
