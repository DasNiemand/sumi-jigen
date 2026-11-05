import QtQuick

// Object "torus" theo Object API của SUMI (docs/OBJECT_API.md): torus dither tự xoay (bọc PointObject, shape torus).
// Thuộc tính chuẩn: palette (cần ink, soft), running, size, speed (hệ số tốc độ xoay), interactive, grid.
// grid = 0: dùng lưới mặc định của object (54); 44..56: lưới do người dùng chọn.
Item {
    id: obj
    property var palette: ({})
    property bool running: true
    property real size: 300
    property real speed: 1.0
    property bool interactive: true
    property int grid: 0
    width: size; height: size

    PointObject {
        anchors.fill: parent
        shape: "torus"
        ink: obj.palette.ink !== undefined ? obj.palette.ink : "#1a1a1a"
        soft: obj.palette.soft !== undefined ? obj.palette.soft : "#777777"
        cells: (obj.grid >= 44 && obj.grid <= 56) ? obj.grid : 54
        idleSpeed: 0.016 * obj.speed
        // speed = 0 và không kéo được thì không cần vẽ lại liên tục
        running: obj.running && (obj.speed > 0 || obj.interactive)
        interactive: obj.interactive
    }
}
