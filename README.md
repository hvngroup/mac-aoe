# mac-aoe — Chơi Đế Chế (AoE: The Rise of Rome) trên macOS

`mac-aoe` giúp bạn chơi bản mod
[hvngroup/age_of_empires_ror_hd](https://github.com/hvngroup/age_of_empires_ror_hd)
trên máy Mac (Intel hoặc Apple Silicon). Bạn không cần cài Windows, Boot Camp
hay máy ảo. Bộ công cụ không viết lại game. Nó chạy chính bản game gốc qua
[Wine](https://www.winehq.org/) và đóng gói thành ứng dụng `AoE RoR.app` để mở
bằng một cú bấm đúp.

Bạn giữ nguyên mọi thứ của bản mod: bug reset ruộng, AI cải tiến, 3 bản cân bằng
(Rise of Rome 1.0, Definitive Edition, Macedonian siêu mạnh) và chế độ chơi mạng
bằng `EMPIRESX.EXE`.

## Yêu cầu

| Mục | Yêu cầu |
|-----|---------|
| macOS | 10.15 Catalina trở lên |
| Chip | Intel, hoặc Apple Silicon (M1–M4) có Rosetta 2 (bộ cài tự đề nghị cài) |
| Dung lượng trống | khoảng 1,5 GB (Wine 650 MB, game 400 MB, bộ nhớ đệm) |
| Mạng | Cần khi cài lần đầu để tải Wine và game |
| git | Nên có (`xcode-select --install`). Nếu thiếu, bộ cài tải bản zip khi repo để public |

## Bản thử nghiệm

Tải app đóng gói sẵn và làm theo [hướng dẫn thử nghiệm](docs/huong-dan-thu-nghiem.md).
Không cần dùng Terminal để cài.

## Cài đặt nhanh

Mở Terminal rồi chạy:

```bash
git clone https://github.com/hvngroup/mac-aoe.git ~/mac-aoe
```

```bash
~/mac-aoe/aoe-mac setup
```

```bash
~/mac-aoe/aoe-mac build-app
```

Lệnh `setup` làm 4 việc:

1. Tải Wine Staging 11.21 cho macOS và kiểm tra mã SHA-256.
2. Tải game từ repo `hvngroup/age_of_empires_ror_hd`.
3. Tạo một Wine prefix riêng và chép game vào `C:\Games\AoE`.
4. Ghi registry mà game cần, thay cho việc chạy `SETUP.EXE`.

Lệnh `build-app` tạo `~/Applications/AoE RoR.app`. Bạn mở app từ Finder hoặc
Launchpad, rồi chọn **Chơi đơn**, **Chơi mạng LAN**, **Đổi bản cân bằng** hoặc
**Đổi chế độ hiển thị**.

> Nếu bạn đã có sẵn thư mục game (ví dụ đã clone repo game), cài từ thư mục đó
> để khỏi tải lại: `~/mac-aoe/aoe-mac install --source ~/age_of_empires_ror_hd`

## Các lệnh

| Lệnh | Tác dụng |
|------|----------|
| `aoe-mac setup` | Cài Wine (nếu chưa có) và game |
| `aoe-mac play` | Chơi đơn (`empires.exe`, có cheat, dân số tối đa 1000) |
| `aoe-mac play multi` | Chơi mạng (`EMPIRESX.EXE`, chống cheat). Mặc định vào được phòng do máy khác tạo, chưa tạo được phòng |
| `aoe-mac directplay microsoft` | Dùng bộ DirectPlay đầy đủ của Microsoft để **tạo phòng** trên Mac (`wine` để quay lại). Xem [Chơi mạng LAN](docs/troubleshooting.md#chơi-mạng-lan) |
| `aoe-mac balance de` | Đổi bản cân bằng: `ror`, `de`, `mace`, `original` |
| `aoe-mac balance` | Xem bản cân bằng đang dùng |
| `aoe-mac display cnc` | Toàn màn hình qua cnc-ddraw, mặc định trên Mac. `cnc-window` để chơi trong cửa sổ |
| `aoe-mac display native` | DirectDraw của Wine, đổi độ phân giải thật. `windowed`/`fullscreen` dùng `wndmode.dll` của game |
| `aoe-mac renderer opengl` | Đổi cách cnc-ddraw vẽ hình (mặc định `gdi`, cần cho ô nhập tên và chat) |
| `aoe-mac cursor system` | Dùng con trỏ chuột của macOS (mượt hơn khi game giật). `game` để quay lại con trỏ của game |
| `aoe-mac tweak fixchilds=1` | Chỉnh trực tiếp tuỳ chọn của cnc-ddraw để thử nghiệm. `aoe-mac tweak` xem danh sách, `--reset` để xoá |
| `aoe-mac update` | Lấy bản mới của game. Bản lưu và tuỳ chọn được giữ nguyên |
| `aoe-mac doctor` | Kiểm tra môi trường khi gặp lỗi |
| `aoe-mac stop` | Dừng game bị treo (hoặc nhấn Ctrl+C trong Terminal đang chạy game) |
| `aoe-mac winecfg` | Mở cấu hình Wine (âm thanh, đồ hoạ) |
| `aoe-mac uninstall` | Gỡ game. Thêm `--all` để gỡ cả Wine |

## Phím tắt trên Mac

- Phím **Command trái** hoạt động như **Ctrl**. Ví dụ, `Command+1` gán nhóm quân
  số 1, giống `Ctrl+1` trên Windows.
- Bug reset ruộng vẫn dùng như cũ: chọn cùng lúc nông dân và ruộng, rồi bấm `S`.
- Ảnh chụp màn hình trong game nằm ở
  `~/Library/Application Support/AoE-Mac/prefix/drive_c/Games/AoE/Screenshot`.

## Dữ liệu nằm ở đâu

Mọi dữ liệu nằm trong `~/Library/Application Support/AoE-Mac/`:

| Thư mục | Nội dung |
|---------|----------|
| `wine/` | Bản Wine riêng của bộ công cụ, không ảnh hưởng Wine khác trên máy |
| `prefix/drive_c/Games/AoE/` | Game, bản lưu (`savegame/`), kịch bản (`scenario/`) |
| `cache/` | Mã nguồn game và file Wine đã tải |
| `logs/` | Log 10 lần chơi gần nhất |
| `config` | Tuỳ chọn: nguồn game, bản cân bằng, chế độ hiển thị |

Đặt biến `AOE_HOME` để dùng thư mục khác.

## Tài liệu thêm

- [Kiến trúc và cách hoạt động](docs/architecture.md)
- [Xử lý sự cố](docs/troubleshooting.md)
- [Hướng dẫn thử nghiệm cho đồng nghiệp](docs/huong-dan-thu-nghiem.md)

## Phát triển

```bash
bash tests/run-tests.sh
```

Bộ test dùng một Wine giả lập nên chạy được trên cả macOS lẫn Linux. Đặt
`AOE_TEST_REAL_WINE=1` để chạy thêm bước cài đặt với Wine thật. CI chạy
shellcheck, test trên macOS bằng bash 3.2 (bash mặc định của macOS) và test với
Wine thật trên Linux.

## Bản quyền

Repo này chỉ chứa script. Khi cài, bộ công cụ tải thêm Wine (LGPL) và
[cnc-ddraw](https://github.com/FunkyFr3sh/cnc-ddraw) (MIT), cả hai đều được ghim
phiên bản và kiểm tra SHA-256. Age of Empires là tài sản của Microsoft. Bộ công cụ
không kèm file game; nó lấy game từ nguồn bạn chỉ định, và bạn chịu trách nhiệm
về quyền sử dụng bản game đó.

---

HVN GROUP · hvn.vn
