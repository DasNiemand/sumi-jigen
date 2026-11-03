import QtQuick
import QtQuick.Shapes
import "lib"

// JIGEN 時限 - View thuần (không Process, không thoát tiến trình): overlay toàn màn hình cho 4 trạng thái: shutdown / reboot / shutdown30 (hẹn giờ) / warning (đếm ngược cuối).
//  - Bố cục NieR:Automata: giấy kem, thanh nav trên cùng, danh sách trái + thanh chọn tối,
//    tiêu đề giữa kẹp giữa 2 đường kẻ, bảng STATUS bên phải, chú thích phím dưới đáy.
//  - Chút Ueda: khung viền mảnh, vòng tròn mỏng quanh vật thể, chữ Hán dọc ở lề trái.
//  - Chút terminal: bật/tắt kiểu CRT, scanline, chữ giải mã, glitch tách kênh màu, luồng hex, vát góc khung.
// Màu: dẫn xuất hoàn toàn từ 4 màu nền do shell.qml truyền vào (lấy từ Noctalia).
Item {
    id: ov

    // ===== Input =====
    property string mode: "shutdown"        // shutdown | reboot | shutdown30 | warning
    property bool active: false             // true từ lúc nội dung được phép hiện
    property bool closing: false            // true => chạy animation tắt (glitch -> CRT thu lại)
    property string bgColor: "#101213"      // surface
    property string fgColor: "#c3c3c4"      // on_surface
    property string mutedColor: "#59636e"   // outline
    property string accentColor: "#717878"  // primary
    property string dangerColor: "#E63946"
    property string fontTitle: "sans-serif"     // vai trò title
    property string fontLabel: "sans-serif"     // vai trò label
    property string fontData: "monospace"       // vai trò data
    property string fontNumeral: "monospace"    // vai trò numeral (số lớn)
    property string fontKanji: Qt.application.font.family   // vai trò kanji (mặc định = font hệ thống như bản gốc)
    property real tint: 0.12
    property real inkDarken: 1.5
    property int bootMs: 900
    property int outroMs: 460
    property real scanOpacity: 0.05
    property bool scanlinesEnabled: true
    property bool glitchEnabled: true
    property real scaleBoost: 1
    property string userName: ""
    property int choice: 0                  // shutdown/reboot: 0 = Yes, 1 = No
    property var checkpoints: [5, 15, 30, 60]
    property int selectedIndex: 2
    property string countdownText: "00:00"  // warning
    property real countdownFraction: 1      // warning: 0..1
    property int warningSec: 90
    property bool standby: false            // true: màn hình PHỤ (không có focus) -> LayoutStandby
    property bool managing: false           // true: mở lại overlay khi timer đang chạy (huỷ / đổi giờ / giữ)
    property int countdownSec: 0            // managing: số giây còn lại của timer đang chạy
    property var stats: ({ upSec: 0, memTotalKb: 0, memAvailKb: 0, batPct: -1, batStatus: "", tempC: -1, load: "0.00" })

    signal choiceRequested(int index)
    signal indexRequested(int index)
    signal confirmed()
    signal cancelled()
    signal switchRequested(string mode)   // chuyển sang chức năng khác ngay trong overlay

    // ===== Kích thước (1.0 ở 1920x1080) =====
    readonly property real u: Math.max(0.6, Math.min(width / 1920, height / 1080)) * scaleBoost
    function px(n) { return Math.max(1, Math.round(n * u)) }
    function fs(n) { return Math.max(8, Math.round(n * u)) }
    function clamp01(v) { return Math.max(0, Math.min(1, v)) }
    function two(n) { return (n < 10 ? "0" : "") + n }
    function mix(a, b, t) { return Qt.rgba(a.r * (1 - t) + b.r * t, a.g * (1 - t) + b.g * t, a.b * (1 - t) + b.b * t, 1) }
    function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

    // ===== Bảng màu: công thức nằm ở lib/SumiTheme.qml =====
    SumiTheme { id: th; bgColor: ov.bgColor; fgColor: ov.fgColor; accentColor: ov.accentColor; tint: ov.tint; inkDarken: ov.inkDarken }
    readonly property color cDanger: dangerColor
    readonly property color paper: th.paper
    readonly property color ink: th.ink
    readonly property color soft: th.soft
    readonly property color rule: th.rule
    readonly property color wash: th.wash
    readonly property color ghostB: th.ghostB

    // ===== Dữ liệu theo mode =====
    readonly property bool isTimer: mode === "shutdown30"
    readonly property bool isWarn: mode === "warning"
    readonly property bool isReboot: mode === "reboot"
    readonly property int minutes: checkpoints[selectedIndex]
    readonly property int navIndex: isReboot ? 1 : (isTimer ? 2 : 0)
    readonly property string titleText: isReboot ? "REBOOT" : isTimer ? (minutes + " MIN") : isWarn ? countdownText : "SHUTDOWN"
    readonly property string tagText: isReboot ? "RESTART" : isTimer ? (managing ? "TIMER RUNNING" : "SHUTDOWN TIMER") : isWarn ? "FINAL COUNTDOWN" : "POWER OFF"
    readonly property string kanji: isReboot ? "再起動" : isTimer ? "時限" : isWarn ? "警告" : "終了"
    readonly property string descText: isReboot ? "Closes every running application and restarts the machine."
        : isTimer ? (managing ? "Timer is running. Re-arm it with another delay, cancel it, or press ESC to keep it running."
                                : "Screens go dark now. The machine powers off when the timer reaches zero.")
        : isWarn ? "Power-off begins when the counter reaches zero. Press ESC to abort."
        : "Closes every running application and powers the machine off."
    readonly property string footerHint: isTimer ? (managing ? "Timer running." : "Select delay.") : isWarn ? "Abort or wait." : "Select option."
    readonly property var listRows: isTimer
        ? checkpoints.map(function (m) { return { label: m + " MIN", right: "T-" + two(m) + ":00" } })
        : isWarn ? []
        : [ { label: isReboot ? "Restart now" : "Power off now", right: "Y" }, { label: "Keep working", right: "N" } ]
    readonly property bool canSwitch: !isWarn && !managing && !standby
    readonly property string confirmLabel: managing ? "RE-ARM" : "CONFIRM"
    readonly property string backLabel: managing ? "KEEP" : "BACK"
    readonly property string endsAt: Qt.formatDateTime(new Date(now.getTime() + countdownSec * 1000), "HH:mm:ss")
    readonly property int listSel: isTimer ? selectedIndex : choice
    readonly property var seqLines: isTimer
        ? ["T-" + two(minutes) + ":00   ARM TIMER", "T-" + two(Math.floor(warningSec / 60)) + ":" + two(warningSec % 60) + "   FINAL WARNING", "T-00:00   POWER OFF"]
        : isWarn ? ["01   CLOSE CLIENTS", "02   SYNC DISKS", "03   POWER OFF"]
        : ["01   CLOSE CLIENTS", "02   STOP SERVICES", isReboot ? "03   RESTART" : "03   POWER OFF"]

    // ===== Đồng hồ cho bảng STATUS =====
    property date now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: ov.active
        triggeredOnStart: true
        onTriggered: ov.now = new Date()
    }
    readonly property string firesAt: Qt.formatDateTime(new Date(now.getTime() + minutes * 60000), "HH:mm")
    readonly property var statusRows: [
        ["ACTION", isReboot ? "Restart" : "Power off"],
        ["DELAY", isTimer ? (minutes + " min") : (isWarn ? countdownText : "Now")],
        [isTimer ? "FIRES AT" : "SESSION", isTimer ? firesAt : userName],
        ["TIME", Qt.formatDateTime(now, "HH:mm:ss")],
        ["DATE", Qt.formatDateTime(now, "dd.MM.yyyy")]
    ]

    // ===== Tiến trình bật máy / tắt máy =====
    property real bp: 0
    property real outP: 0
    readonly property real lineW: Math.min(1, bp / 0.28)
    readonly property real openH: Math.max(0, Math.min(1, (bp - 0.28) / 0.42))
    readonly property real contentP: clamp01((bp - 0.55) / 0.45)
    readonly property real vCollapse: clamp01((outP - 0.34) / 0.40)
    readonly property real hCollapse: clamp01((outP - 0.74) / 0.26)
    // Hiệu ứng CHUYỂN chức năng / đổi vai màn chính <-> màn phụ: rung + loé ngắn, chữ giải mã lại
    property real swP: 1
    NumberAnimation { id: swAnim; target: ov; property: "swP"; from: 0; to: 1; duration: 440; easing.type: Easing.Linear }
    onModeChanged: { if (active && !closing) swAnim.restart() }
    onStandbyChanged: { if (active && !closing) swAnim.restart() }
    readonly property bool textOn: active && !closing && contentP > 0.05 && swP >= 0.25

    onActiveChanged: {
        bootAnim.stop()
        outAnim.stop()
        bp = 0
        outP = 0
        if (active) bootAnim.start()
    }
    onClosingChanged: {
        outAnim.stop()
        outP = 0
        if (closing) outAnim.start()
    }
    NumberAnimation { id: bootAnim; target: ov; property: "bp"; from: 0; to: 1; duration: ov.bootMs; easing.type: Easing.Linear }
    NumberAnimation { id: outAnim; target: ov; property: "outP"; from: 0; to: 1; duration: ov.outroMs; easing.type: Easing.Linear }

    // ===== Glitch =====
    property bool glitchOn: false
    property real gdx: 3
    readonly property bool glitchNow: glitchOn || (closing && outP < 0.34) || swP < 0.35
    readonly property real gdxNow: (closing || swP < 0.35) ? px(12) : gdx
    Timer {
        id: glitchTimer
        interval: 2000
        repeat: true
        running: ov.glitchEnabled && ov.active && ov.contentP >= 1 && !ov.closing
        onTriggered: {
            ov.gdx = (2 + Math.random() * 4) * ov.u
            ov.glitchOn = true
            glitchOff.restart()
            glitchTimer.interval = 1800 + Math.random() * 3200
        }
    }
    Timer { id: glitchOff; interval: 110; repeat: false; onTriggered: ov.glitchOn = false }

    // ===== Hex stream =====
    property string hexStream: "0x5E1F 0C21 9BD4"
    function randHex() {
        let s = "0x"
        for (let g = 0; g < 3; g++) {
            if (g > 0) s += " "
            for (let i = 0; i < 4; i++) s += "0123456789ABCDEF".charAt(Math.floor(Math.random() * 16))
        }
        return s
    }
    Timer { interval: 130; repeat: true; running: ov.active; onTriggered: ov.hexStream = ov.randHex() }

    // ===== Vòng quét (shutdown30 / warning) =====
    property real scanPos: 0
    NumberAnimation on scanPos { from: 0; to: 1; duration: 3000; loops: Animation.Infinite; running: ov.active }
    readonly property real ringFrac: isTimer ? (managing ? countdownFraction : minutes / checkpoints[checkpoints.length - 1]) : countdownFraction
    property real ringFracAnim: ringFrac
    Behavior on ringFracAnim { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    // ===================================================================
    // Khung CRT
    // ===================================================================
    Item {
        id: clipper
        anchors.centerIn: parent
        width: Math.max(0, ov.width * ov.lineW * (1 - ov.hCollapse))
        height: ov.bp <= 0 ? 0 : Math.max(px(3), ov.height * ov.openH * (1 - ov.vCollapse))
        clip: true
        opacity: ov.bp < 0.04 ? 0
               : (ov.bp < 0.4 && Math.floor(ov.bp * 70) % 2 === 1) ? 0.5 : 1

        // Đường sáng của CRT (hiện khi đang là vạch mỏng)
        Rectangle {
            anchors.fill: parent
            color: ov.ink
            visible: clipper.height < px(8)
        }

        Item {
            id: inner
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: jitter
            width: ov.width
            height: ov.height
            readonly property real jitter: (ov.closing && ov.outP < 0.34) || ov.swP < 0.35 ? (Math.random() - 0.5) * px(30) : 0

            // ---------- Nền giấy ----------
            Rectangle { anchors.fill: parent; color: ov.paper }

            // ---------- Khung viền mảnh vát góc dưới phải (Ueda + terminal) ----------
            Shape {
                anchors.fill: parent
                ShapePath {
                    id: frameSP
                    fillColor: "transparent"
                    strokeColor: ov.rule
                    strokeWidth: 1
                    readonly property real f: px(26)
                    readonly property real c: px(64)
                    startX: f; startY: f
                    PathLine { x: inner.width - frameSP.f; y: frameSP.f }
                    PathLine { x: inner.width - frameSP.f; y: inner.height - frameSP.f - frameSP.c }
                    PathLine { x: inner.width - frameSP.f - frameSP.c; y: inner.height - frameSP.f }
                    PathLine { x: frameSP.f; y: inner.height - frameSP.f }
                    PathLine { x: frameSP.f; y: frameSP.f }
                }
            }

            // ---------- Mỗi chế độ một layout + một vật thể riêng ----------
            LayoutShutdown {
                anchors.fill: parent
                ov: ov
                visible: !ov.standby && ov.mode !== "reboot" && ov.mode !== "shutdown30"
            }
            LayoutReboot {
                anchors.fill: parent
                ov: ov
                visible: !ov.standby && ov.mode === "reboot"
            }
            LayoutTimer {
                anchors.fill: parent
                ov: ov
                visible: !ov.standby && ov.mode === "shutdown30"
            }
            LayoutStandby {
                anchors.fill: parent
                ov: ov
                visible: ov.standby
            }

            // ---------- Scanline + thanh quét + flash lúc tắt (không chặn chuột) ----------
            Repeater {
                model: ov.scanlinesEnabled ? Math.ceil(inner.height / Math.max(3, Math.round(3 * ov.u))) : 0
                delegate: Rectangle {
                    required property int index
                    y: index * Math.max(3, Math.round(3 * ov.u))
                    width: inner.width
                    height: 1
                    color: ov.ink
                    opacity: ov.scanOpacity
                    z: 50
                }
            }
            Rectangle {
                id: scanBar
                width: inner.width
                height: px(140)
                z: 49
                visible: ov.contentP > 0
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(ov.ink.r, ov.ink.g, ov.ink.b, 0.0) }
                    GradientStop { position: 0.5; color: Qt.rgba(ov.ink.r, ov.ink.g, ov.ink.b, 0.07) }
                    GradientStop { position: 1.0; color: Qt.rgba(ov.ink.r, ov.ink.g, ov.ink.b, 0.0) }
                }
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: ov.active
                    NumberAnimation { from: -scanBar.height; to: inner.height; duration: 3200; easing.type: Easing.Linear }
                    PauseAnimation { duration: 1000 }
                }
            }
            // Flash trắng ngắn ngay trước khi CRT thu lại
            Rectangle {
                anchors.fill: parent
                z: 60
                color: Qt.lighter(ov.paper, 1.5)
                opacity: ov.closing ? Math.max(0, 0.75 - Math.abs(ov.outP - 0.38) * 5) : Math.max(0, 0.55 - Math.abs(ov.swP - 0.18) * 4.5)
            }
            // Tối dần ở cuối animation tắt
            Rectangle {
                anchors.fill: parent
                z: 61
                color: ov.ink
                opacity: ov.closing ? ov.vCollapse * 0.8 : 0
            }
        }
    }
}
