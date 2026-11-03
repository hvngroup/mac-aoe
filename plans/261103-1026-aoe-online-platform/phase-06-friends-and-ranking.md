---
phase: 6
title: "Bạn bè, lời mời, xếp hạng ELO"
status: pending
priority: P2
effort: 2w
dependencies: [2, 5]
---

# Phase 6: Bạn bè, lời mời, xếp hạng ELO

## Mục tiêu

Người chơi kết bạn, thấy bạn đang online hay đang trong trận, mời bạn vào
phòng. Trận xếp hạng cập nhật ELO và bảng xếp hạng.

## Bạn bè và lời mời

- Bảng `friendships(user_id, friend_id, state: pending|accepted|blocked, created_at)`
- Gửi, chấp nhận, từ chối, huỷ kết bạn, chặn
- Trạng thái: offline, online, trong phòng, đang chơi (sự kiện `presence` qua WebSocket)
- Mời vào phòng: thông báo trong app, bấm là vào phòng (kèm mật khẩu phòng nếu có)
- Người bị chặn không gửi được lời mời hay tin nhắn

## Xếp hạng ELO

- Chỉ áp dụng cho phòng gắn nhãn "xếp hạng", 1v1 hoặc chia đội đều (2v2, 3v3, 4v4)
- Điểm khởi đầu 1200. Hệ số K = 32 cho 20 trận đầu, sau đó K = 16
- Đội: dùng điểm trung bình của đội để tính kỳ vọng, cộng hoặc trừ như nhau cho
  mỗi thành viên
- Bảng `matches(id, room_id, game_id, ranked, started_at, ended_at, result_source)` và
  `match_players(match_id, user_id, team, outcome, elo_before, elo_after)`

### Ghi nhận kết quả (theo kết quả phase 1)

| Kết quả phase 1 | Cách ghi nhận |
|-----------------|---------------|
| Game gửi lobby message về kết quả | `aoelobby.exe` chuyển message về app, app gửi server. Server chỉ chấp nhận khi đa số người chơi trong trận gửi cùng kết quả |
| Không có lobby message | Sau trận, app hỏi "Ai thắng?". Hai bên cùng xác nhận thì tính ELO. Không khớp thì trận chuyển sang "tranh chấp" để admin xử lý. Quá 30 phút không xác nhận thì không tính |

- Rời trận giữa chừng (mất tunnel quá 2 phút trong trận xếp hạng) tính là thua
- Bảng xếp hạng: top 100, lọc theo tháng, trang hồ sơ có lịch sử trận

## Tiêu chí đạt

- [ ] Unit test công thức ELO: 1v1, 2v2, đội lệch điểm, người mới với K = 32
- [ ] Test luồng xác nhận: khớp thì cập nhật ELO; không khớp thì vào tranh chấp; quá hạn thì bỏ
- [ ] Test chặn người dùng: không mời, không nhắn được
- [ ] Thủ công: 4 người chơi 2v2 xếp hạng, bảng xếp hạng cập nhật đúng

## File

- Mới: `server/internal/{friends,ranking,matches}`, migration mới
- Sửa: `client/` (màn hình bạn bè, bảng xếp hạng, hộp thoại kết quả)
