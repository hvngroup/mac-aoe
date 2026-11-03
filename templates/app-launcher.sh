#!/bin/bash
# Entry point of the .app bundle (Contents/MacOS/aoe-launcher).
# Shows a small menu, then delegates to the embedded aoe-mac toolkit.
set -u

APP_CONTENTS="$(cd "$(dirname "$0")/.." && pwd -P)"
TOOLKIT="$APP_CONTENTS/Resources/toolkit"
AOE_MAC="$TOOLKIT/aoe-mac"
# GUI apps start with a minimal PATH; add the usual Homebrew locations.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

dialog() {
  # dialog MESSAGE -> shows an alert (no-op outside macOS)
  command -v osascript >/dev/null 2>&1 || { printf '%s\n' "$1" >&2; return 0; }
  AOE_MSG="$1" osascript -e 'display alert "AoE RoR" message (system attribute "AOE_MSG")' >/dev/null 2>&1
}

ask_yes_no() {
  command -v osascript >/dev/null 2>&1 || return 1
  local answer
  answer="$(AOE_MSG="$1" osascript \
    -e 'display dialog (system attribute "AOE_MSG") buttons {"Để sau", "Đồng ý"} default button "Đồng ý" with title "AoE RoR"' \
    -e 'button returned of result' 2>/dev/null)"
  [ "$answer" = "Đồng ý" ]
}

choose() {
  # choose PROMPT ITEM... -> prints the chosen item, empty if cancelled
  local prompt="$1"; shift
  local list="" item
  for item in "$@"; do list="$list${list:+|}$item"; done
  AOE_PROMPT="$prompt" AOE_ITEMS="$list" osascript <<'OSA' 2>/dev/null
set AppleScript's text item delimiters to "|"
set theItems to text items of (system attribute "AOE_ITEMS")
set picked to choose from list theItems with prompt (system attribute "AOE_PROMPT") default items {item 1 of theItems} with title "AoE RoR"
if picked is false then return ""
return item 1 of picked
OSA
}

if ! "$AOE_MAC" status --quiet >/dev/null 2>&1; then
  if ask_yes_no "Game chưa được cài trên máy này. Mở Terminal để cài đặt (tải Wine và game, khoảng 650 MB)?"; then
    open -a Terminal "$TOOLKIT/setup.command"
  fi
  exit 0
fi

PLAY_SINGLE="Chơi đơn (empires.exe)"
PLAY_MULTI="Chơi mạng LAN (EMPIRESX.EXE)"
BALANCE="Đổi bản cân bằng..."
DISPLAY="Đổi chế độ hiển thị (cửa sổ / toàn màn hình)"
UPDATE="Cập nhật game từ repo"

action="$(choose "Chọn chế độ" "$PLAY_SINGLE" "$PLAY_MULTI" "$BALANCE" "$DISPLAY" "$UPDATE")"
case "$action" in
  "$PLAY_SINGLE") mode=single ;;
  "$PLAY_MULTI") mode=multi ;;
  "$BALANCE")
    picked="$(choose "Bản cân bằng (đang dùng: $("$AOE_MAC" balance current))" \
      "ror - Rise of Rome 1.0" "de - Definitive Edition" "mace - Macedonian siêu mạnh" "original - Dữ liệu gốc")"
    [ -n "$picked" ] && "$AOE_MAC" balance "${picked%% *}" && dialog "Đã chuyển sang bản cân bằng: ${picked%% *}"
    exit 0 ;;
  "$DISPLAY")
    if [ "$("$AOE_MAC" display)" = "windowed" ]; then next=fullscreen; else next=windowed; fi
    "$AOE_MAC" display "$next" && dialog "Chế độ hiển thị: $next"
    exit 0 ;;
  "$UPDATE")
    open -a Terminal "$TOOLKIT/update.command"
    exit 0 ;;
  *) exit 0 ;;
esac

if ! "$AOE_MAC" play "$mode"; then
  dialog "Game thoát bất thường. Xem log trong: $("$AOE_MAC" status --log-dir)"
fi
