import QtQuick

// Quả cầu pixel/dither (Bayer 4x4) tự xoay, kéo chuột để xoay tay, thả ra thì quán tính
// rồi từ từ về tốc độ tự xoay. Lục địa sinh theo hàm nhiễu nên không cần texture.
Item {
    id: g

    property color ink: "#1a1a1a"
    property color soft: "#777777"
    property int cells: 44
    property real rotY: 0.6
    property real rotX: 0.35
    property real idleSpeed: 0.012
    property real tilt: 0.35
    property bool running: true
    property bool interactive: true      // false: không kéo/xoay được, con trỏ không đổi
    readonly property bool dragging: dragArea.pressed
    property real spinVel: idleSpeed

    readonly property string inkS: ink
    readonly property string softS: soft
    onInkChanged: cv.requestPaint()
    onSoftChanged: cv.requestPaint()

    Canvas {
        id: cv
        anchors.fill: parent

        readonly property var bayer: [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

        function landV(lon, lat) {
            return Math.sin(2 * lon + 1.3) * Math.cos(1.5 * lat + 0.4)
                 + 0.7 * Math.sin(3 * lon - 2.1 * lat + 2.0)
                 + 0.5 * Math.cos(5 * lon + 3.1 * lat)
                 + 0.35 * Math.sin(6 * lat + lon)
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const N = g.cells
            const cs = width / N
            const ca = Math.cos(g.rotX), sa = Math.sin(g.rotX)
            const cb = Math.cos(g.rotY), sb = Math.sin(g.rotY)
            const lx = -0.55, ly = 0.45, lz = 0.70
            const ln = Math.sqrt(lx * lx + ly * ly + lz * lz)
            const pad = 0.5

            function inside(i, j) {
                const x = ((i + 0.5) / N) * 2 - 1
                const y = 1 - ((j + 0.5) / N) * 2
                return x * x + y * y <= 1
            }

            for (let j = 0; j < N; j++) {
                for (let i = 0; i < N; i++) {
                    if (!inside(i, j)) continue
                    const x = ((i + 0.5) / N) * 2 - 1
                    const y = 1 - ((j + 0.5) / N) * 2
                    const z = Math.sqrt(Math.max(0, 1 - x * x - y * y))

                    // viền ngoài của đĩa
                    if (!inside(i - 1, j) || !inside(i + 1, j) || !inside(i, j - 1) || !inside(i, j + 1)) {
                        ctx.fillStyle = g.inkS
                        ctx.fillRect(i * cs, j * cs, cs - pad, cs - pad)
                        continue
                    }

                    // quay ngược về toạ độ model: Ry(-b) * Rx(-a)
                    const y1 = y * ca + z * sa
                    const z1 = -y * sa + z * ca
                    const x2 = x * cb - z1 * sb
                    const z2 = x * sb + z1 * cb
                    const lon = Math.atan2(x2, z2)
                    const lat = Math.asin(Math.max(-1, Math.min(1, y1)))

                    const L = Math.max(0, (x * lx + y * ly + z * lz) / ln)
                    const land = landV(lon, lat) > 0.42
                    const v = land ? (0.40 + 0.55 * L) : (0.02 + 0.22 * L * L)
                    const thr = (cv.bayer[(i & 3) + (j & 3) * 4] + 0.5) / 16
                    if (v > thr) {
                        ctx.fillStyle = land ? g.inkS : g.softS
                        ctx.fillRect(i * cs, j * cs, cs - pad, cs - pad)
                    }
                }
            }
        }
    }

    Timer {
        interval: 33
        repeat: true
        running: g.running
        onTriggered: {
            if (!dragArea.pressed) {
                g.spinVel += (g.idleSpeed - g.spinVel) * 0.035
                g.rotY += g.spinVel
                g.rotX += (g.tilt - g.rotX) * 0.03
            }
            cv.requestPaint()
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: interactive
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real lastX: 0
        property real lastY: 0
        property real lastDx: 0
        onPressed: (mouse) => { lastX = mouse.x; lastY = mouse.y; lastDx = 0 }
        onPositionChanged: (mouse) => {
            if (!pressed) return
            const dx = mouse.x - lastX
            const dy = mouse.y - lastY
            lastX = mouse.x
            lastY = mouse.y
            lastDx = dx
            g.rotY += dx * 0.014
            g.rotX = Math.max(-1.2, Math.min(1.2, g.rotX + dy * 0.010))
            cv.requestPaint()
        }
        onReleased: g.spinVel = Math.max(-0.35, Math.min(0.35, lastDx * 0.014))
        // Bấm đúp = đổi chiều xoay
        onDoubleClicked: { g.idleSpeed = -g.idleSpeed; g.spinVel = g.idleSpeed * 6 }
    }
}
