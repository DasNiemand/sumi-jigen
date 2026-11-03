import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "lib"

ShellRoot {
    id: root

    // ===== Config chung =====
    property real coreCollapsedSize: 22
    property real coreCollapsedMargin: 16

    // ===== Màu lấy từ Noctalia =====
    // Noctalia (template user) xuất palette hiện tại ra file colors.json cạnh shell.qml mỗi khi
    // đổi wallpaper/theme; FileView theo dõi file nên màu đổi theo ngay. Thiếu file -> dùng màu mặc định.
    SumiColors { id: noctaliaColors }
    SumiConfig { id: cfg; appId: "jigen" }
    SumiKeyMap { id: km }

    // ----- Look + timing từ config (mặc định = giá trị gốc) -----
    readonly property string themePreset: cfg.look("theme", "paper")
    readonly property real tint: cfg.lookNum("tint", 0, 0.6, 0.12)
    readonly property real inkDarken: cfg.lookNum("inkDarken", 1, 2.5, 1.5)
    readonly property real scanOpacity: cfg.lookNum("scanlineOpacity", 0, 0.2, 0.05)
    readonly property bool scanlinesEnabled: cfg.lookBool("scanlines", true)
    readonly property bool glitchEnabled: cfg.lookBool("glitch", true)
    readonly property real scaleBoost: cfg.lookNum("scaleBoost", 0.5, 2, 1)
    readonly property int bootMs: cfg.optionNum("crtBootMs", 0, 3000, 900)
    readonly property int outroMs: cfg.optionNum("crtOutroMs", 0, 3000, 460)
    readonly property int revealMs: cfg.optionNum("dither.revealMs", 100, 2000, 480)
    readonly property int ditherPixel: Math.round(cfg.optionNum("dither.pixelSize", 8, 48, 20))
    readonly property real ditherNoise: cfg.optionNum("dither.noise", 0, 1, 0.32)
    readonly property int acceptHoldMs: cfg.optionNum("acceptHoldMs", 500, 6000, 2500)
    readonly property int inputGuardMs: cfg.optionNum("acceptKeysDelayMs", 0, 1000, 180)

    // ----- Phím chính cấu hình được (phím phụ: mũi tên, Tab, Space, Enter, 1/2/3 cố định) -----
    readonly property string keyYes: cfg.keyFor("yes", "Y")
    readonly property string keyNo: cfg.keyFor("no", "N")
    readonly property string keyLeft: cfg.keyFor("nav.left", "A")
    readonly property string keyRight: cfg.keyFor("nav.right", "D")
    readonly property string keyUp: cfg.keyFor("nav.up", "W")
    readonly property string keyDown: cfg.keyFor("nav.down", "S")
    readonly property string keyPrev: cfg.keyFor("fn.prev", "Q")
    readonly property string keyNext: cfg.keyFor("fn.next", "E")
    readonly property string keyConfirm: cfg.keyFor("confirm", "Return")

    property string bgColor: noctaliaColors.adapter.surface
    property string fgColor: noctaliaColors.adapter.on_surface
    property string mutedColor: noctaliaColors.adapter.outline
    property string accentColor: noctaliaColors.adapter.primary
    property string liquidColor: "#ffffff"   // màu chất lỏng của vòng progress đếm giờ
    property string borderColor: noctaliaColors.adapter.outline
    property string buttonBorderColor: noctaliaColors.adapter.on_surface

    // ===================================================================
    // ===== Theo dõi màn hình đang có con trỏ chuột (liên tục, poll) =====
    // ===================================================================
    property real cursorGlobalX: NaN
    property real cursorGlobalY: NaN
    property string cursorScreenName: ""
    property string originScreenName: ""   // fallback dùng lúc mới bấm nút, trước khi có cursorScreenName

    function refreshCursorScreen() {
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i]
            if (root.cursorGlobalX >= s.x && root.cursorGlobalX < s.x + s.width &&
                root.cursorGlobalY >= s.y && root.cursorGlobalY < s.y + s.height) {
                root.cursorScreenName = s.name
                return
            }
        }
    }

    Process {
        id: cursorPosProc
        // Bỏ "-j": trên 1 số bản Hyprland, "hyprctl cursorpos -j" không in JSON hợp lệ.
        // Định dạng thường ("x, y") thì luôn ổn định nên parse tay cho chắc.
        command: ["hyprctl", "cursorpos"]
        stdout: SplitParser {
            onRead: (line) => {
                const parts = line.trim().split(",")
                if (parts.length === 2) {
                    const x = parseFloat(parts[0])
                    const y = parseFloat(parts[1])
                    if (!isNaN(x) && !isNaN(y)) {
                        root.cursorGlobalX = x
                        root.cursorGlobalY = y
                        root.refreshCursorScreen()
                    }
                }
            }
        }
    }

    // Poll định kỳ ~400ms để biết widget nên hiện ở màn hình nào.
    Timer {
        interval: 400
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!cursorPosProc.running) cursorPosProc.running = true
        }
    }

    // ===================================================================
    // ===== State dùng CHUNG cho mọi màn hình (dither chạy đồng loạt) =====
    // ===================================================================
    property string confirmAction: ""            // "" | "shutdown" | "reboot" | "shutdown30"
    property bool confirmWasAccepted: false
    // true khi overlay timer được MỞ LẠI (bấm thẻ ở góc) lúc timer đang chạy: có thể huỷ / đổi giờ / giữ nguyên.
    property bool confirmManaging: false
    property string confirmAcceptedAction: ""    // action nào vừa được Accept, để overlay biết hold hay revert
    property bool delayedShutdownActive: false   // đang đếm 30 phút (màn hình đã tắt)
    property bool delayedShutdownWarning: false  // đang trong khoảng cảnh báo cuối trước khi tắt máy thật
    property real countdownRemainingFraction: 1.0
    // Set true ngay khi huỷ 1 confirm screen (No/Esc) hoặc huỷ đếm giờ - giữ dot ẨN
    // luôn cho tới khi tiến trình thật sự Qt.quit(), không cho nó loé lên 1 nhịp
    // trong lúc dither đang rút/đóng lại. Không cần reset về false vì sau đó widget
    // thoát hẳn.
    property bool suppressDotUntilQuit: false

    // Lựa chọn đang được highlight ở màn confirm shutdown/reboot: 0 = Yes, 1 = No.
    // A/D/←/→/Tab đổi lựa chọn, Space/Enter xác nhận lựa chọn đang highlight.
    property int confirmChoice: 0
    // Font theo vai trò (title/label/data/numeral/kanji): đặt trong ~/.config/sumi/config.json.
    readonly property string fontTitle: cfg.font("title", "sans-serif")
    readonly property string fontLabel: cfg.font("label", "sans-serif")
    readonly property string fontData: cfg.font("data", "monospace")
    readonly property string fontNumeral: cfg.font("numeral", "monospace")
    readonly property string fontKanji: cfg.font("kanji", Qt.application.font.family)
    property string userName: Quickshell.env("USER") || ""

    // Animation OUT: bấm Yes/No/Esc không thực thi ngay mà cho overlay chạy hiệu ứng tắt
    // (glitch -> flash -> CRT thu lại) ~480ms rồi mới thực thi hành động thật.
    property bool confirmClosing: false
    property string pendingResolve: ""      // "yes" | "no" | "abort" | "keep"
    function resolveConfirm(kind) {
        if (confirmClosing) return
        confirmClosing = true
        pendingResolve = kind
        resolveTimer.restart()
    }
    Timer {
        id: resolveTimer
        interval: Math.max(480, root.outroMs + 20)
        running: false
        repeat: false
        onTriggered: {
            const k = root.pendingResolve
            // Thực thi TRƯỚC rồi mới tắt cờ closing, để overlay không kịp "bung lại" 1 khung hình.
            if (k === "yes") root.executeConfirmed()
            else if (k === "no") root.cancelConfirm()
            else if (k === "abort") root.cancelDelayedShutdown()
            else if (k === "keep") root.closeManage()
            root.confirmClosing = false
        }
    }

    // ===== Số liệu hệ thống THẬT cho màn hình phụ (uptime, RAM, pin, nhiệt độ, tải) =====
    property var sysStats: ({ upSec: 0, memTotalKb: 0, memAvailKb: 0, batPct: -1, batStatus: "", tempC: -1, load: "0.00" })
    function parseStatLine(line) {
        const i = line.indexOf("=")
        if (i < 0) return
        const key = line.slice(0, i), val = line.slice(i + 1).trim()
        const st = Object.assign({}, sysStats)
        if (key === "up") st.upSec = parseFloat(val) || 0
        else if (key === "memt") st.memTotalKb = parseInt(val) || 0
        else if (key === "mema") st.memAvailKb = parseInt(val) || 0
        else if (key === "bat") st.batPct = val === "" ? -1 : (parseInt(val) || 0)
        else if (key === "bats") st.batStatus = val
        else if (key === "temp") { const t = parseFloat(val); st.tempC = isNaN(t) ? -1 : (t > 1000 ? t / 1000 : t) }
        else if (key === "load") st.load = val
        else return
        sysStats = st
    }
    Process {
        id: statsProc
        command: ["sh", "-c",
            "echo up=$(cut -d' ' -f1 /proc/uptime); " +
            "echo memt=$(grep -m1 MemTotal /proc/meminfo | tr -s ' ' | cut -d' ' -f2); " +
            "echo mema=$(grep -m1 MemAvailable /proc/meminfo | tr -s ' ' | cut -d' ' -f2); " +
            "echo bat=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1); " +
            "echo bats=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1); " +
            "echo temp=$(cat /sys/class/hwmon/hwmon*/temp1_input /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -rn | head -n1); " +
            "echo load=$(cut -d' ' -f1 /proc/loadavg)"]
        stdout: SplitParser { onRead: (line) => root.parseStatLine(line) }
    }
    Timer {
        interval: 2000
        repeat: true
        running: root.overlayActive
        triggeredOnStart: true
        onTriggered: if (!statsProc.running) statsProc.running = true
    }

    // Độ dài cảnh báo cuối (giây) cho LẦN HẸN KẾ TIẾP. Timer đang chạy dùng activeWarningSec (chốt lúc bấm Yes).
    readonly property int warningDurationSec: Math.round(cfg.optionNum("timer.warningSec", 30, 300, 90))
    property int activeWarningSec: 90
    property int warningRemainingSec: 0

    // Ngưỡng "sắp hết giờ" (giây) - trước khi vào hẳn màn hình cảnh báo toàn màn hình
    // (delayedShutdownWarning), đổi màu dot + fluid sang đỏ để cảnh báo sớm.
    readonly property int nearEndWarningSec: Math.round(cfg.optionNum("timer.nearEndSec", 30, 600, 120))

    // ----- Chọn thời lượng đếm giờ cho shutdown30 (orbit ở màn confirm) -----
    // Danh sách thời lượng từ config: chỉ nhận số nguyên 1..240, bỏ trùng, sắp tăng dần, tối đa 8 mục; sai thì dùng [5,15,30,60].
    readonly property var durationCheckpointsMin: {
        const raw = cfg.option("timer.presets", [5, 15, 30, 60])
        let out = []
        if (Array.isArray(raw)) {
            for (let i = 0; i < raw.length; i++) {
                const v = raw[i]
                if (typeof v === "number" && isFinite(v) && Math.floor(v) === v && v >= 1 && v <= 240 && out.indexOf(v) < 0) out.push(v)
            }
        }
        out.sort(function (x, y) { return x - y })
        out = out.slice(0, 8)
        return out.length > 0 ? out : [5, 15, 30, 60]
    }
    // Mặc định = timer.defaultMinutes nếu nằm trong danh sách, không thì mục gần nhất không vượt quá nó (hoặc mục đầu).
    readonly property int defaultDurationIndex: {
        const want = cfg.option("timer.defaultMinutes", 30)
        const l = durationCheckpointsMin
        let best = 0
        for (let i = 0; i < l.length; i++) if (l[i] <= want) best = i
        return best
    }
    property int selectedDurationIndex: defaultDurationIndex
    // true ngay khi người dùng CHỦ ĐỘNG chỉnh orbit (kéo chuột hoặc A/D) - trước đó
    // (đã bỏ orbit) selectedDurationIndex luôn giữ
    // nguyên mặc định, chưa coi là 1 lựa chọn thật.
    property bool durationManuallyAdjusted: false
    // Chỉ số an toàn: danh sách có thể đổi lúc đang chạy (reload config).
    readonly property int safeDurationIndex: Math.max(0, Math.min(selectedDurationIndex, durationCheckpointsMin.length - 1))
    readonly property int selectedDurationMin: durationCheckpointsMin[safeDurationIndex]
    // Thời lượng THẬT đang chạy đếm - chốt lại đúng lúc bấm Yes (executeConfirmed),
    // không đổi theo selectedDurationIndex nữa dù orbit còn đang mở ở lần confirm sau.
    property int activeDurationMin: 30

    property real countdownRemainingSec: countdownRemainingFraction * root.activeDurationMin * 60
    readonly property bool nearEndActive: delayedShutdownActive && !delayedShutdownWarning
        && countdownRemainingSec <= nearEndWarningSec
    property string dangerColor: "#E63946"

    function formatMMSS(totalSeconds) {
        const t = Math.max(0, totalSeconds)
        const m = Math.floor(t / 60)
        const s = t % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    readonly property bool overlayActive: confirmAction !== "" || delayedShutdownWarning
    // Tăng mỗi lần requestConfirm() được gọi, kể cả khi gọi lại action khác trong lúc dialog
    // cũ CHƯA đóng - vì lúc đó "confirmAction !== \"\"" vẫn là true như trước (không đổi giá
    // trị boolean), nên riêng dựa vào activeShow sẽ KHÔNG phát hiện được đây là 1 yêu cầu mới.
    property int confirmRequestToken: 0

    function requestConfirm(action, screenName) {
        // Chỉ tăng token khi ĐANG có dialog khác mở sẵn (đúng edge-case cần bắt: gọi
        // requestConfirm mới trong lúc dialog trước chưa đóng). Mở bình thường (chưa có
        // gì mở) thì KHÔNG đụng token - nếu không, Connections lắng nghe token sẽ gọi
        // openFresh() thêm 1 lần nữa ngay sau lần đầu, gây giật/nhìn như bị rút ngắn.
        const wasAlreadyOpen = confirmAction !== ""
        originScreenName = screenName || ""
        resolveTimer.stop()
        confirmClosing = false
        confirmWasAccepted = false
        confirmManaging = false
        confirmChoice = 0
        confirmAction = action
        // Mỗi lần mở LẠI confirm shutdown30 -> reset orbit về mặc định (30 phút) và cho
        // orbit tự xoay lại từ đầu, không giữ lựa chọn/trạng thái của lần trước.
        if (action === "shutdown30") {
            selectedDurationIndex = defaultDurationIndex
            durationManuallyAdjusted = false
        }
        if (wasAlreadyOpen) confirmRequestToken += 1
    }
    // Nhảy sang checkpoint thời lượng liền kề (có wrap 60 -> 5 và ngược lại).
    function stepDuration(delta) {
        const n = durationCheckpointsMin.length
        durationManuallyAdjusted = true
        selectedDurationIndex = ((selectedDurationIndex + delta) % n + n) % n
    }
    // ----- Chuyển chức năng ngay trong overlay (Q/E, Tab, 1/2/3, bấm tab) -----
    readonly property var confirmOrder: ["shutdown", "reboot", "shutdown30"]
    function switchConfirm(action) {
        if (confirmClosing || confirmManaging || confirmAction === "" || action === confirmAction) return
        if (confirmOrder.indexOf(action) < 0) return
        confirmChoice = 0
        confirmAction = action
    }
    function cycleConfirm(delta) {
        const i = confirmOrder.indexOf(confirmAction)
        if (i < 0) return
        switchConfirm(confirmOrder[(i + delta + confirmOrder.length) % confirmOrder.length])
    }
    // ----- Mở lại overlay đầy đủ khi timer đang chạy (bấm thẻ ở góc) -----
    function requestManage(screenName) {
        if (!delayedShutdownActive || delayedShutdownWarning || confirmAction !== "") return
        originScreenName = screenName || cursorScreenName
        resolveTimer.stop()
        confirmClosing = false
        confirmWasAccepted = false
        confirmChoice = 0
        const idx = durationCheckpointsMin.indexOf(activeDurationMin)
        selectedDurationIndex = idx >= 0 ? idx : defaultDurationIndex
        confirmManaging = true
        confirmAction = "shutdown30"
    }
    // Esc trong chế độ quản lý timer: đóng overlay, timer vẫn chạy tiếp, KHÔNG thoát widget.
    function closeManage() {
        confirmManaging = false
        confirmWasAccepted = false
        confirmAction = ""
    }
    function cancelConfirm() {
        confirmWasAccepted = false
        confirmAction = ""
        // Huỷ (No/Esc) màn hình confirm ban đầu (shutdown/reboot/shutdown30) -> thoát
        // hẳn tiến trình widget, KHÔNG giữ nền, và KHÔNG cho dot hiện lại trước khi
        // thoát. Chỉ khi bấm Yes ở confirm shutdown30 (xem executeConfirmed) mới
        // không quit, vì phải sống tiếp để đếm 30 phút.
        suppressDotUntilQuit = true
        quitAfterCancelTimer.restart()
    }
    // Đợi animation dither "rút" xong (closeTimer dùng pixelGrid.revealDuration = 480ms)
    // rồi mới Qt.quit(), để không cắt ngang animation đóng lại. Có kiểm tra confirmAction
    // lúc bắn ra phòng trường hợp 1 yêu cầu confirm MỚI đã kịp mở lại trong lúc chờ.
    Timer {
        id: quitAfterCancelTimer
        interval: root.revealMs + 40
        running: false
        repeat: false
        onTriggered: if (root.confirmAction === "") Qt.quit()
    }
    function executeConfirmed() {
        confirmWasAccepted = true
        confirmAcceptedAction = confirmAction
        if (confirmAction === "shutdown") {
            shutdownProc.running = true
            quitAfterHoldTimer.restart()
        } else if (confirmAction === "reboot") {
            rebootProc.running = true
            quitAfterHoldTimer.restart()
        } else if (confirmAction === "shutdown30") {
            activeDurationMin = selectedDurationMin
            startDelayedShutdown()
            // KHÔNG quit - phải sống tới khi đếm hết giờ mới thật sự tắt máy.
        }
        confirmManaging = false
        confirmAction = ""
    }
    // Chỉ dùng cho shutdown/reboot: đợi đúng bằng acceptHoldMs (thời gian giữ dither phủ
    // kín trước khi đóng) rồi mới tự thoát tiến trình - để không cần chạy `qs -c clockwidget`
    // nền thường trực, mỗi lần gọi lệnh sẽ tự khởi động rồi tự dọn dẹp sau khi xong việc.
    Timer {
        id: quitAfterHoldTimer
        interval: root.acceptHoldMs
        running: false
        repeat: false
        onTriggered: Qt.quit()
    }
    function startDelayedShutdown() {
        activeWarningSec = warningDurationSec
        delayedShutdownActive = true
        delayedShutdownWarning = false
        countdownRemainingFraction = 1.0
        countdownAnim.restart()
        delayedMainTimer.restart()
        // Đợi animation dither đóng lại chạy xong hẳn (480ms) rồi mới tắt màn hình -
        // trước đây tắt màn hình ngay lập tức làm dpms cắt ngang animation, nhìn như
        // bị rút ngắn/nhanh hơn lúc mở ra.
        dpmsOffDelayTimer.restart()
    }
    Timer {
        id: dpmsOffDelayTimer
        interval: root.revealMs + 40
        running: false
        repeat: false
        onTriggered: dpmsOffProc.running = true
    }
    function cancelDelayedShutdown() {
        confirmWasAccepted = false
        confirmManaging = false
        // Hủy từ chế độ QUẢN LÝ (mở lại bằng thẻ ở góc) thì confirmAction vẫn là "shutdown30": phải xóa, nếu không
        // overlay không đóng (overlayActive vẫn true) và tiến trình không tự thoát -> hiện lại màn xác nhận lần nữa.
        confirmAction = ""
        delayedShutdownActive = false
        delayedShutdownWarning = false
        delayedMainTimer.stop()
        delayedWarnTimer.stop()
        warningTickTimer.stop()
        dpmsOffDelayTimer.stop()
        warningRemainingSec = 0
        countdownAnim.stop()
        countdownRemainingFraction = 1.0
        dpmsOnProc.running = true
        // Huỷ đếm giờ (dù đang đếm bình thường hay đang ở màn cảnh báo cuối trước khi
        // tắt máy thật) -> thoát hẳn tiến trình luôn, không giữ nền, không cho dot
        // hiện lại trước khi thoát (giống cancelConfirm ở trên).
        suppressDotUntilQuit = true
        quitAfterCancelTimer.restart()
    }

    Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: dpmsOffProc; command: ["hyprctl", "dispatch", "dpms", "off"] }
    Process { id: dpmsOnProc; command: ["hyprctl", "dispatch", "dpms", "on"] }

    // Thanh progress "fluid" - 1 animation liên tục chạy suốt 30 phút, không cập nhật
    // theo từng giây rời rạc, nên chuyển động luôn mượt.
    NumberAnimation {
        id: countdownAnim
        target: root
        property: "countdownRemainingFraction"
        from: 1.0
        to: 0.0
        duration: root.activeDurationMin * 60 * 1000
        easing.type: Easing.Linear
    }

    // Đếm (activeDurationMin phút - warningDurationSec) rồi bật màn hình + cảnh báo
    // dither có đếm ngược sống động (mặc định 90s = 1.5 phút), hết thời gian đó mới
    // tắt máy thật.
    Timer {
        id: delayedMainTimer
        interval: root.activeDurationMin * 60 * 1000 - root.activeWarningSec * 1000
        running: false
        repeat: false
        onTriggered: {
            root.delayedShutdownWarning = true
            dpmsOnProc.running = true
            root.warningRemainingSec = root.activeWarningSec
            warningTickTimer.restart()
            delayedWarnTimer.restart()
        }
    }
    Timer {
        id: warningTickTimer
        interval: 1000
        running: false
        repeat: true
        onTriggered: {
            if (root.warningRemainingSec > 0) root.warningRemainingSec -= 1
        }
    }
    Timer {
        id: delayedWarnTimer
        interval: root.activeWarningSec * 1000
        running: false
        repeat: false
        onTriggered: {
            root.delayedShutdownActive = false
            warningTickTimer.stop()
            shutdownProc.running = true
            // Không tắt delayedShutdownWarning ở đây - giữ dither phủ kín tới khi máy tắt hẳn.
        }
    }

    // ===================================================================
    // ===== Kích hoạt qua IPC (gắn vào keybind Hyprland hoặc 1 nút bấm khác,
    // vd nút power-menu của Noctalia). Mỗi lệnh bắn THẲNG confirm screen của
    // action tương ứng (dither + Yes/No) - không còn tam giác 3 nút / dot mở
    // rộng nữa, mỗi nút hoàn toàn độc lập, mỗi nút = 1 shell command riêng.
    // Với shutdown30: màn confirm có thêm orbit chọn thời lượng (5/15/30/60 phút),
    // Yes xong sẽ hiện dot dạng vòng progress đếm ngược đúng thời lượng đã chọn.
    // Thử bằng: `qs ipc call clock-widget shutdown` (hoặc reboot / shutdown30).
    // Đổi tên IpcHandler/import nếu bản Quickshell của bạn khác API. =====
    // ===================================================================

    // Tên IPC mới (sumi-jigen) và tên cũ (clock-widget, giữ để bind Hyprland / nút Noctalia cũ chạy tiếp).
    // reload(): đọc lại config ngay; KHÔNG đụng timer đang chạy.
    IpcHandler {
        target: "sumi-jigen"
        function shutdown(): void { root.requestConfirm("shutdown", root.cursorScreenName) }
        function reboot(): void { root.requestConfirm("reboot", root.cursorScreenName) }
        function shutdown30(): void { root.requestConfirm("shutdown30", root.cursorScreenName) }
        function reload(): void { cfg.reload(); cfg.refresh() }
    }
    IpcHandler {
        target: "clock-widget"
        function shutdown(): void { root.requestConfirm("shutdown", root.cursorScreenName) }
        function reboot(): void { root.requestConfirm("reboot", root.cursorScreenName) }
        function shutdown30(): void { root.requestConfirm("shutdown30", root.cursorScreenName) }
    }

    // ----- 1 PanelWindow / màn hình -----
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData

            readonly property bool isCursorScreen: root.cursorScreenName !== ""
                ? (modelData.name === root.cursorScreenName)
                : (Quickshell.screens.length > 0 && modelData.name === Quickshell.screens[0].name)

            // Widget CHỈ hiện ở màn hình đang có cursor - màn hình khác ẩn hoàn toàn,
            // không chiếm input, không có icon gì cả.
            visible: isCursorScreen

            // ----- Toạ độ (toàn bộ tính theo hệ toạ độ của panel, tức toàn màn hình) -----
            readonly property real centerX: width / 2
            readonly property real centerY: height / 2

            // Thẻ đếm giờ (CornerCard) nằm ở góc PHẢI trên cùng, chỉ hiện khi đang đếm giờ.
            readonly property real cardU: Math.max(0.85, Math.min(width / 1920, height / 1080)) * root.scaleBoost
            readonly property real cardW: Math.round(196 * cardU)
            readonly property real cardH: Math.round(72 * cardU)
            readonly property real cardX: width - root.coreCollapsedMargin - cardW
            readonly property real cardY: root.coreCollapsedMargin

            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: -1
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "clock-widget"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            mask: Region { item: hitArea }

            Item {
                id: hitArea
                x: panel.cardX
                y: panel.cardY
                width: root.delayedShutdownActive ? panel.cardW : 0
                height: root.delayedShutdownActive ? panel.cardH : 0
            }

            Item {
                id: hostArea
                anchors.fill: parent
                // Ẩn thẻ trong lúc overlay (dither) đang hiện, hoặc sau khi vừa huỷ và đang chờ tự thoát.
                opacity: (root.overlayActive || root.suppressDotUntilQuit) ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }

                CornerCard {
                    id: timerCard
                    visible: root.delayedShutdownActive
                    x: panel.cardX
                    y: panel.cardY
                    scaleU: panel.cardU
                    bgColor: root.bgColor
                    fgColor: root.fgColor
                    accentColor: root.accentColor
                    preset: root.themePreset
                    tint: root.tint
                    inkDarken: root.inkDarken
                    dangerColor: root.dangerColor
                    fontData: root.fontData
                    fontNumeral: root.fontNumeral
                    remainingText: root.formatMMSS(Math.round(root.countdownRemainingSec))
                    fraction: root.countdownRemainingFraction
                    nearEnd: root.nearEndActive
                    onClicked: root.requestManage(panel.modelData.name)
                }
            } // hostArea

            // ===== Overlay xác nhận / cảnh báo - phủ kín TOÀN BỘ các màn hình cùng lúc,
            // đè lên mọi app khác. "activeShow" đọc state chung ở root nên mọi confirmOverlay
            // (1 cái / màn hình, sinh bởi Variants) chạy dither cùng lúc. Chỉ màn hình đang có
            // con trỏ chuột mới hiện Yes/No + nhận bàn phím; các màn hình khác chỉ có dither. =====
            PanelWindow {
                id: confirmOverlay
                screen: panel.modelData
                readonly property bool activeShow: root.overlayActive
                property bool windowOpen: false
                visible: windowOpen
                property string displayAction: ""
                // Lúc đang kéo chuột trên orbit -> hiện LIVE số phút của checkpoint gần nhất
                // theo vị trí đang kéo (chưa commit vào selectedDurationIndex, chỉ preview),
                // để biết ngay đang kéo tới đâu thay vì phải thả ra mới biết.
                readonly property int liveDurationIndex: root.safeDurationIndex
                readonly property string displayLabel: displayAction === "shutdown" ? "Shutdown?"
                                                        : displayAction === "reboot" ? "Restart?"
                                                        : displayAction === "shutdown30" ? ("Shutdown in " + root.durationCheckpointsMin[liveDurationIndex] + " minutes?")
                                                        : displayAction === "warning" ? "Shutting down soon"
                                                        : ""

                readonly property bool isCursorScreen: root.cursorScreenName !== ""
                    ? (panel.modelData.name === root.cursorScreenName)
                    : (panel.modelData.name === root.originScreenName)

                anchors { top: true; bottom: true; left: true; right: true }
                exclusiveZone: -1
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "clock-widget-confirm"
                WlrLayershell.keyboardFocus: isCursorScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                property bool revealDone: false
                property bool acceptedHold: false
                property int acceptHoldMs: root.acceptHoldMs

                // Cho phép nhận phím NGAY sau ~180ms kể từ lúc dialog mở (không đợi dither
                // phủ xong 480ms như trước, vì lúc khởi động nguội widget hay trễ nên người
                // dùng bấm Enter sớm hơn lúc UI kịp hiện -> bị bỏ qua, nhìn như "đôi lúc
                // không nhận phím"). 180ms đầu vẫn chặn để không ăn nhầm phím vừa bấm ra dialog.
                property bool inputReady: false
                Timer {
                    id: inputGuardTimer
                    interval: root.inputGuardMs
                    running: false
                    repeat: false
                    onTriggered: confirmOverlay.inputReady = true
                }
                // Nếu cửa sổ chưa nhận được focus bàn phím (do compositor/panel khác đang giữ
                // focus lúc đóng dần), liên tục đòi lại focus cho tới khi nhận được.
                Timer {
                    interval: 150
                    repeat: true
                    running: confirmOverlay.windowOpen && confirmOverlay.isCursorScreen && !keyItem.activeFocus
                    onTriggered: keyItem.forceActiveFocus()
                }

                // Dùng chung cho 2 trường hợp cần "mở sạch": (1) activeShow vừa đổi
                // false->true bình thường, (2) có yêu cầu confirm MỚI trong lúc dialog
                // cũ đang mở (activeShow không đổi giá trị nên onActiveShowChanged phía
                // dưới không tự chạy - phải gọi tay qua Connections bên dưới).
                function openFresh() {
                    closeTimer.stop()
                    acceptCloseTimer.stop()
                    windowOpen = true
                    revealDone = false
                    acceptedHold = false
                    inputReady = false
                    inputGuardTimer.restart()
                    displayAction = root.confirmAction !== "" ? root.confirmAction : "warning"
                    revealTimer.restart()
                }

                onActiveShowChanged: {
                    if (!activeShow) inputReady = false
                    if (activeShow) {
                        openFresh()
                    } else if (root.confirmWasAccepted && root.confirmAcceptedAction !== "shutdown30") {
                        // Shutdown/Reboot: giữ phủ kín (hold) rồi mới đóng, che luôn lúc máy
                        // thật sự tắt/khởi động lại.
                        acceptedHold = true
                        acceptCloseTimer.restart()
                    } else {
                        // Shutdown-30-phút (và Cancel/No): CHẠY NGƯỢC lại animation lúc hiện ra
                        // (dither rút dần), vì việc tắt máy còn ở tương lai xa, không cần giữ màn
                        // hình tối ngay lúc này.
                        closeTimer.restart()
                    }
                }
                // Bắt trường hợp: gọi requestConfirm() (vd qua IPC) lúc dialog TRƯỚC ĐÓ vẫn
                // đang mở, chưa được Yes/No/Esc. Lúc này confirmAction đổi giá trị (vd
                // "shutdown" -> "reboot") nhưng "activeShow" (confirmAction !== "") vẫn là
                // true như cũ -> onActiveShowChanged ở trên KHÔNG chạy lại -> animation "in"
                // bị bỏ qua. confirmRequestToken chỉ tăng đúng lúc này (xem requestConfirm),
                // nên Connections dưới đây chỉ fire cho đúng edge-case, không fire trùng lặp
                // ở lần mở bình thường.
                // Chuyển chức năng ngay trong overlay đang mở (Q/E, Tab, 1/2/3, bấm tab): cập nhật
                // displayAction mà KHÔNG chạy lại animation dither.
                Connections {
                    target: root
                    function onConfirmActionChanged() {
                        if (root.confirmAction !== "" && confirmOverlay.windowOpen)
                            confirmOverlay.displayAction = root.confirmAction
                    }
                }
                Connections {
                    target: root
                    function onConfirmRequestTokenChanged() {
                        if (confirmOverlay.activeShow) confirmOverlay.openFresh()
                    }
                }
                Timer {
                    id: closeTimer
                    interval: pixelGrid.revealDuration
                    running: false
                    onTriggered: confirmOverlay.windowOpen = false
                }
                Timer {
                    id: acceptCloseTimer
                    interval: confirmOverlay.acceptHoldMs
                    running: false
                    onTriggered: {
                        confirmOverlay.windowOpen = false
                        confirmOverlay.acceptedHold = false
                    }
                }
                // QUAN TRỌNG: không dùng "running: confirmOverlay.activeShow" ở đây. Vì đây là
                // timer chạy 1 lần (repeat mặc định false), sau khi bắn xong nó tự set
                // running=false - và việc TỰ SET này sẽ PHÁ LUÔN binding "running" (gotcha kinh
                // điển của QML: gán giá trị vào property đang có binding sẽ xoá binding đó).
                // Hậu quả nếu dùng binding: từ lần mở thứ 2 trở đi, timer này không bao giờ tự
                // chạy lại -> revealDone không bao giờ true nữa -> Yes/No không hiện lại được.
                // Nên phải gọi .restart() TƯỜNG MINH mỗi lần mở (đã làm ở nhánh "if (activeShow)"
                // bên trên) thay vì bind "running".
                Timer {
                    id: revealTimer
                    interval: pixelGrid.revealDuration
                    running: false
                    repeat: false
                    onTriggered: confirmOverlay.revealDone = true
                }

                // ----- Phím (nhận sau inputGuardTimer 180ms, không cần đợi dither phủ xong) -----
                //  Esc: huỷ (No / huỷ đếm giờ)        Y / N: Yes / No trực tiếp
                //  Shutdown & Reboot: A/D/←/→/Tab đổi highlight Yes<->No, Space/Enter xác nhận
                //  Shutdown-after-time: A/D/←/→ (và W/S/↑/↓) đổi thời lượng, Space/Enter = Yes
                // WlrKeyboardFocus chỉ Exclusive trên màn hình có cursor, màn hình khác không nhận phím.
                Item {
                    id: keyItem
                    anchors.fill: parent
                    focus: true
                    onActiveFocusChanged: console.log("[confirm] keyboard focus on", panel.modelData.name, "=", activeFocus)
                    Keys.onPressed: (event) => {
                        if (!confirmOverlay.inputReady || root.confirmClosing) return
                        const k = event.key
                        const ar = event.isAutoRepeat
                        const isLeft  = (km.match(event, root.keyLeft) || k === Qt.Key_Left)
                        const isRight = (km.match(event, root.keyRight) || k === Qt.Key_Right)
                        const isUp    = (km.match(event, root.keyUp) || k === Qt.Key_Up)
                        const isDown  = (km.match(event, root.keyDown) || k === Qt.Key_Down)
                        const isAct   = (km.match(event, root.keyConfirm) || k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)

                        if (k === Qt.Key_Escape) {
                            if (root.confirmManaging) root.resolveConfirm("keep")
                            else if (root.confirmAction !== "") root.resolveConfirm("no")
                            else if (root.delayedShutdownWarning) root.resolveConfirm("abort")
                            event.accepted = true
                        } else if (root.confirmAction !== "") {
                            // Phím giữ lì (auto-repeat) không được phép xác nhận/huỷ/chuyển.
                            if (km.match(event, root.keyPrev) || k === Qt.Key_Backtab) { if (!ar) root.cycleConfirm(-1) }
                            else if (km.match(event, root.keyNext) || k === Qt.Key_Tab) { if (!ar) root.cycleConfirm(1) }
                            else if (k >= Qt.Key_1 && k <= Qt.Key_3) { if (!ar) root.switchConfirm(root.confirmOrder[k - Qt.Key_1]) }
                            else if (km.match(event, root.keyYes)) { if (!ar) root.resolveConfirm("yes") }
                            else if (km.match(event, root.keyNo)) { if (!ar) root.resolveConfirm(root.confirmManaging ? "abort" : "no") }
                            else if (root.confirmAction === "shutdown30") {
                                if (isLeft || isUp) root.stepDuration(-1)
                                else if (isRight || isDown) root.stepDuration(1)
                                else if (isAct) { if (!ar) root.resolveConfirm("yes") }
                                else return
                            } else {
                                if (isLeft || isRight) root.confirmChoice = 1 - root.confirmChoice
                                else if (isAct) {
                                    if (!ar) root.resolveConfirm(root.confirmChoice === 0 ? "yes" : "no")
                                }
                                else return
                            }
                            event.accepted = true
                        }
                    }

                    // ---- Lưới pixel "dithering" - chạy giống hệt nhau trên MỌI màn hình vì
                    // dùng chung confirmOverlay.activeShow (bind từ root.overlayActive).
                    Item {
                        id: pixelGrid
                        anchors.fill: parent

                        property int pixelSize: root.ditherPixel
                        // Dùng kích thước MÀN HÌNH THẬT (biết ngay từ lúc khởi động qua
                        // panel.modelData) thay vì confirmOverlay.width/height - vì cửa sổ
                        // overlay ẩn (visible:false) từ đầu nên kích thước của NÓ là 0 cho tới
                        // đúng lúc mở lần đầu, khiến hàng nghìn ô Rectangle bị tạo dồn cục ngay
                        // trong lúc chạy animation mở đầu tiên -> giật/chậm hẳn lần đầu, làm các
                        // lần sau (đã có sẵn ô) trông như nhanh hơn hẳn so với lần đầu.
                        property int cols: Math.max(1, Math.ceil(panel.modelData.width / pixelSize))
                        property int rows: Math.max(1, Math.ceil(panel.modelData.height / pixelSize))
                        property real noiseAmount: root.ditherNoise
                        property int revealDuration: root.revealMs

                        property real progress: (confirmOverlay.activeShow || confirmOverlay.acceptedHold) ? 1.0 : 0.0
                        Behavior on progress {
                            NumberAnimation { duration: pixelGrid.revealDuration; easing.type: Easing.Linear }
                        }

                        Repeater {
                            model: pixelGrid.cols * pixelGrid.rows
                            delegate: Rectangle {
                                id: cell
                                readonly property int row: Math.floor(index / pixelGrid.cols)
                                readonly property int col: index % pixelGrid.cols
                                readonly property real posFromTop: pixelGrid.rows > 1
                                    ? row / (pixelGrid.rows - 1) : 0
                                readonly property real threshold: Math.min(1, Math.max(0,
                                    posFromTop * (1 - pixelGrid.noiseAmount) + Math.random() * pixelGrid.noiseAmount))
                                width: pixelGrid.pixelSize + 1
                                height: pixelGrid.pixelSize + 1
                                x: col * pixelGrid.pixelSize
                                y: row * pixelGrid.pixelSize
                                color: Qt.darker(bgColor, 1.15)
                                antialiasing: false
                                opacity: pixelGrid.progress >= threshold ? 1 : 0
                                visible: opacity > 0.5
                            }
                        }

                        // Lớp phủ "chốt" 100% - đảm bảo lúc phủ kín xong là 1 mảng màu đặc,
                        // không còn kẽ hở antialiasing/subpixel giữa các ô.
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.darker(bgColor, 1.15)
                            antialiasing: false
                            opacity: pixelGrid.progress >= 1 ? 1 : 0
                            visible: opacity > 0
                        }
                    }

                    // ---- Nội dung - CHỈ hiện trên màn hình đang có con trỏ chuột, và chỉ sau khi
                    // lưới pixel phủ xong. ----
                    Item {
                        anchors.fill: parent
                        opacity: (confirmOverlay.activeShow && confirmOverlay.revealDone) ? 1 : 0
                        visible: opacity > 0.01

                        // Overlay toàn màn hình (PowerOverlay.qml) cho cả 4 trạng thái:
                        // shutdown / reboot / shutdown30 / warning.
                        View {
                            anchors.fill: parent
                            mode: confirmOverlay.displayAction
                            active: confirmOverlay.activeShow && confirmOverlay.revealDone
                            standby: !confirmOverlay.isCursorScreen
                            managing: root.confirmManaging
                            stats: root.sysStats
                            closing: root.confirmClosing
                            bgColor: root.bgColor
                            fgColor: root.fgColor
                            mutedColor: root.mutedColor
                            accentColor: root.accentColor
                            dangerColor: root.dangerColor
                            fontTitle: root.fontTitle
                            fontLabel: root.fontLabel
                            fontData: root.fontData
                            fontNumeral: root.fontNumeral
                            fontKanji: root.fontKanji
                            preset: root.themePreset
                            tint: root.tint
                            inkDarken: root.inkDarken
                            bootMs: root.bootMs
                            outroMs: root.outroMs
                            scanOpacity: root.scanOpacity
                            scanlinesEnabled: root.scanlinesEnabled
                            glitchEnabled: root.glitchEnabled
                            scaleBoost: root.scaleBoost
                            userName: root.userName
                            choice: root.confirmChoice
                            checkpoints: root.durationCheckpointsMin
                            selectedIndex: root.safeDurationIndex
                            countdownText: root.confirmManaging ? root.formatMMSS(Math.round(root.countdownRemainingSec))
                                                                : root.formatMMSS(root.warningRemainingSec)
                            countdownSec: Math.round(root.countdownRemainingSec)
                            countdownFraction: root.confirmManaging ? root.countdownRemainingFraction
                                : (root.activeWarningSec > 0
                                    ? Math.max(0, Math.min(1, root.warningRemainingSec / root.activeWarningSec)) : 0)
                            warningSec: root.delayedShutdownWarning ? root.activeWarningSec : root.warningDurationSec
                            onChoiceRequested: (index) => root.confirmChoice = index
                            onIndexRequested: (index) => {
                                root.durationManuallyAdjusted = true
                                root.selectedDurationIndex = index
                            }
                            onSwitchRequested: (m) => root.switchConfirm(m)
                            onConfirmed: root.resolveConfirm("yes")
                            onCancelled: root.resolveConfirm(root.confirmManaging ? "abort" : (root.confirmAction !== "" ? "no" : "abort"))
                        }
                    }
                } // Item (key handler + dither + content)
            } // confirmOverlay
        } // panel
    } // Variants
} // ShellRoot
