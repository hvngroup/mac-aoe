# Thử nghiệm chơi online HVN AOE (phase 1)

Tài liệu này hướng dẫn chạy phase 1 của kế hoạch
[HVN AOE](../plans/261103-1026-aoe-online-platform/plan.md). Phase 1 kiểm tra ba
câu hỏi trước khi xây sản phẩm:

1. AoE có chơi ổn qua mạng ảo WireGuard giữa Mac và Windows không?
2. `aoelobby.exe` có mở game vào thẳng phòng không?
3. Game có báo kết quả trận cho lobby không?

Công cụ nằm trong `online/spike/` của repo này.

| Công cụ | Việc | Đã kiểm tra |
|---------|------|-------------|
| `hub/setup-hub.sh` | Dựng hub WireGuard trên VPS, kể cả VPS có Coolify/Docker | Test 26/26 trong network namespace Linux (`hub/test-hub.sh`), cả máy thường lẫn máy mô phỏng tường lửa Docker |
| `hub/add-peer.sh`, `remove-peer.sh` | Cấp hoặc gỡ cấu hình cho người thử | Như trên |
| `aoelobby/bin/aoelobby.exe` | Mở game vào phòng qua DirectPlay Lobby | Test 14/14 trên Wine với chương trình giả lập game (`aoelobby/run-lobby-test.sh`). Chưa thử với game thật |

## 1. Dựng hub trên VPS (quản trị, khoảng 10 phút)

### Yêu cầu VPS

| Mục | Yêu cầu |
|-----|---------|
| Hệ điều hành | Ubuntu 22.04 hoặc 24.04 (cùng loại Coolify hỗ trợ). Kernel đã có sẵn WireGuard |
| Cấu hình | Hub gần như không tốn tài nguyên. Để chạy chung Coolify và backend ở các phase sau: 2 vCPU, 4 GB RAM, 40 GB SSD |
| Mạng | IPv4 công khai. Mở cổng **51820/UDP** trên tường lửa của nhà cung cấp VPS |
| Quyền | Tài khoản root hoặc sudo qua SSH |
| DNS | Bản ghi A `aoe.hvn.works` trỏ về IP của VPS. Nếu DNS ở Cloudflare, để chế độ **DNS only** (mây xám): proxy của Cloudflare không chuyển tiếp UDP 51820 |

### VPS đã cài Coolify

Dùng được. Coolify chiếm các cổng 22, 80, 443, 8000, 6001, 6002; hub dùng
51820/UDP nên không trùng. Coolify cài Docker, mà Docker đặt chính sách mặc
định của chuỗi `FORWARD` (iptables) là chặn mọi gói chuyển tiếp. `setup-hub.sh`
tự thêm một luật cho phép chuyển tiếp từ `wg0` sang `wg0`, và cho hub khởi động
sau Docker. Việc chặn cổng vẫn do bảng nftables của hub đảm nhận. Hub chạy
thẳng trên máy chủ, không chạy trong Coolify. Đã kiểm tra bằng
`AOE_TEST_DOCKER=1 test-hub.sh`, mô phỏng tường lửa của Docker: 26/26.

### Cài đặt

```bash
git clone https://github.com/hvngroup/mac-aoe.git && cd mac-aoe/online/spike/hub
```
```bash
sudo ./setup-hub.sh
```

Thêm từng người thử. Tên chỉ gồm chữ thường, số và dấu gạch ngang:

```bash
sudo ./add-peer.sh dong-mac
```

Lệnh lưu cấu hình WireGuard ở `/etc/wireguard/peers/<tên>.conf` (chỉ root đọc
được) và chỉ in đường dẫn, không in khoá ra màn hình. Người thử thứ nhất nhận IP
`10.77.0.11`, người thứ hai `10.77.0.12`, và cứ thế tăng dần. Cấu hình có khoá
riêng (`PrivateKey`) và khoá chia sẻ (`PresharedKey`) của người thử, nên **gửi
riêng cho từng người** qua 1Password hoặc một file Drive chỉ chia sẻ cho người
đó. Không gửi qua chat, không dán vào ticket.

Lấy file về máy quản trị (chạy trên máy của bạn, không phải trên VPS):

```bash
ssh root@aoe.hvn.works cat /etc/wireguard/peers/dong-mac.conf > dong-mac.conf
```

Cần xem nội dung ngay trên VPS thì thêm `--print`: `sudo ./add-peer.sh dong-mac --print`.

Nếu khoá đã lộ (ví dụ lỡ dán vào chat), cấp lại khoá mới cho người đó:

```bash
sudo ./remove-peer.sh dong-mac && sudo ./add-peer.sh dong-mac
```

### Kiểm tra hub

```bash
sudo wg show wg0
```
```bash
sudo nft list table inet aoe_hub && sudo iptables -S FORWARD | grep wg0
```

Kết quả đúng: `wg show` liệt kê các peer; bảng `aoe_hub` có các luật cho cổng
`2300-2400` và `47624`; `iptables` có dòng `-A FORWARD -i wg0 -o wg0 -j ACCEPT`
(hoặc `-I`). Khi người thử đã kết nối, dòng `latest handshake` của họ hiện thời
gian gần nhất.

Gỡ người thử: `sudo ./remove-peer.sh dong-mac`.

Hub chỉ cho các người chơi nói chuyện với nhau qua cổng DirectPlay (TCP/UDP
2300–2400 và 47624) và ping. Mọi cổng khác bị chặn, và người chơi không dùng
được hub để ra Internet.

## 2. Cài trên máy người thử

**Mac:** cài app WireGuard từ Mac App Store, chọn **Import Tunnel(s) from File**,
chọn file `.conf`, rồi bấm **Activate**. Game cài theo
[hướng dẫn thử nghiệm](huong-dan-thu-nghiem.md) (bản 0.4.0 trở lên đã bật sẵn
`directplay microsoft`).

**Windows:** cài WireGuard từ <https://www.wireguard.com/install/>, chọn
**Import tunnel(s) from file**, rồi bấm **Activate**. Cài game từ repo
`hvngroup/age_of_empires_ror_hd` và chạy `SETUP.EXE` một lần.

Kiểm tra: mở Terminal (Mac) hoặc Command Prompt (Windows) và chạy
`ping 10.77.0.1`. Có trả lời là đã vào mạng ảo.

## 3. Thử A: chơi bằng IP gõ tay

1. Người A (ví dụ `10.77.0.11`) mở game, vào Multiplayer, chọn TCP/IP, bấm **Create**.
2. Người B mở game, vào Multiplayer, chọn TCP/IP, nhập IP `10.77.0.11` khi được hỏi, rồi **Join**.
3. Chơi ít nhất 20 phút. Ghi lại độ trễ (`ping 10.77.0.11`), lag và lỗi mất đồng bộ.

Lặp lại với các cặp Mac và Mac, Mac và Windows, Windows và Windows, rồi một ván 4 người.

## 4. Thử B: vào thẳng phòng bằng `aoelobby`

Chủ phòng và người vào phòng dùng **cùng một GUID phiên**. Tạo một GUID mới cho
mỗi lần thử: chạy `uuidgen` trên Mac, hoặc `[guid]::NewGuid()` trong PowerShell.
Viết GUID trong dấu ngoặc nhọn, ví dụ `{D1E2F3A4-B5C6-4D7E-8F90-A1B2C3D4E5F6}`.

**Mac** (từ thư mục `mac-aoe` đã clone, sau `git pull`):

```bash
~/mac-aoe/aoe-mac lobby host --name DongMac --session "Phong thu" --session-guid "{GUID}" --wait 3600
```
```bash
~/mac-aoe/aoe-mac lobby join --name DongMac --host 10.77.0.12 --session-guid "{GUID}" --wait 3600
```

**Windows** (Command Prompt, trong thư mục chứa `aoelobby.exe` tải từ
`online/spike/aoelobby/bin/`):

```bat
aoelobby.exe host --name DongWin --session "Phong thu" --session-guid "{GUID}" --wait 3600
```
```bat
aoelobby.exe join --name DongWin --host 10.77.0.11 --session-guid "{GUID}" --wait 3600
```

Chủ phòng chạy `host` trước. Khi game của chủ phòng đã vào phòng chờ, người kia
chạy `join`. Kết quả mong đợi: game tự mở và vào thẳng phòng chờ, không phải
chọn TCP/IP hay gõ IP.

## 5. Thử C: game có báo kết quả cho lobby không

Ở thử B, `--wait 3600` giữ `aoelobby` chạy suốt ván và in mọi tin nhắn game gửi
về, mỗi tin một dòng JSON. Chơi đến hết ván (có người thắng), thoát game, rồi
chép toàn bộ những dòng `aoelobby` đã in, đặc biệt các dòng `app_message` và
`system_message`.

- Có dòng `app_message` chứa kết quả: ELO sẽ tự tính từ tin nhắn này.
- Không có: ELO sẽ dựa vào việc hai bên cùng xác nhận kết quả trong app.

## 6. Ghi kết quả

Với mỗi lần thử, ghi lại:

| Mục | Ghi |
|-----|-----|
| Cặp máy | ví dụ MacBook Pro M5 Max (macOS 27.0.1) và PC Windows 11 |
| Mạng | ví dụ Wi-Fi văn phòng Hà Nội và cáp quang nhà TP.HCM |
| Ping qua hub | ví dụ 32 ms |
| Thử A | vào phòng được không, chơi hết ván không, lag hay mất đồng bộ |
| Thử B | game có tự vào phòng không, mất bao lâu |
| Thử C | các dòng JSON `aoelobby` in ra |
| Log | Mac: `~/mac-aoe/aoe-mac logs`; log lobby nằm trong `~/Library/Application Support/AoE-Mac/logs/lobby-*.log` |

Gửi kết quả về kythuat@hvn.vn. Kết quả sẽ được tổng hợp vào
`plans/261103-1026-aoe-online-platform/reports/phase-01-spike-results.md`.

## Chạy lại các test tự động

```bash
sudo online/spike/hub/test-hub.sh
```
```bash
sudo AOE_TEST_DOCKER=1 online/spike/hub/test-hub.sh
```
```bash
xvfb-run -a online/spike/aoelobby/run-lobby-test.sh
```

Test hub cần root, `iproute2`, `wireguard-tools`, `nftables`, `netcat-openbsd`, và
module WireGuard trong kernel hoặc `wireguard-go`. Test lobby cần `wine` và
`i686-w64-mingw32-gcc`.

---

HVN GROUP · hvn.vn
