---
phase: 2
title: "Backend lõi: tài khoản, sảnh, phòng, chat"
status: pending
priority: P1
effort: 2w
dependencies: [1]
---

# Phase 2: Backend lõi

## Mục tiêu

Một service Go chạy trên VPS phục vụ đăng ký và đăng nhập, sảnh thời gian thực,
vòng đời phòng và chat.

## Thành phần

| Module | Nội dung |
|--------|---------|
| `auth` | Đăng ký email hoặc số điện thoại, mật khẩu băm bằng Argon2id. Đăng nhập Google (OAuth 2.0 / OpenID Connect, PKCE cho app desktop). Access token ngắn hạn và refresh token xoay vòng |
| `profile` | Nickname duy nhất, avatar, nền tảng (mac/windows), ngày tham gia |
| `lobby` | WebSocket `/ws`: danh sách người online, danh sách phòng, sự kiện thay đổi |
| `rooms` | Tạo, vào, rời, khoá phòng. Chủ phòng, tối đa 8 người, mật khẩu phòng tuỳ chọn, `game_id`, nhãn "xếp hạng" hoặc "giao hữu". Trạng thái: chờ, đang chơi, kết thúc |
| `chat` | Kênh sảnh và kênh phòng. Giới hạn tốc độ (ví dụ 5 tin trong 10 giây), lọc từ cấm, lưu 7 ngày |
| `store` | PostgreSQL, migration bằng `golang-migrate` |

## Lược đồ dữ liệu (rút gọn)

```sql
users(id uuid pk, nickname citext unique, email citext unique null, phone text unique null,
      password_hash text null, google_sub text unique null, platform text, created_at, banned_until)
sessions(id uuid pk, user_id fk, refresh_hash text, expires_at, revoked_at)
rooms(id uuid pk, game_id text default 'aoe-ror', host_id fk, name, ranked bool,
      password_hash null, max_players int, state text, created_at, ended_at)
room_members(room_id fk, user_id fk, joined_at, left_at, virtual_ip inet)
chat_messages(id bigserial, channel text, user_id fk, body text, created_at)
```

## API (rút gọn)

- `POST /auth/register`, `POST /auth/login`, `POST /auth/google`, `POST /auth/refresh`, `POST /auth/logout`
- `GET /me`, `PATCH /me`
- `GET /rooms`, `POST /rooms`, `POST /rooms/{id}/join`, `POST /rooms/{id}/leave`, `POST /rooms/{id}/start`
- WebSocket `/ws` với các sự kiện `presence`, `room.created`, `room.updated`, `room.closed`, `chat.message`

## Tiêu chí đạt

- [ ] Test tích hợp (Go `testing` và PostgreSQL thật trong Docker) cho đăng ký, đăng nhập, refresh token, đăng nhập Google (giả lập IdP)
- [ ] Vòng đời phòng đúng: chủ phòng rời thì phòng đóng, phòng đầy thì từ chối người mới, mật khẩu sai thì từ chối
- [ ] Tải thử 200 WebSocket đồng thời, mỗi kết nối 1 tin chat mỗi 10 giây: không mất tin nhắn, p95 phát tin dưới 200 ms
- [ ] Giới hạn tốc độ chat và đăng nhập có test

## File

- Mới: repo `hvngroup/aoe-online`: `server/cmd/aoe-online`, `server/internal/{auth,profile,lobby,rooms,chat,store}`, `server/migrations/`
- Mới: `deploy/docker-compose.yml` (server, postgres, caddy)

## Rủi ro

- Đăng nhập Google từ app desktop cần luồng loopback redirect và PKCE. Không nhúng client secret vào app.
