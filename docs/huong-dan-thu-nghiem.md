# Hướng dẫn thử nghiệm AoE RoR trên Mac (bản 0.4.0)

Tài liệu này dành cho đồng nghiệp thử bản chạy trên macOS của Đế Chế (Age of
Empires: The Rise of Rome, bản mod
[hvngroup/age_of_empires_ror_hd](https://github.com/hvngroup/age_of_empires_ror_hd)).
Bạn cần khoảng 20 phút để cài, chủ yếu là thời gian tải.

## 1. Yêu cầu

| Mục | Yêu cầu |
|-----|---------|
| Máy | Mac chip Apple (M1 trở lên) hoặc Mac Intel |
| macOS | 10.15 trở lên. Đã chạy tốt trên macOS 27.0.1, MacBook Pro M5 Max |
| Dung lượng trống | khoảng 2 GB |
| Mạng | Cần khi cài lần đầu (tải khoảng 750 MB) |

## 2. Tải và cài app

1. Tải file
   [AoE-RoR-0.4.0-macos.zip](https://github.com/hvngroup/mac-aoe/raw/claude/blissful-mayer-91sloi/releases/AoE-RoR-0.4.0-macos.zip).
2. Bấm đúp để giải nén, rồi kéo **AoE RoR.app** vào thư mục **Applications**.
3. Mở **AoE RoR** từ Applications. Lần đầu, macOS báo app không xác minh được
   nhà phát triển, vì đây là bản thử chưa ký bằng chứng chỉ Apple:
   - Mở **System Settings > Privacy & Security**, kéo xuống mục Security, bấm
     **Open Anyway** cạnh dòng nói về "AoE RoR", rồi xác nhận.
   - Trên macOS cũ hơn: chuột phải vào app, chọn **Open**, rồi chọn **Open**.

## 3. Cài game lần đầu

1. App hỏi *"Game chưa được cài trên máy này..."*. Bấm **Đồng ý**.
2. Nếu macOS hỏi cho phép "AoE RoR" điều khiển Terminal, bấm **OK**.
3. Một cửa sổ Terminal mở ra và tự chạy các bước sau:
   - Trên Mac chip Apple, hỏi cài Rosetta 2 nếu máy chưa có. Gõ `y` rồi Enter.
   - Tải Wine (khoảng 230 MB), game (khoảng 400 MB), cnc-ddraw và DirectPlay của
     Microsoft (khoảng 105 MB). Mỗi file đều được kiểm tra mã SHA-256.
   - Cài game với cấu hình đã chạy tốt trên Mac: chơi trong cửa sổ, vẽ bằng GDI,
     DirectPlay của Microsoft.
4. Khi Terminal báo **Hoàn tất**, đóng Terminal và mở lại app AoE RoR.

## 4. Chơi

Mở app, chọn **Chơi đơn** hoặc **Chơi mạng LAN**.

- Game chạy trong cửa sổ. Kéo góc cửa sổ để phóng to. Cửa sổ càng to thì máy
  càng phải phóng to hình nhiều hơn, nên dễ lag hơn trên màn hình lớn.
- Phím **Command trái** dùng như **Ctrl**. Ví dụ, `Command+1` gán nhóm quân số 1.
- Game treo: mở Terminal và chạy
  `"/Applications/AoE RoR.app/Contents/Resources/toolkit/aoe-mac" stop`.

### Chơi mạng LAN giữa các máy Mac

1. Tất cả các máy cùng một mạng Wi-Fi hoặc LAN.
2. Một máy vào Multiplayer, chọn **TCP/IP**, bấm **Create** để tạo phòng.
3. Nếu macOS hỏi cho phép `wine` nhận kết nối mạng, hoặc truy cập mạng cục bộ
   (Local Network), bấm **Cho phép**.
4. Các máy khác vào Multiplayer, chọn **TCP/IP**, bấm **Show Games**, rồi **Join**.
   Nếu không thấy phòng, nhập địa chỉ IP của máy tạo phòng. Xem IP trong
   **System Settings > Wi-Fi > Details**.

## 5. Những gì cần thử và báo lại

Đánh dấu từng mục, ghi lại mục nào lỗi:

- [ ] Cài đặt chạy xong, không báo lỗi
- [ ] Vào được menu chính, âm thanh và nhạc chạy
- [ ] Nhập tên người chơi: ô nhập hiển thị bình thường, không đen hay trắng
- [ ] Chơi một ván Random Map khoảng 15 phút: cuộn bản đồ, chọn quân, gán nhóm
      quân bằng `Command+số`
- [ ] Game có lag không? Lag lúc nào (cuộn bản đồ, nhiều quân, kéo chọn quân)?
- [ ] Bug reset ruộng (chọn nông dân và ruộng, bấm `S`) vẫn hoạt động
- [ ] Lưu game, thoát, mở lại bản lưu
- [ ] Tạo phòng chơi mạng (Create)
- [ ] Máy Mac khác vào phòng (Join), chơi hết một ván, chat trong trận
- [ ] Có người thoát giữa trận: những người còn lại có chơi tiếp được không

## 6. Gửi log khi gặp lỗi

Sau khi gặp lỗi và thoát game, mở Terminal, chạy lệnh dưới đây, rồi gửi toàn bộ
kết quả kèm ảnh chụp màn hình về **kythuat@hvn.vn**:

```bash
"/Applications/AoE RoR.app/Contents/Resources/toolkit/aoe-mac" logs
```

Ghi kèm các thông tin: dòng máy (ví dụ MacBook Air M2), phiên bản macOS, và màn
hình đang dùng (độ phân giải, tần số quét).

## 7. Giới hạn đã biết

- Chế độ toàn màn hình (`cnc`) lag trên màn hình lớn. Bản này mặc định chơi
  trong cửa sổ.
- Cách vẽ bằng GPU (`opengl`, `direct3d9`) làm đen hoặc trắng ô nhập liệu, nên
  bản này chỉ dùng GDI.
- Chưa thử chơi mạng giữa Mac và Windows.
- App chưa được ký bằng chứng chỉ Apple, nên lần mở đầu cần bước **Open Anyway**.

## 8. Gỡ cài đặt

```bash
"/Applications/AoE RoR.app/Contents/Resources/toolkit/aoe-mac" uninstall --all
```

Lệnh này xoá Wine, game và bản lưu trong
`~/Library/Application Support/AoE-Mac`. Sau đó xoá AoE RoR.app khỏi
Applications.

---

HVN GROUP · hvn.vn
