---
phase: 1
title: "Spike: mạng ảo và lobby launch"
status: in-progress
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

1. **Dựng hub thủ công.** Trên một VPS HVN Cloud có bản ghi DNS `aoe.hvn.works`,
   chạy `setup-hub.sh`, rồi `add-peer.sh` cho từng người thử (`10.77.0.11` trở đi).
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

Đặt tạm trong repo `mac-aoe` dưới `online/spike/` cho đến khi có repo riêng:

- Mới: `online/spike/hub/setup-hub.sh`, `online/spike/hub/add-peer.sh` (dựng hub trên VPS, cấp cấu hình cho người thử)
- Mới: `online/spike/aoelobby/aoelobby.c`, `lobbytarget.c`, `run-lobby-test.sh` (mở game qua lobby và test trên Wine)
- Mới: `reports/phase-01-spike-results.md`
- Mới: `docs/thu-nghiem-choi-online.md` (hướng dẫn chạy thử cho quản trị và người thử)
- Sửa: `lib/game.sh`, `aoe-mac` (lệnh `aoe-mac lobby`, dùng chung DLL override với lúc chơi)

## Tiến độ (2026-11-03)

- [x] Script hub: test trong network namespace Linux đạt 25/25. TCP 2300 và UDP 47624 qua được, TCP 22 bị chặn, máy bị gỡ không vào được nữa, địa chỉ được dùng lại
- [x] `aoelobby.exe`: test trên Wine (Linux, DirectPlay của Wine) đạt 14/14. Chương trình giả lập game nhận đúng vai trò, IP chủ phòng, GUID phiên, tên người chơi, số người tối đa
- [x] `aoe-mac lobby` chạy `aoelobby.exe` trong prefix của mac-aoe với cùng DLL override như lúc chơi
- [ ] Dựng hub trên VPS `aoe.hvn.works`
- [ ] Thử A, B, C với người thật (xem `docs/thu-nghiem-choi-online.md`)
- Ghi chú: DirectPlay của Wine bỏ trống `SendLobbyMessage` (trả `0x8007000e`), nên thử C phải làm với DirectPlay của Microsoft (Mac) và Windows thật

Ở bản spike, `add-peer.sh` sinh khoá cho người thử ngay trên VPS cho nhanh. Bản
sản phẩm (phase 3–4) sinh khoá trên máy người chơi.

## Rủi ro

- Thiếu máy Windows và người thử ở hai thành phố khác nhau. Cần chuẩn bị trước.
- AoE có thể đòi phiên bản DirectPlay giống nhau ở mọi máy. Ghi lại phiên bản
  `dplayx.dll` của từng máy.
