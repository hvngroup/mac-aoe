# Plan: Chạy AoE RoR HD trên macOS

Status: done (v0.1)

## Outcome

Người dùng macOS (Intel hoặc Apple Silicon) cài và chơi bản mod
`hvngroup/age_of_empires_ror_hd` bằng một ứng dụng `.app` bấm đúp,
không cần Windows, không cần máy ảo.

## Approach

Không viết lại engine. Bộ công cụ bash `aoe-mac` đóng gói game gốc vào một
Wine prefix riêng:

1. Tải Wine Staging (bản build macOS của Gcenx, có WoW64 để chạy app 32-bit),
   kiểm tra SHA-256.
2. Lấy game từ repo nguồn (git clone hoặc thư mục có sẵn), chép vào
   `C:\Games\AoE` trong prefix.
3. Ghi registry giống `data/setupreg.exe` (khoá phân tích tĩnh từ file đó).
4. Thêm tuỳ chỉnh Mac: Command trái = Ctrl, tắt Retina mode.
5. Tạo `AoE RoR.app` gói sẵn bộ công cụ, menu chọn chơi đơn / chơi mạng /
   đổi bản cân bằng / đổi chế độ hiển thị.

## Constraints

- Không commit file nhị phân hay tài sản game vào repo này.
- Tương thích bash 3.2 (bash mặc định của macOS), sed/date bản BSD.
- Không gỡ quarantine, không tắt Gatekeeper.

## Non-goals

- Viết lại engine, làm lại đồ hoạ hay âm thanh.
- Phân phối game kèm bộ cài.

## Acceptance

- `shellcheck` sạch; `tests/run-tests.sh` pass trên Linux và macOS (CI).
- Registry import được bằng Wine thật, game đọc được khoá ở view 32-bit.
- `build-app` tạo bundle hợp lệ (Info.plist, launcher thực thi được,
  toolkit được nhúng).

## Known gaps

- Chưa chạy thử game trên máy Mac thật; cần một vòng UAT trên Intel và
  Apple Silicon (xem docs/troubleshooting.md).
