import QtQuick

// Ô chứa object của một function: nạp objects/<id>.qml theo cấu hình (ov.objectFor(fn)).
// Object lỗi khi nạp thì tự rơi về object mặc định của function. Vị trí/kích thước do layout đặt.
Item {
    id: slot
    required property var ov
    property string fn: "shutdown"
    property bool running: true

    readonly property var sel: ov.objectFor(fn)
    readonly property string wantId: sel.id
    property bool failed: false
    readonly property string useId: failed ? ov.objectDefault(fn) : wantId
    onWantIdChanged: failed = false

    Loader {
        id: ld
        anchors.fill: parent
        source: "objects/" + slot.useId + ".qml"
        onStatusChanged: if (status === Loader.Error && !slot.failed) slot.failed = true
    }
    Binding { target: ld.item; property: "palette"; value: slot.ov.objPalette; when: ld.item !== null }
    Binding { target: ld.item; property: "running"; value: slot.running; when: ld.item !== null }
    Binding { target: ld.item; property: "size"; value: Math.min(slot.width, slot.height); when: ld.item !== null }
    Binding { target: ld.item; property: "speed"; value: slot.sel.speed; when: ld.item !== null }
    Binding { target: ld.item; property: "interactive"; value: slot.sel.interactive; when: ld.item !== null }
    Binding { target: ld.item; property: "grid"; value: slot.sel.grid; when: ld.item !== null }
}
