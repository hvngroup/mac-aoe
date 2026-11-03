---
phase: 1
title: "Spike: mạng ảo và lobby launch"
status: pending
priority: P1
effort: 1w
dependencies: []
---

# Phase 1: Spike mạng ảo và lobby launch (cổng go/no-go)

## Mục tiêu

Chứng minh bằng thử nghiệm thật ba giả định mà cả dự án dựa vào, trước khi
viết dòng code sản phẩm nào:

1. DirectPlay của AoE chạy ổn qua WireGuard đi qua hub, giữa Mac và Windows.
2. Lobby launch (`RunApplication`) mở được game vào đúng phòng, trên Windows
   và trong Wine trên Mac.
3. Biết được game có báo kết quả trận cho lobby hay không (quyết định cách tính ELO).

## Việc cần làm

1. **Dựng hub thủ công.** Trên một VPS HVN Cloud, cài WireGuard, cấp 4 peer
   `10.77.0.11–14`, bật `net.ipv4.ip_forward` và cho phép forward giữa các peer.
   Người thử dùng app WireGuard chính thức (Mac App Store, wireguard.com cho
   Windows).
2. **Thử chơi bằng IP gõ tay.** Ghép từng cặp Mac↔Mac, Mac↔Windows,
   Windows↔Windows. Một máy tạo phòng TCP/IP, máy kia gõ IP ảo của chủ phòng.
   Sau đó chơi một ván 4 người. Ghi lại thời gian vào phòng, độ trễ
   (`ping 10.77.0.x`), số lần lag hoặc mất đồng bộ (sync error).
3. **Viết `aoelobby.exe` bản thử** (C, mingw, dưới 300 dòng):
   - `aoelobby host --name A --session "Phong 1" --max 8`
   - `aoelobby join --name B --host 10.77.0.11`
   Chương trình gọi `IDirectPlayLobby3A::RunApplication` với `DPLCONNECTION`
   gồm GUID ứng dụng `{8701C5C1-337B-11d2-839B-00609707F508}`, địa chỉ TCP/IP
   (`DPAID_INet`), cờ `DPLCONNECTION_CREATESESSION` hoặc `JOINSESSION`.
4. **Thử lobby launch** trên Windows và trên Mac
   (`wine aoelobby.exe ...` trong prefix của mac-aoe, `directplay microsoft`).
5. **Kiểm tra lobby message.** Cho `aoelobby.exe` chờ `ReceiveLobbyMessage`
   sau khi mở game và ghi mọi message nhận được trong một ván đến lúc có kết quả.
6. Ghi lại cấu hình máy, phiên bản macOS/Windows, log `aoe-mac logs`, và lưu
   kết quả vào `reports/phase-01-spike-results.md`.

## Tiêu chí đạt (go)

- [ ] Mac↔Windows chơi trọn một ván 20 phút qua hub, không mất đồng bộ
- [ ] Ván 4 người (2 Mac, 2 Windows) chơi trọn
- [ ] `aoelobby join` đưa game vào phòng chờ của chủ phòng trên cả hai nền tảng
- [ ] Đã biết game có hay không gửi lobby message về kết quả trận

## Phương án dự phòng (nếu no-go)

| Điều kiện thất bại | Phương án |
|--------------------|-----------|
| Mac↔Windows không tương thích, Mac↔Mac và Windows↔Windows vẫn được | Phòng chỉ gồm một nền tảng. Ghi nhãn nền tảng cho phòng. Tiếp tục thử hướng B (DirectPlay của Wine đã vá) |
| Lobby launch không chạy dưới Wine | App hiện IP chủ phòng, tự chép vào clipboard. Người chơi tự bấm Join trong game |
| Không có lobby message về kết quả | ELO dựa vào hai bên cùng xác nhận kết quả trong app (phase 6) |
| DirectPlay qua WireGuard lag hoặc mất đồng bộ | Thử kết nối thẳng giữa các máy (WireGuard mesh, hub chỉ để điều phối). Thêm 2 tuần vào phase 3 |

## File

- Mới: `aoe-online/tools/aoelobby/aoelobby.c`, `Makefile`
- Mới: `reports/phase-01-spike-results.md`

## Rủi ro

- Thiếu máy Windows và người thử ở hai thành phố khác nhau. Cần chuẩn bị trước.
- AoE có thể đòi phiên bản DirectPlay giống nhau ở mọi máy. Ghi lại phiên bản
  `dplayx.dll` của từng máy.
