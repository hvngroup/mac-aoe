# Xử lý sự cố

Luôn chạy `aoe-mac doctor` trước. Lệnh này chỉ ra mục nào còn thiếu. Log của
10 lần chơi gần nhất nằm ở `~/Library/Application Support/AoE-Mac/logs/`.

Để có log chi tiết hơn, chạy:

```bash
WINEDEBUG=err+all,fixme-all ~/mac-aoe/aoe-mac play
```

## Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|------------|-----------|
| `Rosetta 2: THIẾU` trên máy M1–M4 | `softwareupdate --install-rosetta --agree-to-license` |
| macOS báo "không thể mở vì không xác minh được nhà phát triển" khi mở `AoE RoR.app` | Chuột phải vào app, chọn **Mở**, rồi chọn **Mở** lần nữa. Chỉ cần làm một lần |
| `git clone thất bại` | Repo game có thể đang private. Đăng nhập GitHub bằng `gh auth login` hoặc cấu hình SSH key, rồi chạy lại `aoe-mac install` |
| Màn hình đen hoặc màu sai | Đổi chế độ hiển thị: `aoe-mac display fullscreen`, hoặc ngược lại `windowed` |
| Cửa sổ quá nhỏ trên màn hình Retina | Dùng `aoe-mac display fullscreen`. macOS sẽ phóng to độ phân giải của game |
| Không có tiếng | Chạy `aoe-mac winecfg`, mở tab **Audio** và chọn thiết bị ra |
| Phím `Ctrl+số` không gán nhóm quân | Dùng **Command trái** + số. Phím Ctrl thật vẫn dùng được nếu macOS không chiếm tổ hợp đó |
| Game treo khi thoát | Đóng hết tiến trình Wine của game: `WINEPREFIX="$HOME/Library/Application Support/AoE-Mac/prefix" "$HOME/Library/Application Support/AoE-Mac/wine/Wine Staging.app/Contents/Resources/wine/bin/wineserver" -k` |
| Muốn cài lại từ đầu | `aoe-mac uninstall`, rồi `aoe-mac install`. Lưu ý bước gỡ cũng xoá bản lưu |

## Chơi mạng LAN

`EMPIRESX.EXE` dùng DirectPlay qua TCP/IP. Wine có DirectPlay riêng, nên chơi
mạng giữa các máy Mac cùng chạy `mac-aoe` có thể hoạt động. Chơi chéo với máy
Windows chưa được kiểm chứng. Nếu gặp lỗi:

1. Cho phép Wine nhận kết nối khi macOS hỏi về tường lửa.
2. Thử chạy với file `dplayx.dll` đi kèm game thay cho bản của Wine:
   `WINEDLLOVERRIDES="dplayx=n,b" aoe-mac play multi`
3. Gửi log trong `logs/` cho bộ phận kỹ thuật.

## Kiểm thử chấp nhận (UAT) trên máy Mac thật

Bộ công cụ đã được kiểm tra tự động: cài đặt, registry, đổi bản cân bằng, cập
nhật và tạo app. Phần chạy game trên Mac thật cần người kiểm tra:

- [ ] Intel Mac: `aoe-mac setup` chạy xong, `aoe-mac doctor` báo sẵn sàng
- [ ] Apple Silicon: như trên, có bước cài Rosetta
- [ ] Mở `AoE RoR.app`, vào được menu chính của game
- [ ] Chơi một ván Random Map 15 phút: âm thanh, cuộn bản đồ, chọn nhóm quân
- [ ] Bug reset ruộng (`S`) vẫn hoạt động
- [ ] Đổi bản cân bằng `de`, vào game và thấy chỉ số đã đổi
- [ ] Chơi LAN giữa 2 máy Mac
- [ ] Lưu game, `aoe-mac update`, mở lại bản lưu

Gửi kết quả và log về kythuat@hvn.vn.

---

HVN GROUP · hvn.vn
