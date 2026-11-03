# sumi-jigen 時限

Shutdown, reboot và hẹn giờ tắt máy, một app (daemon) của hệ thống SUMI.

- Chạy: `sumi jigen <shutdown|reboot|timer>` (hoặc `shutdown30`, tên IPC cũ của function `timer`).
- IPC: `sumi-jigen` (mới) và `clock-widget` (giữ để bind cũ chạy tiếp). Thêm `reload()` để đọc lại config.
- Khi đang hẹn giờ, app sống nền và giữ thẻ đếm giờ ở góc; thoát/cập nhật app sẽ hủy hẹn giờ.
- Config: `~/.config/sumi/config.json` (`apps.jigen.options`, `fonts`, `keybinds`), màu: `~/.config/sumi/colors.json`.
  Đổi config chỉ áp dụng cho lần mở overlay kế tiếp, không đụng timer đang chạy.

`View.qml` là overlay thuần (không Process); `shell.qml` giữ trạng thái, timer và hành động hệ thống.
`objects/` chứa globe/torus/hourglass; chọn object theo function sẽ có ở GĐ2.
