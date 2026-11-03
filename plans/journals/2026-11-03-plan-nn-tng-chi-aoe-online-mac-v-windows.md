---
title: Plan nền tảng chơi AoE online Mac và Windows
date: 2026-11-03
summary: "Lập plan 7 phase cho dịch vụ kiểu Ego Play: mạng ảo WireGuard có cách ly theo phòng và lobby launch DirectPlay"
---

# Plan nền tảng chơi AoE online Mac và Windows

## What happened
Lập plan `plans/261103-1026-aoe-online-platform/` cho nền tảng chơi AoE RoR online, phạm vi do người dùng chốt: Mac và Windows chơi chung, dưới 200 người cùng lúc, tài khoản riêng kèm đăng nhập Google, chat sảnh và phòng, bấm Join là vào game, ELO, bạn bè và lời mời.

## Decision
- Mạng ảo WireGuard đi qua một hub ở Việt Nam thay vì chuyển tiếp cổng. Lý do: DirectPlay ghi IP người gửi vào gói tin và mở cổng động 2300–2400 và 47624, nên NAT làm hỏng kết nối. Hub dùng nftables để chỉ cho các máy cùng phòng nói chuyện với nhau, và chỉ trên cổng DirectPlay.
- "Bấm Join là vào game" dùng DirectPlay Lobby `RunApplication` qua `aoelobby.exe`, một chương trình C build bằng mingw, chạy trực tiếp trên Windows và qua Wine trên Mac. Game đã đăng ký sẵn `EmpiresX.Exe` với tham số `lobby`. Cách này không cần broadcast, vốn không đi qua được WireGuard.
- Stack: Go cho backend và hub (wgctrl), PostgreSQL, Wails cho app desktop, helper chạy quyền admin dùng wireguard-go (utun trên Mac, Wintun trên Windows).

## Next steps
- Phase 1 là cổng go/no-go: chơi Mac↔Windows qua WireGuard hub, lobby launch dưới Wine, kiểm tra game có gửi lobby message về kết quả trận hay không. Kết quả quyết định cách tính ELO.
- Rủi ro cao cần pháp chế xem trước khi mở công khai: bản quyền game của Microsoft, giấy phép dịch vụ trò chơi điện tử tại Việt Nam, bảo vệ dữ liệu cá nhân.

> Historical work record — not durable authority. Prefer docs/specs/ADRs for current decisions.
