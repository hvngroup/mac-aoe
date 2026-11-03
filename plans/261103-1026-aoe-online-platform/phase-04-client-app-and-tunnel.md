---
phase: 4
title: "App desktop và helper mạng Mac/Windows"
status: pending
priority: P1
effort: 3w
dependencies: [2, 3]
---

# Phase 4: App desktop và helper mạng

## Mục tiêu

Một app cho Mac và Windows: đăng nhập, sảnh, danh sách phòng, chat. Một helper
chạy nền giữ kết nối WireGuard tới hub.

## Thành phần

| Thành phần | Mac | Windows |
|-----------|-----|---------|
| UI | Wails v2 (WebKit) | Wails v2 (WebView2) |
| Helper mạng | Daemon launchd chạy quyền root, dùng `wireguard-go` trên `utun`. Đăng ký bằng `SMAppService` | Windows Service dùng `wireguard-go` trên Wintun |
| Giao tiếp UI và helper | Unix socket `/var/run/aoe-online.sock`, chỉ user hiện tại truy cập | Named pipe, ACL cho user hiện tại |
| Cài đặt | `.dmg`, kéo vào Applications, lần đầu hỏi quyền admin để cài helper | Bộ cài `.msi` (WiX) cài app, service và Wintun |

## Màn hình

1. Đăng nhập và đăng ký (email/số điện thoại, nút Google)
2. Sảnh: danh sách phòng (tên, chủ phòng, số người, xếp hạng hay giao hữu, nền tảng), danh sách người online, khung chat sảnh
3. Phòng chờ: thành viên và độ trễ, chat phòng, nút "Bắt đầu" cho chủ phòng
4. Hồ sơ và cài đặt (đường dẫn game trên Windows, chế độ hiển thị trên Mac)

## Việc cần làm

1. Khung Wails, đăng nhập (PKCE và loopback cho Google), lưu refresh token
   trong Keychain (Mac) và Credential Manager (Windows).
2. Client WebSocket tự kết nối lại, đồng bộ trạng thái sảnh.
3. Helper: sinh khoá, đăng ký thiết bị, bật hoặc tắt tunnel, báo trạng thái.
   Helper chỉ nhận lệnh từ UI cùng máy.
4. Route chỉ dải `10.77.0.0/16` qua tunnel (split tunnel), không đụng Internet
   của người chơi.

## Tiêu chí đạt

- [ ] Trên Mac (Apple Silicon, macOS 15 trở lên) và Windows 10/11: cài, đăng nhập, thấy sảnh, chat qua lại giữa hai nền tảng
- [ ] Bật tunnel thì `ping` được hub. Internet thường không đi qua tunnel (kiểm tra bằng `traceroute 1.1.1.1`)
- [ ] Mất mạng 30 giây thì app và tunnel tự nối lại
- [ ] Gỡ app thì gỡ cả helper, Wintun và route

## File

- Mới: `client/` (Wails), `client/helper/` (daemon và service), `installer/mac/`, `installer/windows/`

## Rủi ro

- `SMAppService` daemon và notarize cần Developer ID. Bản nội bộ trước đó cài
  helper bằng script `sudo` (đã ghi trong phase 7).
- Wine trên Mac phải đi được qua `utun`. Phase 1 đã kiểm tra với app WireGuard
  chính thức; phase này kiểm tra lại với helper tự viết.
