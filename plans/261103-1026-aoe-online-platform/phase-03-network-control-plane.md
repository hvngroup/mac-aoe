---
phase: 3
title: "Mạng ảo: WireGuard hub và cách ly theo phòng"
status: pending
priority: P1
effort: 1.5w
dependencies: [1, 2]
---

# Phase 3: WireGuard hub và cách ly theo phòng

## Mục tiêu

Mỗi người chơi có một IP ảo cố định. Hub chỉ chuyển gói giữa các máy đang ở
cùng một phòng.

## Thiết kế

- **Dải địa chỉ:** `10.77.0.0/16`. Mỗi tài khoản được gán một IP ảo cố định
  khi đăng ký thiết bị, lưu trong bảng `devices(user_id, public_key, virtual_ip, last_seen)`.
- **Khoá:** khoá riêng WireGuard sinh trên máy người chơi và không rời khỏi
  máy đó. App chỉ gửi khoá công khai lên `POST /devices`.
- **Hub:** service backend quản lý interface `wg0` bằng `wgctrl` (thêm hoặc xoá
  peer). Peer không hoạt động quá 24 giờ thì bị gỡ.
- **Cách ly theo phòng:** mặc định chặn mọi forward giữa các peer
  (`nftables`, chain `forward`, policy drop). Khi một người vào phòng, backend
  thêm IP ảo của họ vào set `room_<id>`. Một luật chỉ cho phép forward khi IP
  nguồn và IP đích cùng thuộc một set phòng. Rời phòng thì gỡ khỏi set.
- **Cổng DirectPlay:** chỉ cho TCP và UDP 2300–2400 và 47624 giữa các thành viên
  phòng. Chặn các cổng khác (SMB, SSH...) để mạng ảo không thành đường tấn công.
- **Đo trễ:** app ping hub mỗi 30 giây và báo về backend. Sảnh hiện mức độ kết
  nối (tốt, trung bình, kém) cạnh tên người chơi.

## Tiêu chí đạt

- [ ] Test tích hợp trong network namespace Linux: 3 peer, 2 ở phòng A, 1 ở phòng B. Trong phòng A gửi được TCP 2300 và UDP 47624; từ phòng B sang phòng A bị chặn; cổng 22 bị chặn trong mọi trường hợp
- [ ] Vào hoặc rời phòng thì luật được cập nhật trong vòng 1 giây
- [ ] Hub khởi động lại thì khôi phục peer và set phòng từ CSDL
- [ ] Băng thông 8 người một phòng đo được dưới 100 KB/s tổng

## File

- Mới: `server/internal/wghub/`, `server/internal/firewall/` (nftables qua `google/nftables`)
- Sửa: `server/internal/rooms` (gọi firewall khi vào hoặc rời phòng)

## Rủi ro

- Backend cần quyền `CAP_NET_ADMIN`. Chạy riêng phần hub thành một process có
  quyền tối thiểu, nói chuyện với API qua socket nội bộ.
