---
title: "Nền tảng chơi AoE online cho Mac và Windows"
description: "Máy chủ sảnh và mạng ảo để người chơi Mac và Windows tạo phòng, vào phòng, chat, kết bạn và xếp hạng ELO khi chơi AoE RoR qua Internet"
status: pending
priority: P2
effort: 13w
branch: claude/blissful-mayer-91sloi
tags: [backend, networking, desktop-app, game]
blockedBy: []
blocks: []
created: 2026-11-03
---

# Nền tảng chơi AoE online (tên dự án tạm: AoE Online)

## Mục tiêu

Người chơi Mac và Windows đăng nhập một app, thấy sảnh có danh sách phòng, chat,
bấm **Tạo phòng** hoặc **Join**, và game AoE RoR tự mở vào đúng trận với nhau qua
Internet. Trải nghiệm giống Ego Play. Thêm danh sách bạn bè, lời mời và xếp hạng ELO.

## Quyết định đã chốt (từ người dùng, 2026-11-03)

| Mục | Quyết định |
|-----|-----------|
| Nền tảng | Mac và Windows, chơi chung một phòng |
| Quy mô bản đầu | Dưới 200 người chơi cùng lúc |
| Tài khoản | Tài khoản riêng (email/số điện thoại và mật khẩu) và đăng nhập Google |
| Tính năng bản đầu | Sảnh và phòng, chat sảnh/phòng, bấm Join là vào game, xếp hạng ELO, bạn bè và lời mời |

## Ràng buộc

- Không sửa file game. Game vẫn chạy DirectPlay TCP/IP như chơi LAN.
- Trên Mac, game chạy qua bộ công cụ `mac-aoe`: Wine 11.21, cnc-ddraw và
  `directplay microsoft`. Bộ này đã tạo được phòng trên macOS 27.
- Hạ tầng ở Việt Nam, chạy trên HVN Cloud. Một VPS là đủ cho dưới 200 người.
- Không lưu mật khẩu dạng rõ. Dữ liệu cá nhân tuân thủ quy định Việt Nam (xem rủi ro R6).

## Ngoài phạm vi bản đầu

- Ghép trận tự động (matchmaking), giải đấu, xem trực tiếp, ghi lại trận.
- Game khác ngoài AoE RoR. Schema giữ sẵn trường `game_id` (xem phần mở rộng).
- Thanh toán, vật phẩm, VIP.
- App di động.

## Kiến trúc

```mermaid
flowchart LR
  subgraph PC_A[Máy người chơi A - Mac]
    UIA[App AoE Online] --> HA[Helper mạng<br/>WireGuard utun]
    UIA --> LA[aoelobby.exe<br/>qua Wine]
    LA --> GA[EMPIRESX.EXE<br/>DirectPlay Microsoft]
  end
  subgraph PC_B[Máy người chơi B - Windows]
    UIB[App AoE Online] --> HB[Helper mạng<br/>WireGuard Wintun]
    UIB --> LB[aoelobby.exe]
    LB --> GB[EMPIRESX.EXE<br/>DirectPlay Windows]
  end
  subgraph VPS[VPS HVN Cloud]
    API[API + WebSocket<br/>sảnh, chat, bạn bè, ELO]
    DB[(PostgreSQL)]
    HUB[WireGuard hub<br/>cách ly theo phòng]
    API --> DB
    API -- cấp peer, mở luật phòng --> HUB
  end
  UIA <-- HTTPS/WSS --> API
  UIB <-- HTTPS/WSS --> API
  HA <-- UDP 51820 --> HUB
  HB <-- UDP 51820 --> HUB
  GA <-. DirectPlay qua IP ảo 10.77.x.y .-> GB
```

**Vì sao dùng mạng ảo thay vì chuyển tiếp từng cổng.** DirectPlay ghi địa chỉ
IP của người gửi vào gói tin, và mở thêm cổng động (2300–2400, 47624). NAT trên
Internet làm sai các địa chỉ đó. Khi mỗi người chơi có một IP ảo cố định trong
mạng riêng, game thấy nhau như đang chung một mạng LAN và không cần sửa gì.

**Vì sao đi qua hub thay vì kết nối thẳng giữa các máy.** AoE chỉ dùng vài
KB/s mỗi người và chịu được độ trễ 100–200 ms. Hub ở Việt Nam thêm khoảng
20–40 ms. Đổi lại, không phải xử lý NAT khó, và máy chủ kiểm soát được ai nói
chuyện với ai: chỉ các máy trong cùng phòng mới thấy nhau.

**Vì sao "bấm Join là vào game" dùng DirectPlay Lobby.** Game đã đăng ký sẵn
`EmpiresX.Exe` với tham số `lobby` (registry
`DirectPlay\Applications\Age of Empires Expansion`). Một chương trình nhỏ
`aoelobby.exe` gọi `IDirectPlayLobby3::RunApplication` với địa chỉ TCP/IP của
chủ phòng. Game mở lên và vào thẳng phòng, không cần dò phòng bằng broadcast,
vốn không đi qua được WireGuard.

## Các phase

| # | Phase | Công sức | Phụ thuộc | Trạng thái |
|---|-------|----------|-----------|-----------|
| 1 | [Spike: mạng ảo và lobby launch](phase-01-spike-network-and-lobby.md) | 1 tuần | – | pending |
| 2 | [Backend lõi: tài khoản, sảnh, phòng, chat](phase-02-backend-core.md) | 2 tuần | 1 | pending |
| 3 | [Mạng ảo: WireGuard hub và cách ly theo phòng](phase-03-network-control-plane.md) | 1,5 tuần | 1, 2 | pending |
| 4 | [App desktop và helper mạng Mac/Windows](phase-04-client-app-and-tunnel.md) | 3 tuần | 2, 3 | pending |
| 5 | [Mở game một chạm: aoelobby.exe, Mac và Windows](phase-05-game-launch-integration.md) | 2 tuần | 1, 4 | pending |
| 6 | [Bạn bè, lời mời, xếp hạng ELO](phase-06-friends-and-ranking.md) | 2 tuần | 2, 5 | pending |
| 7 | [Vận hành, bảo mật, phát hành beta](phase-07-ops-security-release.md) | 1,5 tuần | 1–6 | pending |

Tổng khoảng 13 tuần cho 2 lập trình viên. Phase 2–3 và một phần phase 5
(`aoelobby.exe`) chạy song song được sau phase 1.

**Cổng go/no-go sau phase 1.** Nếu DirectPlay không chạy ổn qua WireGuard giữa
Mac và Windows, hoặc lobby launch không chạy dưới Wine, phải dừng và chọn lại
cách làm trước khi đầu tư phase 2–7 (xem phương án dự phòng trong phase 1).

## Công nghệ đề xuất

| Thành phần | Lựa chọn | Lý do |
|-----------|----------|-------|
| Backend | Go, một binary: REST + WebSocket | Thư viện WireGuard chính chủ (`wgctrl`, `wireguard-go`), dễ vận hành, đủ cho dưới 200 người trên một instance |
| CSDL | PostgreSQL | Tài khoản, bạn bè, trận, ELO. Trạng thái sảnh và phòng giữ trong bộ nhớ |
| App desktop | Wails v2 (Go + web UI) | Một code cho Mac và Windows. Dùng chung model với backend. Nhúng được `wireguard-go` |
| Mạng ảo | WireGuard: `utun` trên Mac, Wintun trên Windows | Mã nguồn mở, nhanh, xuyên NAT tốt. Chạy trong helper có quyền admin |
| Mở game | `aoelobby.exe` viết bằng C, build bằng mingw | Cùng một file chạy trên Windows và trong Wine trên Mac |
| Hạ tầng | 1 VPS HVN Cloud (2 vCPU, 4 GB RAM), Docker Compose, Caddy (TLS) | Rẻ, đủ cho quy mô bản đầu |

## Mở rộng sau này (extension trace)

Biến thể dễ đến nhất là **thêm một game DirectPlay khác** (AoE2, Đế Chế Map Đồng
Minh). Phần không đổi là phòng, mạng ảo và luật cách ly. Phần phải đổi là thông
tin khởi chạy (GUID ứng dụng DirectPlay, đường dẫn exe) và cách tính kết quả
trận. Bản đầu chỉ thêm cột `game_id` vào bảng `rooms` và `matches`, và để
`aoelobby.exe` nhận GUID ứng dụng qua tham số. Không làm hệ thống plugin.
Phase 5 kiểm chứng việc này bằng một test chạy `aoelobby.exe` với GUID truyền
vào.

## Rủi ro chính

| # | Rủi ro | Mức | Cách xử lý |
|---|--------|-----|-----------|
| R1 | DirectPlay giữa Mac (Wine + DirectPlay Microsoft) và Windows không tương thích | Cao | Phase 1 thử thật Mac↔Windows trước mọi việc khác |
| R2 | Lobby launch không chạy dưới Wine | Trung bình | Phase 1 thử. Dự phòng: app tự điền IP chủ phòng, người chơi bấm Join trong game |
| R3 | Game không báo kết quả trận cho lobby, nên không tự tính ELO được | Trung bình | Phase 1 kiểm tra lobby message. Dự phòng: hai bên cùng xác nhận kết quả trong app |
| R4 | Helper mạng cần quyền admin. Mac cần ký Developer ID và notarize, Windows cần chữ ký code | Trung bình | Phase 7 làm ký số. Thử nghiệm nội bộ dùng bản chưa ký |
| R5 | Bản quyền: game AoE thuộc Microsoft. Phân phối file game công khai qua nền tảng thương mại có rủi ro pháp lý | Cao | Cần pháp chế HVN rà soát trước khi mở công khai. Một phương án là người chơi tự cung cấp bản game của mình |
| R6 | Pháp lý vận hành tại Việt Nam: dịch vụ trò chơi điện tử và mạng xã hội (Nghị định 147/2024/NĐ-CP), dữ liệu cá nhân (Nghị định 13/2023/NĐ-CP, Luật Bảo vệ dữ liệu cá nhân) | Cao | Pháp chế xác nhận loại giấy phép cần có trước khi mở công khai. Beta nội bộ giới hạn người tham gia |
| R7 | Lạm dụng: spam chat, gian lận ELO, dùng mạng ảo để tấn công máy người khác | Trung bình | Cách ly theo phòng (phase 3), giới hạn tốc độ, báo cáo và chặn người dùng (phase 7) |

## Tiêu chí hoàn thành bản beta

- [ ] Hai máy Mac và hai máy Windows ở hai mạng khác nhau (ví dụ Hà Nội và TP.HCM) chơi trọn một ván 4 người qua app
- [ ] Từ lúc bấm Join đến lúc vào phòng chờ trong game dưới 15 giây
- [ ] Độ trễ khứ hồi qua hub dưới 80 ms giữa Hà Nội và TP.HCM
- [ ] Máy ngoài phòng không ping được IP ảo của máy trong phòng
- [ ] Đăng ký, đăng nhập email và Google, chat, bạn bè, lời mời chạy được trên cả hai nền tảng
- [ ] Sau một ván xếp hạng, ELO của cả hai bên được cập nhật đúng
- [ ] Tải thử 200 kết nối WebSocket đồng thời: CPU VPS dưới 50%, không mất tin nhắn

## Câu hỏi còn mở

1. Tên sản phẩm và tên miền (ví dụ `play.hvn.vn`)? Do công ty thành viên nào vận hành (HVN Digital, HVN Software)?
2. Mở công khai cho cộng đồng hay chỉ beta nội bộ trước? Câu trả lời quyết định thời điểm cần xử lý R5 và R6.
3. Có máy Windows và nhóm người thử ở hai thành phố cho phase 1 không?
4. HVN có sẵn tài khoản Apple Developer (Developer ID) và chứng chỉ ký code Windows chưa?

---

HVN GROUP · hvn.vn
