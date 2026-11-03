import QtQuick
import "lib"

// Layout STANDBY: cho các màn hình PHỤ (không có con trỏ chuột / không nhận phím).
// Trái: log terminal chạy chữ (trình tự của chức năng đang chờ xác nhận ở màn chính) + nhịp "heartbeat"
// chứa số liệu thật. Giữa: chữ Hán + tên chức năng khổng lồ. Phải: thông số máy THẬT
// (uptime, RAM, pin, nhiệt độ, tải) kèm thanh pixel. Di chuột sang màn này là nó thành màn chính.
Item {
    id: lay
    required property var ov
    function px(n) { return ov.px(n) }
    function fs(n) { return ov.fs(n) }

    readonly property real m: px(100)
    readonly property real gap: px(52)
    readonly property real leftW: Math.min(px(640), (width - 2 * m) * 0.37)
    readonly property real rightW: Math.min(px(600), (width - 2 * m) * 0.35)
    readonly property real topY: px(196)
    readonly property real centerX: m + leftW + gap
    readonly property real centerW: width - 2 * m - leftW - rightW - 2 * gap
    readonly property var st: ov.stats

    // ---------- định dạng số liệu ----------
    function two(n) { return (n < 10 ? "0" : "") + n }
    function fmtUp(sec) {
        const s = Math.floor(sec)
        const d = Math.floor(s / 86400)
        const h = Math.floor((s % 86400) / 3600)
        const mi = Math.floor((s % 3600) / 60)
        const se = s % 60
        return (d > 0 ? d + "d " : "") + two(h) + ":" + two(mi) + ":" + two(se)
    }
    readonly property real memTotalG: st.memTotalKb / 1048576
    readonly property real memUsedG: Math.max(0, st.memTotalKb - st.memAvailKb) / 1048576
    readonly property real memFrac: st.memTotalKb > 0 ? memUsedG / memTotalG : 0
    readonly property bool hasBat: st.batPct >= 0
    readonly property bool hasTemp: st.tempC >= 0

    // ---------- log ----------
    ListModel { id: logModel }
    property int seqIdx: 0
    property int beatIdx: 0
    readonly property int maxLines: Math.max(6, Math.floor(px(690) / px(38)))

    function col(a, b) { return (a + "                ").slice(0, 15) + b }
    function startupLines() {
        const base = [col("POWER.CTL", "INIT")]
        if (ov.isWarn) {
            return base.concat([col("MODE", "FINAL COUNTDOWN"), col("SEQ 01", "CLOSE CLIENTS"), col("SEQ 02", "SYNC DISKS"),
                                col("SEQ 03", "POWER OFF"), col("COUNT", ov.countdownText)])
        }
        if (ov.isTimer) {
            const sec = Math.floor(ov.warningSec / 60) + ":" + two(ov.warningSec % 60)
            return base.concat([col("MODE", ov.managing ? "TIMER RUNNING" : "SHUTDOWN TIMER"),
                                col("DELAY", ov.minutes + " MIN"), col("T-" + two(ov.minutes) + ":00", "ARM TIMER"),
                                col("T-0" + sec, "FINAL WARNING"), col("T-00:00", "POWER OFF"),
                                col("WAIT", "CONFIRM ON PRIMARY DISPLAY")])
        }
        return base.concat([col("MODE", ov.isReboot ? "REBOOT" : "SHUTDOWN"),
                            col("SEQ 01", "CLOSE CLIENTS"), col("SEQ 02", "STOP SERVICES"),
                            col("SEQ 03", ov.isReboot ? "RESTART" : "POWER OFF"),
                            col("WAIT", "CONFIRM ON PRIMARY DISPLAY")])
    }
    function pushLine(t) {
        logModel.append({ txt: t })
        while (logModel.count > maxLines) logModel.remove(0)
    }
    function heartbeat() {
        beatIdx += 1
        const k = beatIdx % 3
        if (k === 1) return "SYS    UP " + fmtUp(st.upSec) + "   MEM " + Math.round(memFrac * 100) + "%"
        if (k === 2) return "TMP    " + (hasTemp ? Math.round(st.tempC) + " C" : "N/A") + "   LOAD " + st.load
        return "TICK   0x" + ov.hexStream.slice(2, 6) + "   STANDBY OK"
    }
    function resetLog() {
        logModel.clear()
        seqIdx = 0
        beatIdx = 0
        startupTimer.restart()
    }
    Timer {
        id: startupTimer
        interval: 240
        repeat: true
        onTriggered: {
            const arr = lay.startupLines()
            if (lay.seqIdx < arr.length) lay.pushLine(arr[lay.seqIdx++])
            else startupTimer.stop()
        }
    }
    Timer {
        interval: 1500
        repeat: true
        running: ov.active && lay.visible && !startupTimer.running && !ov.closing
        onTriggered: lay.pushLine(lay.heartbeat())
    }
    Connections {
        target: ov
        function onModeChanged() { if (ov.active) lay.resetLog() }
        function onActiveChanged() { if (ov.active) lay.resetLog() }
        function onClosingChanged() { if (ov.closing) lay.pushLine(lay.col("EXEC", "COMMAND RECEIVED")) }
    }
    Component.onCompleted: if (ov.active) resetLog()

    // ---------- thanh trên ----------
    Item {
        id: top
        x: lay.m; y: px(60)
        width: lay.width - 2 * lay.m; height: px(40)
        opacity: ov.contentP
        Rectangle { width: px(150); height: parent.height; color: ov.ink
            Text { anchors.centerIn: parent; text: "STANDBY"; color: ov.paper
                font.family: ov.fontData; font.pixelSize: fs(18); font.bold: true; font.letterSpacing: 3 } }
        Text {
            x: px(172); anchors.verticalCenter: parent.verticalCenter
            text: "AWAITING INPUT ON PRIMARY DISPLAY"
            color: ov.soft
            font.family: ov.fontData; font.pixelSize: fs(15); font.letterSpacing: 2
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(ov.now, "HH:mm")
            color: ov.ink
            font.family: ov.fontData; font.pixelSize: fs(20); font.bold: true
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: px(92)
            anchors.verticalCenter: parent.verticalCenter
            text: ov.hexStream
            color: ov.soft
            font.family: ov.fontData; font.pixelSize: fs(14); font.letterSpacing: 1
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: ov.rule }
    }

    // ---------- trái: log ----------
    Item {
        x: lay.m; y: lay.topY
        width: lay.leftW; height: lay.height - lay.topY - px(150)
        opacity: ov.contentP
        Text {
            text: "LOG"
            color: ov.ink
            font.family: ov.fontLabel; font.pixelSize: fs(20); font.bold: true; font.letterSpacing: 1.5
        }
        Rectangle { y: px(34); width: parent.width; height: 1; color: ov.ink }
        Column {
            y: px(50)
            width: parent.width
            Repeater {
                model: logModel
                delegate: Item {
                    id: ln
                    required property int index
                    required property string txt
                    width: lay.leftW; height: px(38)
                    ScrambleText {
                        id: lt
                        anchors.verticalCenter: parent.verticalCenter
                        full: ln.txt
                        active: ov.textOn
                        color: ln.index === logModel.count - 1 ? ov.ink : ov.soft
                        font.family: ov.fontData; font.pixelSize: fs(19); font.letterSpacing: 0.5
                        Component.onCompleted: Qt.callLater(function () { if (ov.textOn) lt.scramble() })
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: ov.rule; opacity: 0.45 }
                }
            }
        }
    }

    // ---------- giữa: chữ Hán + tên chức năng ----------
    Item {
        id: mid
        x: lay.centerX; y: lay.topY
        width: lay.centerW; height: lay.height - lay.topY - px(150)
        opacity: ov.contentP
        ScrambleText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: px(10)
            full: ov.kanji.split("").join("\n")
            font.family: ov.fontKanji
            active: ov.textOn
            color: ov.rule
            lineHeight: 0.95
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: fs(200)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - px(150)
            text: ov.isTimer ? (ov.managing ? ov.countdownText : (ov.minutes + " MIN")) : ov.titleText
            color: ov.ink
            font.family: ov.fontLabel; font.pixelSize: fs(46); font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - px(92)
            text: ov.tagText
            color: ov.soft
            font.family: ov.fontLabel; font.pixelSize: fs(16); font.letterSpacing: 2
        }
    }

    // ---------- phải: thông số máy thật ----------
    Item {
        id: sys
        x: lay.width - lay.m - lay.rightW; y: lay.topY
        width: lay.rightW; height: lay.height - lay.topY - px(150)
        opacity: ov.contentP
        function rowDefs() {
            const defs = [
                { label: "UPTIME",  value: lay.fmtUp(lay.st.upSec), bar: -1 },
                { label: "MEMORY",  value: lay.memUsedG.toFixed(1) + " / " + lay.memTotalG.toFixed(1) + " GiB", bar: lay.memFrac },
                { label: "BATTERY", value: lay.hasBat ? (lay.st.batPct + "%  " + lay.st.batStatus.toUpperCase()) : "NO BATTERY", bar: lay.hasBat ? lay.st.batPct / 100 : -1 },
                { label: "TEMP",    value: lay.hasTemp ? (Math.round(lay.st.tempC) + " °C") : "N/A", bar: lay.hasTemp ? Math.min(1, lay.st.tempC / 100) : -1 },
                { label: "LOAD",    value: lay.st.load, bar: -1 }
            ]
            let y = px(50)
            return defs.map(function (d) {
                const h = d.bar >= 0 ? px(112) : px(64)
                const r = { label: d.label, value: d.value, bar: d.bar, y: y, h: h }
                y += h
                return r
            })
        }
        readonly property var rows: rowDefs()
        Text {
            text: "SYSTEM"
            color: ov.ink
            font.family: ov.fontLabel; font.pixelSize: fs(20); font.bold: true; font.letterSpacing: 1.5
        }
        Rectangle { y: px(34); width: parent.width; height: 1; color: ov.ink }

        Repeater {
            model: sys.rows
            delegate: Item {
                required property int index
                required property var modelData
                y: modelData.y
                width: sys.width; height: modelData.h
                Text {
                    text: modelData.label
                    color: ov.soft
                    font.family: ov.fontLabel; font.pixelSize: fs(17); font.letterSpacing: 1.5
                }
                Text {
                    anchors.right: parent.right
                    text: modelData.value
                    color: ov.ink
                    font.family: ov.fontData; font.pixelSize: fs(26); font.bold: true
                }
                PixelBar {
                    visible: modelData.bar >= 0
                    y: px(46)
                    width: parent.width; height: px(12)
                    cells: 32
                    gap: Math.max(1, px(2))
                    value: modelData.bar >= 0 ? modelData.bar : 0
                    onColor: ov.ink
                    offColor: ov.rule
                    headColor: ov.cDanger
                }
                Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: px(modelData.bar >= 0 ? 16 : 10); width: parent.width; height: 1; color: ov.rule; opacity: 0.7 }
            }
        }
    }

    // ---------- chân trang ----------
    Item {
        x: lay.m; y: lay.height - px(100)
        width: lay.width - 2 * lay.m; height: px(34)
        opacity: ov.contentP
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "SESSION  " + ov.userName
            color: ov.ink
            font.family: ov.fontData; font.pixelSize: fs(17); font.bold: true; font.letterSpacing: 1.5
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: px(70)
            anchors.verticalCenter: parent.verticalCenter
            text: "Move the cursor here to take control."
            color: ov.soft
            font.family: ov.fontLabel; font.pixelSize: fs(19)
        }
    }
}
