# Báo cáo: tạo phòng DirectPlay TCP/IP trong Wine (hướng B)

Status: prototype chạy được giữa Wine với Wine trên một máy Linux. Chưa thử trên
macOS, chưa thử với game, chưa thử với client Windows.

## Kết quả

Wine 11.21 sau khi vá đã tạo được phiên DirectPlay TCP/IP, trả lời yêu cầu tìm
phòng, cho máy khác vào phòng, gửi danh sách người chơi và chuyển tin nhắn hai
chiều. Test đạt với cả hai máy cùng vào một phòng.

| Cấu hình DLL | Tạo phòng | Tìm phòng | Vào phòng | Tin nhắn 2 chiều | 2 máy vào |
|--------------|-----------|-----------|-----------|------------------|-----------|
| 11.21 gốc | FAIL `0x80004001` (DPERR_UNSUPPORTED) | - | - | - | - |
| Chỉ vá dpwsockx | PASS | PASS | FAIL `0x887700f0` (DPERR_TIMEOUT sau 60 giây) | - | - |
| Vá cả dpwsockx và dplayx | PASS | PASS | PASS | PASS (TCP và UDP) | PASS |

Output đầy đủ nằm trong `results/`. Bản chạy lại độc lập (host và 2 máy vào
phòng) ra `RESULT: host OK (0 failures)` và `RESULT: joiner OK (0 failures)`
cho cả hai máy vào phòng.

## Thay đổi (`wine-dplay-host.patch`, 9 file, +854/-90)

**dpwsockx, `DPWSCB_Open` khi tạo phòng.** Mở cổng 47624 (UDP và TCP) để nhận
yêu cầu tìm phòng. Việc nhận dữ liệu chạy trên thread của dpwsockx qua
`QueueUserAPC`. UDP dùng `WSARecvFrom` để biết địa chỉ người gửi. Accept xử lý
được cả cổng 2300 lẫn 47624.

**dpwsockx, `DPWSCB_Reply`.** Gửi trả lời qua TCP về cổng mà bên yêu cầu khai
trong header, tại IP nguồn của gói (MC-DPL4CS 3.2.5.3). Sửa luôn chỗ rò bộ nhớ
buffer trả lời trong `dplaysp.c`.

**dplayx, phía máy chủ phòng.**

- `NS_ReplyToEnumSessionsRequest` được viết lại. Chỉ máy chủ phòng trả lời. Hàm
  kiểm tra GUID ứng dụng, các cờ AVAILABLE và JOINDISABLED, mật khẩu, và xử lý
  được mô tả phiên dạng ANSI lẫn Unicode.
- Hàm mới `DP_HandleAddForwardRequest`. Hàm tạo system player cho máy vừa vào,
  gửi ADDFORWARD cho các máy khác, rồi trả SUPERENUMPLAYERSREPLY chứa đủ người
  chơi, SP data và nhóm. Nếu lỗi, hàm trả FORWARDADDPLAYERNACK.
- Sửa một lỗi có sẵn: system player của máy chủ phòng mang cờ `APPSERVER` thay
  cho `SYSPLAYER|NAMESRVR`.

**Tin nhắn trong trận.** Đường `SendEx`/`SendToGroupEx` sẵn có đã đủ, không cần
viết thêm.

## Build

```sh
apt-get install -y gcc-mingw-w64-i686 gcc-mingw-w64-x86-64 flex bison
git clone --depth 1 --branch wine-11.21 https://gitlab.winehq.org/wine/wine.git wine
cd wine && git apply ../wine-dplay-host.patch && cd ..
mkdir obj && cd obj
../wine/configure --enable-archs=i386,x86_64 --without-x --without-freetype \
  --without-wayland --without-gstreamer --without-pulse --without-alsa ...
make -j4 __tooldeps__
make -j4 dlls/dpwsockx/i386-windows/dpwsockx.dll dlls/dplayx/i386-windows/dplayx.dll
```

Danh sách đầy đủ các cờ `--without-*` nằm trong báo cáo gốc của agent. Bản build
i386 PE nằm trong `bin/`, có `SHA256SUMS`.

## Chạy test

```sh
WINEPREFIX=/path/to/prefix xvfb-run -a bash tests/run-host-join-test.sh bin <out-dir> 2
```

Script build `dphost.exe`/`dpjoin.exe` bằng mingw, chép hai DLL vào cạnh file exe,
xoá dấu "Wine builtin DLL" ở offset 0x40 (nếu không, Wine thay chúng bằng bản
builtin của hệ thống), rồi chạy với `WINEDLLOVERRIDES="dpwsockx,dplayx=n,b"`.

## Hạn chế và rủi ro

1. **Chưa thử với DirectPlay của Windows.** ID người chơi do Wine cấp là số tăng
   dần từ 1000, còn DirectPlay của Microsoft cấp ID theo dạng index XOR khoá và có
   thể kiểm tra dạng ID đó. Ngoài ra máy chủ phòng trả danh sách người chơi ngay
   mà không chờ ADDFORWARDACK như spec quy định.
2. **`connect()` để trả lời chạy đồng bộ trên thread nhận.** Nếu máy vào phòng
   nằm sau NAT hoặc tường lửa, thread treo đến khi TCP hết thời gian chờ.
3. **Còn nhiều FIXME có sẵn trong dplayx.** DestroyPlayer/Close, SetPlayerName/
   Data và SetSessionDesc chưa được gửi qua mạng. Chat là stub. Chưa có keepalive
   và chưa có cơ chế chuyển máy chủ phòng. `DPSEND_ASYNC` trả UNSUPPORTED. Các
   chỗ này có thể làm hỏng phòng chờ hoặc lúc có người rời trận.
4. **Máy vào phòng của Wine luôn broadcast** và bỏ qua IP người dùng nhập.
5. **Chưa chạy trên macOS và chưa chạy với AoE.**
6. Mỗi máy chỉ tạo được một phòng, vì cổng 47624 chỉ bind được một lần.

## So với hướng A

Hướng A (`aoe-mac directplay microsoft`, dùng DirectPlay 5.3 của Microsoft) đã
tạo được phòng trong AoE trên MacBook Pro M5 Max, macOS 27.0.1. Hướng B chỉ cần
thiết khi muốn bỏ phụ thuộc vào file của Microsoft hoặc đóng góp ngược cho Wine.

## Bước tiếp theo

| Việc | Công sức ước lượng |
|------|--------------------|
| Thử AoE trên Mac với bộ DLL đã vá (`WINEDEBUG=+dplay`) | 0,5-1 ngày |
| Gửi DestroyPlayer/Close, SetPlayerData/Name, SetSessionDesc qua mạng; chat | 2-4 ngày |
| Keepalive, xử lý mất kết nối | 1-2 ngày |
| Đưa `connect()`/gửi trả lời ra khỏi thread nhận | 1-2 ngày |
| Tương thích client Windows (ID kiểu DirectPlay, chờ ACK, bắt gói đối chiếu) | 3-5 ngày, cần máy Windows |
| Máy vào phòng gửi EnumSessions unicast tới IP | 0,5-1 ngày |
| Test conformance trong `dlls/dplayx/tests`, chia patch để gửi upstream | 3-5 ngày |

---

HVN GROUP · hvn.vn
