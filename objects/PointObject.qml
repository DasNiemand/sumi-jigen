import QtQuick

// Vật thể 3D pixel/dither dựng bằng "rải điểm" lên bề mặt tham số (torus hoặc đồng hồ cát),
// z-buffer theo ô, đổ bóng theo hướng sáng rồi dither Bayer 4x4. Kéo chuột để xoay,
// thả ra có quán tính, bấm đúp để đổi chiều tự xoay.
Item {
    id: o

    property string shape: "torus"          // torus | hourglass
    property color ink: "#1a1a1a"
    property color soft: "#777777"
    property int cells: 52
    property real rotY: 0.5
    property real rotX: 0.45
    property real idleSpeed: 0.016
    property real tilt: 0.45
    property bool running: true
    readonly property bool dragging: dragArea.pressed
    property real spinVel: idleSpeed

    readonly property string inkS: ink
    readonly property string softS: soft
    onInkChanged: cv.requestPaint()
    onSoftChanged: cv.requestPaint()

    // Hình học: mảng phẳng các điểm + pháp tuyến
    property var geo: ({ n: 0, x: [], y: [], z: [], nx: [], ny: [], nz: [], kind: [], tex: [] })

    function add(g, x, y, z, nx, ny, nz, kind, tex) {
        g.x.push(x); g.y.push(y); g.z.push(z)
        g.nx.push(nx); g.ny.push(ny); g.nz.push(nz)
        g.kind.push(kind); g.tex.push(tex)
        g.n++
    }

    function build() {
        const g = { n: 0, x: [], y: [], z: [], nx: [], ny: [], nz: [], kind: [], tex: [] }
        const TAU = Math.PI * 2
        if (shape === "torus") {
            const R = 0.64, r = 0.27, U = 120, V = 46
            for (let iu = 0; iu < U; iu++) {
                const u = TAU * iu / U, cu = Math.cos(u), su = Math.sin(u)
                for (let iv = 0; iv < V; iv++) {
                    const v = TAU * iv / V, cv2 = Math.cos(v), sv = Math.sin(v)
                    const tex = (Math.floor(iu * 12 / U) + Math.floor(iv * 6 / V)) & 1
                    add(g, (R + r * cv2) * cu, (R + r * cv2) * su, r * sv, cv2 * cu, cv2 * su, sv, 1, tex)
                }
            }
        } else {
            const H = 0.86
            // thân thuỷ tinh (mặt tròn xoay quanh trục Y, thắt ở giữa)
            const T = 48, A = 80
            for (let it = 0; it <= T; it++) {
                const y = -H + 2 * H * it / T
                const s = Math.abs(y) / H
                const rad = 0.09 + 0.66 * Math.pow(s, 1.45)
                const dr = (y === 0 ? 0 : 0.66 * 1.45 * Math.pow(s, 0.45) / H * (y > 0 ? 1 : -1))
                const ln = Math.sqrt(1 + dr * dr)
                for (let ia = 0; ia < A; ia++) {
                    const th = TAU * ia / A, c = Math.cos(th), sn = Math.sin(th)
                    add(g, rad * c, y, rad * sn, c / ln, -dr / ln, sn / ln, 2, 0)
                }
            }
            // 2 tấm đế
            for (let sg = -1; sg <= 1; sg += 2) {
                const yy = sg * (H + 0.05)
                for (let k = 1; k <= 14; k++) {
                    const rr = 0.86 * k / 14
                    const cnt = Math.max(8, Math.round(TAU * rr * 46))
                    for (let ia = 0; ia < cnt; ia++) {
                        const th = TAU * ia / cnt
                        add(g, rr * Math.cos(th), yy, rr * Math.sin(th), 0, sg, 0, 1, k & 1)
                    }
                }
                for (let ia = 0; ia < 140; ia++) {
                    const th = TAU * ia / 140, c = Math.cos(th), sn = Math.sin(th)
                    for (let q = 0; q < 4; q++)
                        add(g, 0.86 * c, yy - sg * 0.012 * q, 0.86 * sn, c, 0, sn, 1, 0)
                }
            }
            // 4 trụ
            for (let k = 0; k < 4; k++) {
                const ang = Math.PI / 4 + k * Math.PI / 2
                const cx = 0.74 * Math.cos(ang), cz = 0.74 * Math.sin(ang)
                for (let iy = 0; iy <= 44; iy++) {
                    const y = -(H + 0.05) + 2 * (H + 0.05) * iy / 44
                    for (let ia = 0; ia < 8; ia++) {
                        const th = TAU * ia / 8, c = Math.cos(th), sn = Math.sin(th)
                        add(g, cx + 0.04 * c, y, cz + 0.04 * sn, c, 0, sn, 1, 0)
                    }
                }
            }
        }
        geo = g
        cv.requestPaint()
    }
    // Chỉ dựng sau khi object đã tạo xong (gọi build() lúc đang khởi tạo sẽ lỗi 'Math undefined')
    property bool ready: false
    onShapeChanged: { if (ready) build() }
    Component.onCompleted: { ready = true; build() }

    Canvas {
        id: cv
        anchors.fill: parent
        readonly property var bayer: [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
        property var zb: null
        property var vb: null
        property var kb: null

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const g = o.geo
            if (!g || g.n === 0) return
            const N = o.cells
            const cs = width / N
            if (!zb || zb.length !== N * N) {
                zb = new Float32Array(N * N)
                vb = new Float32Array(N * N)
                kb = new Uint8Array(N * N)
            }
            zb.fill(-9)
            kb.fill(0)
            const ca = Math.cos(o.rotX), sa = Math.sin(o.rotX)
            const cb = Math.cos(o.rotY), sb = Math.sin(o.rotY)
            const lx = -0.55, ly = 0.45, lz = 0.70
            const ln = Math.sqrt(lx * lx + ly * ly + lz * lz)
            const sc = (o.shape === "hourglass") ? 0.84 : 0.97
            const X = g.x, Y = g.y, Z = g.z, NX = g.nx, NY = g.ny, NZ = g.nz, K = g.kind, T = g.tex

            for (let i = 0; i < g.n; i++) {
                const x = X[i], y = Y[i], z = Z[i]
                const x1 = x * cb + z * sb
                const z1 = -x * sb + z * cb
                const y2 = y * ca - z1 * sa
                const z2 = y * sa + z1 * ca
                const ci = Math.floor((x1 * 0.5 * sc + 0.5) * N)
                const cj = Math.floor((0.5 - y2 * 0.5 * sc) * N)
                if (ci < 0 || cj < 0 || ci >= N || cj >= N) continue
                const idx = cj * N + ci
                if (z2 <= zb[idx]) continue
                zb[idx] = z2
                const nx = NX[i], ny = NY[i], nz = NZ[i]
                const nx1 = nx * cb + nz * sb
                const nz1 = -nx * sb + nz * cb
                const ny2 = ny * ca - nz1 * sa
                const nz2 = ny * sa + nz1 * ca
                const L = Math.max(0, (nx1 * lx + ny2 * ly + nz2 * lz) / ln)
                if (K[i] === 2) {
                    vb[idx] = 0.08 + 0.55 * L
                    kb[idx] = 2
                } else {
                    vb[idx] = (0.42 + 0.58 * L) * (T[i] ? 0.72 : 1.0)
                    kb[idx] = 1
                }
            }

            const pad = 0.5
            for (let j = 0; j < N; j++) {
                for (let i = 0; i < N; i++) {
                    const idx = j * N + i
                    const k = kb[idx]
                    if (k === 0) continue
                    const thr = (cv.bayer[(i & 3) + (j & 3) * 4] + 0.5) / 16
                    if (vb[idx] > thr) {
                        ctx.fillStyle = (k === 1) ? o.inkS : o.softS
                        ctx.fillRect(i * cs, j * cs, cs - pad, cs - pad)
                    }
                }
            }
        }
    }

    Timer {
        interval: 33
        repeat: true
        running: o.running
        onTriggered: {
            if (!dragArea.pressed) {
                o.spinVel += (o.idleSpeed - o.spinVel) * 0.035
                o.rotY += o.spinVel
                o.rotX += (o.tilt - o.rotX) * 0.03
            }
            cv.requestPaint()
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
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
            o.rotY += dx * 0.014
            o.rotX = Math.max(-1.3, Math.min(1.3, o.rotX + dy * 0.010))
            cv.requestPaint()
        }
        onReleased: o.spinVel = Math.max(-0.35, Math.min(0.35, lastDx * 0.014))
        onDoubleClicked: { o.idleSpeed = -o.idleSpeed; o.spinVel = o.idleSpeed * 6 }
    }
}
