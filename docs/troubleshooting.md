# Xử lý sự cố

Luôn chạy `aoe-mac doctor` trước. Lệnh này chỉ ra mục nào còn thiếu. Log của
10 lần chơi gần nhất nằm ở `~/Library/Application Support/AoE-Mac/logs/`.
`aoe-mac logs` in 200 dòng cuối của lần chơi gần nhất, gồm thông tin máy, bản
Wine, lệnh đã chạy, các lỗi Wine báo ra và mã thoát của game. Khi gửi yêu cầu
hỗ trợ, hãy dán toàn bộ nội dung này.

Để có log chi tiết hơn nữa, chạy:

```bash
WINEDEBUG=err+all,fixme-all ~/mac-aoe/aoe-mac play
```

## Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|------------|-----------|
| `Rosetta 2: THIẾU` trên máy M1–M4 | `softwareupdate --install-rosetta --agree-to-license` |
| macOS báo "không thể mở vì không xác minh được nhà phát triển" khi mở `AoE RoR.app` | Chuột phải vào app, chọn **Mở**, rồi chọn **Mở** lần nữa. Chỉ cần làm một lần |
| `git clone thất bại` | Repo game có thể đang private. Đăng nhập GitHub bằng `gh auth login` hoặc cấu hình SSH key, rồi chạy lại `aoe-mac install` |
| Game thoát với mã 1 sau vài giây, log có `nested exception on signal stack` | `aoe-mac display cnc` rồi chơi lại. Chế độ này tắt `wndmode.dll` (thư viện hook DirectDraw của game, xung đột với Wine qua Rosetta) và bỏ qua video mở đầu |
| Vào được màn hình chính, bấm menu thì màn hình đen | Máy Mac chip Apple không còn các độ phân giải thấp mà game xin đổi. Dùng `aoe-mac display cnc` (cnc-ddraw phóng to hình vào màn hình, không đổi độ phân giải thật) |
| Ô nhập tên hoặc chat làm màn hình chuyển trắng | `aoe-mac renderer gdi` (mặc định từ 0.2.1). Driver Mac của Wine không vẽ được ô nhập liệu đè lên hình OpenGL |
| "Unable to create game. For TCP/IP games..." | `aoe-mac directplay native`, rồi thử lại. Nếu vẫn lỗi, gửi log mạng (xem mục Chơi mạng LAN) |
| Màn hình đen hoặc màu sai | Thử lần lượt `aoe-mac display cnc`, `cnc-window`, rồi `native` |
| Hình bị mờ hoặc muốn đổi bộ lọc | Sửa dòng `shader=` trong `drive_c/Games/AoE/ddraw.ini` (`Nearest neighbor`, `Bilinear`, `Lanczos`). Lưu ý `aoe-mac display`/`update` ghi lại file này |
| Không có tiếng | Chạy `aoe-mac winecfg`, mở tab **Audio** và chọn thiết bị ra |
| Phím `Ctrl+số` không gán nhóm quân | Dùng **Command trái** + số. Phím Ctrl thật vẫn dùng được nếu macOS không chiếm tổ hợp đó |
| Terminal đứng ở "Khởi động empires.exe" mà không thấy cửa sổ game, hoặc game treo | Bình thường Terminal chờ đến khi thoát game. Nếu treo: nhấn Ctrl+C, hoặc chạy `aoe-mac stop` ở tab khác. Nếu vừa bật `directplay native`, chạy `aoe-mac directplay wine` rồi thử lại |
| Muốn cài lại từ đầu | `aoe-mac uninstall`, rồi `aoe-mac install`. Lưu ý bước gỡ cũng xoá bản lưu |

## Chơi mạng LAN

`EMPIRESX.EXE` dùng DirectPlay qua TCP/IP. Wine có DirectPlay riêng, nên chơi
mạng giữa các máy Mac cùng chạy `mac-aoe` có thể hoạt động. Chơi chéo với máy
Windows chưa được kiểm chứng. Nếu gặp lỗi:

1. Cho phép Wine nhận kết nối khi macOS hỏi về tường lửa.
2. Thử DirectPlay của Microsoft đi kèm game thay cho bản của Wine:
   `aoe-mac directplay native` (quay lại bằng `aoe-mac directplay wine`).
3. Lấy log mạng chi tiết rồi gửi bộ phận kỹ thuật:
   `WINEDEBUG=err+all,+dplay,+winsock aoe-mac play multi`, sau đó `aoe-mac logs`.

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
