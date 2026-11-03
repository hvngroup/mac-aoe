# Xử lý sự cố

Luôn chạy `aoe-mac doctor` trước. Lệnh này chỉ ra mục nào còn thiếu. Log của
10 lần chơi gần nhất nằm ở `~/Library/Application Support/AoE-Mac/logs/`.
`aoe-mac logs` in 200 dòng cuối của lần chơi gần nhất, gồm thông tin máy, bản
Wine, lệnh đã chạy, các lỗi Wine báo ra và mã thoát của game. Khi gửi yêu cầu
hỗ trợ, hãy dán toàn bộ nội dung này.

Để có log chi tiết hơn nữa, chạy:

```bash
WINEDEBUG=err+all,fixme-all,+loaddll,+seh ~/mac-aoe/aoe-mac play
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
| "Unable to create game. For TCP/IP games..." | DirectPlay của Wine chưa hỗ trợ tạo phòng (log có `DP_SecureOpen Unable to open session: DPERR_UNSUPPORTED`). Thử `aoe-mac directplay microsoft`. Xem mục Chơi mạng LAN |
| Màn hình đen hoặc màu sai | Thử lần lượt `aoe-mac display cnc`, `cnc-window`, rồi `native` |
| Hình bị mờ hoặc muốn đổi bộ lọc | Sửa dòng `shader=` trong `drive_c/Games/AoE/ddraw.ini` (`Nearest neighbor`, `Bilinear`, `Lanczos`). Lưu ý `aoe-mac display`/`update` ghi lại file này |
| Không có tiếng | Chạy `aoe-mac winecfg`, mở tab **Audio** và chọn thiết bị ra |
| Phím `Ctrl+số` không gán nhóm quân | Dùng **Command trái** + số. Phím Ctrl thật vẫn dùng được nếu macOS không chiếm tổ hợp đó |
| Terminal đứng ở "Khởi động empires.exe" mà không thấy cửa sổ game, hoặc game treo | Bình thường Terminal chờ đến khi thoát game. Nếu treo: nhấn Ctrl+C, hoặc chạy `aoe-mac stop` ở tab khác. Nếu vừa bật `directplay native`, chạy `aoe-mac directplay wine` rồi thử lại |
| Muốn cài lại từ đầu | `aoe-mac uninstall`, rồi `aoe-mac install`. Lưu ý bước gỡ cũng xoá bản lưu |

## Chơi mạng LAN

`EMPIRESX.EXE` (và mục Multiplayer của `empires.exe`) dùng DirectPlay qua TCP/IP.
Có hai lựa chọn:

| `aoe-mac directplay` | Vào phòng (Join) | Tạo phòng (Create) | Ghi chú |
|----------------------|------------------|--------------------|---------|
| `wine` (mặc định) | Được | Chưa được | Wine trả về `session creation is not yet supported` (mã nguồn `dlls/dpwsockx/dpwsockx_main.c`, Wine 11.21 và master) |
| `microsoft` | Đang thử nghiệm | Đang thử nghiệm | Bộ DirectPlay 5.3 đầy đủ của Microsoft, lấy từ gói DirectX tháng 2/2010 (cách winetricks làm) |

`aoe-mac directplay microsoft` làm các việc sau:

1. Tải gói DirectX của Microsoft (khoảng 105 MB) từ bản lưu trên archive.org hoặc
   mirror của winetricks, kiểm tra SHA-256 `f6d191e8…a1e93f`.
2. Tách `dplayx.dll`, `dpwsockx.dll`, `dpmodemx.dll`, `dplaysvr.exe` bằng `tar` có
   sẵn của macOS, đặt vào `C:\windows\syswow64` của prefix, rồi xoá gói đã tải.
3. Tắt `dplayx.dll` bản XP đi kèm game (đổi tên), vì Windows tìm DLL trong thư mục
   game trước. Bản này đi lẻ, không có `dpwsockx.dll` cùng phiên bản, và đã làm
   game treo lúc khởi động.
4. Khi chơi, ưu tiên bộ DLL của Microsoft thay cho bản của Wine.

Quay lại bằng `aoe-mac directplay wine`.

Nếu vào hoặc tạo phòng không được:

1. Cho phép `wine` nhận kết nối mạng khi macOS hỏi, và cho phép truy cập mạng cục
   bộ trong **System Settings > Privacy & Security > Local Network**.
2. Lấy log mạng chi tiết rồi gửi bộ phận kỹ thuật:
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
- [ ] Máy Mac vào phòng do máy Windows tạo (LAN)
- [ ] `directplay microsoft`: máy Mac tạo phòng, máy Mac khác vào phòng
- [ ] Lưu game, `aoe-mac update`, mở lại bản lưu

Gửi kết quả và log về kythuat@hvn.vn.

---

HVN GROUP · hvn.vn
