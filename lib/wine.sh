# shellcheck shell=bash
# Locating, installing and running Wine.

# Pinned Wine build for macOS: Gcenx macOS_Wine_builds, WoW64 build that runs
# 32-bit Windows programs (AoE is 32-bit) on 64-bit-only macOS.
# Override with AOE_WINE_URL + AOE_WINE_SHA256 to try another build.
AOE_WINE_URL_DEFAULT="https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.21/wine-staging-11.21-osx64.tar.xz"
AOE_WINE_SHA256_DEFAULT="d7bcd5abf4df27aae397a7898aef074fea4a2e0b51e0a55aa9659517bbf9d452"

# Print the path of a usable wine binary, or nothing.
find_wine() {
  local candidate app
  if [ -n "${AOE_WINE:-}" ]; then
    [ -x "$AOE_WINE" ] && { printf '%s\n' "$AOE_WINE"; return 0; }
    candidate="$(command -v "$AOE_WINE" 2>/dev/null || true)"
    [ -n "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
  fi
  candidate="$(config_get WINE_BIN)"
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    printf '%s\n' "$candidate"; return 0
  fi
  for app in "$AOE_WINE_DIR"/*.app \
             "/Applications/Wine Staging.app" \
             "/Applications/Wine Devel.app" \
             "/Applications/Wine Stable.app" \
             "/Applications/Wine Crossover.app"; do
    candidate="$app/Contents/Resources/wine/bin/wine"
    [ -x "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
  done
  for candidate in wine wine64; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"; return 0
    fi
  done
  return 1
}

require_wine() {
  WINE_BIN="$(find_wine || true)"
  [ -n "$WINE_BIN" ] || die "Chưa có Wine. Chạy: aoe-mac install-wine"
  WINE_BIN_DIR="$(dirname "$WINE_BIN")"
}

wine_version() { WINEPREFIX="$AOE_PREFIX" "$WINE_BIN" --version 2>/dev/null || echo "không rõ"; }

# Run a Wine command inside our prefix. Caller sets extra env if needed.
wine_run() {
  WINEPREFIX="$AOE_PREFIX" WINEDEBUG="${WINEDEBUG:--all}" "$WINE_BIN" "$@"
}

wineserver_bin() {
  if [ -x "$WINE_BIN_DIR/wineserver" ]; then
    printf '%s\n' "$WINE_BIN_DIR/wineserver"
  else
    command -v wineserver 2>/dev/null || true
  fi
}

# Block until every process in the prefix has exited (registry is flushed).
wine_wait() {
  local ws
  ws="$(wineserver_bin)"
  if [ -n "$ws" ]; then WINEPREFIX="$AOE_PREFIX" "$ws" -w || true; fi
}

rosetta_ready() {
  # Intel Macs do not need Rosetta.
  [ "$(uname -m)" = "arm64" ] || return 0
  arch -x86_64 /usr/bin/true >/dev/null 2>&1
}

cmd_install_wine() {
  local url sha tmp actual app assume_yes=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -y|--yes) assume_yes=1 ;;
      *) die "Tham số không hợp lệ cho install-wine: $1" ;;
    esac
    shift
  done

  if ! is_macos; then
    die "install-wine chỉ dành cho macOS. Trên Linux hãy cài Wine từ trình quản lý gói (vd: apt install wine wine32:i386)."
  fi

  if ! rosetta_ready; then
    warn "Máy Apple Silicon cần Rosetta 2 để chạy Wine (bản build x86_64)."
    if [ "$assume_yes" -eq 1 ] || confirm "Cài Rosetta 2 ngay bây giờ?"; then
      softwareupdate --install-rosetta --agree-to-license || die "Cài Rosetta 2 thất bại."
    else
      die "Hãy cài Rosetta 2: softwareupdate --install-rosetta --agree-to-license"
    fi
  fi

  need_cmd curl "Cần curl để tải Wine."
  need_cmd tar "Cần tar để giải nén Wine."
  url="${AOE_WINE_URL:-$AOE_WINE_URL_DEFAULT}"
  sha="${AOE_WINE_SHA256:-$AOE_WINE_SHA256_DEFAULT}"
  if [ -n "${AOE_WINE_URL:-}" ] && [ -z "${AOE_WINE_SHA256:-}" ]; then
    die "Khi đặt AOE_WINE_URL phải đặt kèm AOE_WINE_SHA256 để kiểm tra toàn vẹn."
  fi

  mkdir -p "$AOE_CACHE"
  tmp="$AOE_CACHE/$(basename "$url")"
  if [ -f "$tmp" ] && [ "$(sha256_of "$tmp")" = "$sha" ]; then
    log "Dùng lại bản Wine đã tải: $tmp"
  else
    log "Tải Wine: $url"
    curl -fL --retry 3 --progress-bar -o "$tmp.part" "$url" || die "Tải Wine thất bại."
    mv "$tmp.part" "$tmp"
  fi
  actual="$(sha256_of "$tmp")"
  [ "$actual" = "$sha" ] || { rm -f "$tmp"; die "SHA-256 không khớp (nhận $actual, cần $sha). Đã xoá file tải."; }

  log "Giải nén Wine vào $AOE_WINE_DIR"
  rm -rf "$AOE_WINE_DIR.new"
  mkdir -p "$AOE_WINE_DIR.new"
  tar -xJf "$tmp" -C "$AOE_WINE_DIR.new" || die "Giải nén Wine thất bại."
  rm -rf "$AOE_WINE_DIR"
  mv "$AOE_WINE_DIR.new" "$AOE_WINE_DIR"

  WINE_BIN=""
  for app in "$AOE_WINE_DIR"/*.app; do
    [ -x "$app/Contents/Resources/wine/bin/wine" ] && WINE_BIN="$app/Contents/Resources/wine/bin/wine"
  done
  [ -n "$WINE_BIN" ] || die "Không tìm thấy wine sau khi giải nén."
  config_set WINE_BIN "$WINE_BIN"
  log "Đã cài $("$WINE_BIN" --version 2>/dev/null || echo Wine) tại: $WINE_BIN"
}

confirm() {
  local answer
  [ -t 0 ] || return 1
  printf '%s [y/N] ' "$1" >&2
  read -r answer || return 1
  case "$answer" in y|Y|yes|YES|co|có) return 0 ;; *) return 1 ;; esac
}
