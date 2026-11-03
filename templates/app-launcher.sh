#!/bin/bash
# Entry point of the .app bundle (Contents/MacOS/aoe-launcher).
# Shows a small menu, then delegates to the embedded aoe-mac toolkit.
#
# Text encoding: every Vietnamese string reaches AppleScript as a command-line
# argument (on run argv), which osascript decodes as UTF-8. Environment
# variables read with "system attribute" are decoded as MacRoman and turn
# diacritics into mojibake, so they must not carry text. AppleScript also
# returns plain ASCII (indexes, yes/no) so its output encoding never matters.
set -u

APP_CONTENTS="$(cd "$(dirname "$0")/.." && pwd -P)"
TOOLKIT="$APP_CONTENTS/Resources/toolkit"
AOE_MAC="$TOOLKIT/aoe-mac"
# GUI apps start with a minimal PATH; add the usual Homebrew locations.
export PATH="${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}:/opt/homebrew/bin:/usr/local/bin"

dialog() {
  # dialog MESSAGE -> shows an alert (prints to stderr outside macOS)
  command -v osascript >/dev/null 2>&1 || { printf '%s\n' "$1" >&2; return 0; }
  osascript - "$1" >/dev/null 2>&1 <<'OSA'
on run argv
  display alert "AoE RoR" message (item 1 of argv)
end run
OSA
}

ask_yes_no() {
  # ask_yes_no MESSAGE -> success when the player picks "Đồng ý"
  command -v osascript >/dev/null 2>&1 || return 1
  local answer
  answer="$(osascript - "$1" "Để sau" "Đồng ý" 2>/dev/null <<'OSA'
on run argv
  set r to display dialog (item 1 of argv) buttons {item 2 of argv, item 3 of argv} default button 2 with title "AoE RoR"
  if button returned of r is (item 3 of argv) then return "yes"
  return "no"
end run
OSA
)"
  [ "$answer" = "yes" ]
}

choose() {
  # choose PROMPT ITEM... -> prints the 1-based index of the chosen item, 0 if cancelled
  command -v osascript >/dev/null 2>&1 || { echo 0; return 0; }
  osascript - "$@" 2>/dev/null <<'OSA' || echo 0
on run argv
  set thePrompt to item 1 of argv
  set theItems to rest of argv
  set picked to choose from list theItems with prompt thePrompt default items {item 1 of theItems} with title "AoE RoR"
  if picked is false then return "0"
  set p to item 1 of picked
  repeat with i from 1 to count of theItems
    if (item i of theItems) is p then return (i as text)
  end repeat
  return "0"
end run
OSA
}

if ! "$AOE_MAC" status --quiet >/dev/null 2>&1; then
  if ask_yes_no "Game chưa được cài trên máy này. Mở Terminal để cài đặt (tải Wine và game, khoảng 650 MB)?"; then
    open -a Terminal "$TOOLKIT/setup.command"
  fi
  exit 0
fi

action="$(choose "Chọn chế độ" \
  "Chơi đơn (empires.exe)" \
  "Chơi mạng LAN (EMPIRESX.EXE)" \
  "Đổi bản cân bằng..." \
  "Đổi chế độ hiển thị (cửa sổ / toàn màn hình)" \
  "Cập nhật game từ repo")"

case "$action" in
  1) mode=single ;;
  2) mode=multi ;;
  3)
    picked="$(choose "Bản cân bằng (đang dùng: $("$AOE_MAC" balance current))" \
      "ror - Rise of Rome 1.0" "de - Definitive Edition" "mace - Macedonian siêu mạnh" "original - Dữ liệu gốc")"
    case "$picked" in
      1) profile=ror ;; 2) profile=de ;; 3) profile=mace ;; 4) profile=original ;;
      *) exit 0 ;;
    esac
    "$AOE_MAC" balance "$profile" && dialog "Đã chuyển sang bản cân bằng: $profile"
    exit 0 ;;
  4)
    if [ "$("$AOE_MAC" display)" = "windowed" ]; then next=fullscreen; else next=windowed; fi
    "$AOE_MAC" display "$next" && dialog "Chế độ hiển thị: $next"
    exit 0 ;;
  5)
    open -a Terminal "$TOOLKIT/update.command"
    exit 0 ;;
  *) exit 0 ;;
esac

rc=0
"$AOE_MAC" play "$mode" || rc=$?
if [ "$rc" -ne 0 ]; then
  logfile="$("$AOE_MAC" logs --path 2>/dev/null)"
  if ask_yes_no "Game thoát bất thường (mã $rc). Mở file log để gửi bộ phận kỹ thuật?"; then
    if [ -n "$logfile" ]; then open -e "$logfile"; else open "$("$AOE_MAC" status --log-dir)"; fi
  fi
fi
