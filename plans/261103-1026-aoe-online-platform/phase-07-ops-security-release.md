---
phase: 7
title: "Vận hành, bảo mật, phát hành beta"
status: pending
priority: P1
effort: 1.5w
dependencies: [1, 2, 3, 4, 5, 6]
---

# Phase 7: Vận hành, bảo mật, phát hành beta

## Mục tiêu

Đưa nền tảng lên VPS HVN Cloud, ký và phát hành app, mở beta có kiểm soát.

## Việc cần làm

### Hạ tầng

- VPS HVN Cloud 2 vCPU / 4 GB / 40 GB SSD, đặt tại Việt Nam. Docker Compose:
  `server`, `wghub` (process riêng, có `CAP_NET_ADMIN`), `postgres`, `caddy`
- Tên miền `aoe.hvn.works` và TLS (Caddy tự cấp chứng chỉ). Mở cổng 443/TCP và 51820/UDP
- Sao lưu PostgreSQL mỗi ngày (`pg_dump`), giữ 14 bản, lưu ra ngoài VPS. Thử khôi phục một lần trước khi mở beta
- Giám sát: endpoint `/healthz`, Uptime Kuma hoặc dịch vụ tương đương, cảnh báo về email kythuat@hvn.vn

### Bảo mật

- Giới hạn tốc độ đăng nhập, đăng ký, chat. Khoá tạm tài khoản sau nhiều lần sai mật khẩu
- Secret (OAuth Google, khoá ký JWT) lưu trong biến môi trường hoặc file chỉ root đọc được, không commit
- Mạng ảo chỉ mở cổng DirectPlay trong phòng (phase 3). Thử xâm nhập cơ bản: quét cổng từ một peer khác phòng
- Admin: chặn người dùng, tắt tiếng chat, xoá tin nhắn, xử lý tranh chấp kết quả trận

### Ký và phát hành app

- Mac: ký Developer ID, notarize, đóng `.dmg`. Helper đăng ký bằng `SMAppService`
- Windows: beta nội bộ phát hành bản chưa ký (đã được chấp nhận). Tài liệu beta hướng dẫn "More info, Run anyway" khi SmartScreen cảnh báo. Wintun vẫn là bản đã ký của WireGuard LLC, nên driver cài được. Ký code trước khi mở công khai
- Trang tải và hướng dẫn cài, dựa trên `mac-aoe/docs/huong-dan-thu-nghiem.md`

### Pháp lý (trước khi mở công khai)

- Pháp chế HVN rà soát: bản quyền game (rủi ro R5), giấy phép dịch vụ trò chơi
  điện tử hoặc mạng xã hội (Nghị định 147/2024/NĐ-CP), dữ liệu cá nhân (Nghị
  định 13/2023/NĐ-CP, Luật Bảo vệ dữ liệu cá nhân)
- Điều khoản sử dụng và chính sách bảo mật hiển thị khi đăng ký

### Beta

- Beta nội bộ: nhân viên HVN và 20–50 người chơi được mời, trong 2 tuần
- Thu phản hồi bằng form và log app. Chỉ mở rộng khi các tiêu chí trong `plan.md` đều đạt

## Tiêu chí đạt

- [ ] Khôi phục được CSDL từ bản sao lưu trên một VPS mới
- [ ] Quét cổng từ peer khác phòng không thấy cổng nào mở
- [ ] App Mac mở được mà không cần "Open Anyway". App Windows cài được sau bước "Run anyway"
- [ ] Có văn bản xác nhận của pháp chế trước khi mở công khai
- [ ] Beta 2 tuần: không mất dữ liệu, thời gian hoạt động trên 99%

## File

- Mới: `deploy/` (compose, Caddyfile, script backup), `docs/van-hanh.md`, `docs/dieu-khoan.md`
