# shellcheck shell=bash
# Game source, prefix setup, registry, balance and display handling.

# Balance profiles: name|file under data/|description. Mirrors the game's
# switch_data_definitive_edition.sh, plus the untouched original data file.
balance_profiles() {
  cat <<'EOF'
ror|empires.dat.backup|Rise of Rome 1.0 (mặc định của repo, AI cải tiến)
de|empires_definitive_edition.dat|Cân bằng Definitive Edition / Return of Rome
mace|empires_mace_overpowered.dat|Macedonian siêu mạnh (gộp mọi bonus)
original|empires_original.dat|File dữ liệu gốc chưa chỉnh
EOF
}

balance_file_for() {
  balance_profiles | awk -F'|' -v n="$1" '$1 == n { print $2 }'
}

game_installed() { [ -f "$AOE_GAME_DIR/empires.exe" ]; }

require_game() {
  game_installed || die "Game chưa được cài. Chạy: aoe-mac install"
}

# --- fetching the game source ---------------------------------------------

is_url() {
  case "$1" in http://*|https://*|git@*|ssh://*) return 0 ;; *) return 1 ;; esac
}

validate_game_dir() {
  [ -f "$1/empires.exe" ] && [ -f "$1/data/empires.dat" ] && [ -d "$1/data2" ]
}

# github_zip_url URL REF -> codeload zip URL, or nothing for non-GitHub URLs.
github_zip_url() {
  local url="${1%.git}" ref="$2" path
  case "$url" in
    https://github.com/*) path="${url#https://github.com/}" ;;
    *) return 1 ;;
  esac
  printf 'https://codeload.github.com/%s/zip/refs/heads/%s\n' "$path" "$ref"
}

# fetch_source SOURCE REF -> prints the local directory holding the game.
fetch_source() {
  local source="$1" ref="$2" dest zip_url tmp
  if ! is_url "$source"; then
    [ -d "$source" ] || die "Không tìm thấy thư mục nguồn: $source"
    source="$(cd "$source" && pwd -P)"
    validate_game_dir "$source" || die "Thư mục $source không giống bản game (thiếu empires.exe/data/data2)."
    printf '%s\n' "$source"
    return 0
  fi

  dest="$AOE_CACHE/game-src"
  mkdir -p "$AOE_CACHE"
  if git_usable; then
    if [ -d "$dest/.git" ]; then
      log "Cập nhật mã nguồn game ($ref) từ $source"
      git -C "$dest" remote set-url origin "$source"
      git -C "$dest" fetch --depth 1 origin "$ref" >&2 || die "git fetch thất bại."
      git -C "$dest" checkout -q --force FETCH_HEAD >&2 || die "git checkout thất bại."
    else
      log "Tải game ($ref) từ $source (khoảng 400 MB, vui lòng chờ)"
      rm -rf "$dest"
      git clone --depth 1 --branch "$ref" "$source" "$dest" >&2 || die "git clone thất bại."
    fi
  else
    zip_url="$(github_zip_url "$source" "$ref" || true)"
    [ -n "$zip_url" ] || die "Cần git để tải từ $source. Cài Xcode Command Line Tools: xcode-select --install"
    need_cmd unzip "Cần unzip để giải nén."
    log "Không có git, tải bản zip: $zip_url"
    tmp="$AOE_CACHE/game-src.zip"
    curl -fL --retry 3 --progress-bar -o "$tmp" "$zip_url" || die "Tải zip thất bại (repo private cần git + quyền truy cập)."
    rm -rf "$dest" "$AOE_CACHE/game-src.unzip"
    mkdir -p "$AOE_CACHE/game-src.unzip"
    unzip -q "$tmp" -d "$AOE_CACHE/game-src.unzip" || die "Giải nén zip thất bại."
    mv "$AOE_CACHE/game-src.unzip"/* "$dest"
    rm -rf "$AOE_CACHE/game-src.unzip" "$tmp"
  fi
  validate_game_dir "$dest" || die "Nguồn tải về không chứa bản game hợp lệ."
  printf '%s\n' "$dest"
}

# On macOS /usr/bin/git is a stub that pops up an installer when the
# Command Line Tools are missing; treat that as "no git".
git_usable() {
  command -v git >/dev/null 2>&1 || return 1
  if is_macos && [ "$(command -v git)" = "/usr/bin/git" ]; then
    xcode-select -p >/dev/null 2>&1 || return 1
  fi
  return 0
}

# --- prefix and files ---------------------------------------------------------

init_prefix() {
  if [ -f "$AOE_PREFIX/system.reg" ]; then
    return 0
  fi
  log "Khởi tạo Wine prefix: $AOE_PREFIX"
  mkdir -p "$AOE_PREFIX"
  # Skip the Mono/Gecko download prompts: the game needs neither.
  WINEDLLOVERRIDES="mscoree=;mshtml=" wine_run wineboot -i >/dev/null 2>&1 || die "wineboot thất bại."
  wine_wait
  [ -f "$AOE_PREFIX/system.reg" ] || die "Wine prefix không được tạo đúng."
}

sync_game_files() {
  local src="$1"
  need_cmd rsync "rsync có sẵn trên macOS; trên Linux hãy cài gói rsync."
  log "Chép game vào $AOE_GAME_DIR"
  mkdir -p "$AOE_GAME_DIR"
  # Never --delete: savegames, recorded games and custom scenarios that the
  # player created inside the prefix must survive updates.
  rsync -a \
    --exclude '.git' --exclude '.github' --exclude '.idea' \
    --exclude 'data2_daominah' --exclude 'Screenshot' \
    --exclude '*.md' --exclude '*.png' --exclude '*.sh' \
    "$src/" "$AOE_GAME_DIR/" || die "Chép file game thất bại."
}

# render_template FILE -> stdout, replacing @GAME_DIR@ with the reg-escaped
# Windows path. Done with index/substr so backslashes stay literal.
render_template() {
  local escaped
  escaped="$(printf '%s' "$AOE_GAME_DIR_WIN" | sed 's/\\/\\\\/g')"
  AOE_REPL="$escaped" awk '
    {
      line = $0; out = ""; pat = "@GAME_DIR@"; rep = ENVIRON["AOE_REPL"]
      while ((i = index(line, pat)) > 0) {
        out = out substr(line, 1, i - 1) rep
        line = substr(line, i + length(pat))
      }
      print out line
    }
  ' "$1"
}

# regedit that writes to the view the 32-bit game reads.
import_reg() {
  local file_unix="$1" file_win
  file_win="$(WINEPREFIX="$AOE_PREFIX" "$WINE_BIN" winepath -w "$file_unix" 2>/dev/null | tr -d '\r')"
  [ -n "$file_win" ] || die "Không chuyển được đường dẫn sang dạng Windows: $file_unix"
  if [ -f "$AOE_PREFIX/drive_c/windows/syswow64/regedit.exe" ]; then
    wine_run 'C:\windows\syswow64\regedit.exe' /S "$file_win" >/dev/null 2>&1
  else
    wine_run regedit /S "$file_win" >/dev/null 2>&1
  fi
}

write_registry() {
  local root tmpdir
  root="$(toolkit_root)"
  tmpdir="$AOE_GAME_DIR/.aoe-mac"
  mkdir -p "$tmpdir"
  log "Ghi registry cho game"
  render_template "$root/templates/aoe-registry.reg.in" > "$tmpdir/aoe-registry.reg"
  import_reg "$tmpdir/aoe-registry.reg" || die "Import registry game thất bại."
  cp "$root/templates/mac-driver.reg.in" "$tmpdir/mac-driver.reg"
  import_reg "$tmpdir/mac-driver.reg" || warn "Không ghi được tuỳ chỉnh Mac Driver."
  wine_wait
}

# Re-apply the player's choices after files were (re)synced from source.
apply_preferences() {
  local balance display
  balance="$(config_get BALANCE)"
  display="$(config_get DISPLAY_MODE)"
  [ -n "$balance" ] && set_balance "$balance"
  # Apple Silicon cannot switch to the game's low display modes, and the
  # bundled wndmode.dll crashes under Rosetta: default to cnc-ddraw on macOS.
  # A window keeps the CPU-side GDI scaling small (fullscreen on a large
  # monitor lagged), and GDI is the only renderer that shows text boxes.
  if [ -z "$display" ] && is_macos; then
    display="cnc-window"
    config_set DISPLAY_MODE "$display"
  fi
  [ -n "$display" ] && set_display "$display"
  local dplay
  dplay="$(config_get DIRECTPLAY)"
  # Wine's own DirectPlay cannot host games; Microsoft's can (verified on
  # macOS 27 / Wine 11.21), so Macs default to it.
  if [ -z "$dplay" ] && is_macos; then
    dplay="microsoft"
    config_set DIRECTPLAY "$dplay"
  fi
  [ "$dplay" = "native" ] && { dplay=microsoft; config_set DIRECTPLAY microsoft; }
  [ -n "$dplay" ] && set_directplay "$dplay"
  local cursor
  cursor="$(config_get CURSOR)"
  [ -n "$cursor" ] && set_cursor "$cursor"
  return 0
}

cmd_install() {
  local source="" ref=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --source) [ $# -ge 2 ] || die "--source cần giá trị"; source="$2"; shift ;;
      --ref) [ $# -ge 2 ] || die "--ref cần giá trị"; ref="$2"; shift ;;
      *) die "Tham số không hợp lệ cho install: $1" ;;
    esac
    shift
  done
  source="${source:-$(config_get GAME_SOURCE "$AOE_GAME_REPO_DEFAULT")}"
  ref="${ref:-$(config_get GAME_REF "$AOE_GAME_REF_DEFAULT")}"

  require_wine
  log "Dùng Wine: $WINE_BIN ($(wine_version))"
  local src
  src="$(fetch_source "$source" "$ref")"
  init_prefix
  sync_game_files "$src"
  write_registry
  apply_preferences
  config_set GAME_SOURCE "$source"
  config_set GAME_REF "$ref"
  config_set WINE_BIN "$WINE_BIN"
  log "Cài đặt xong. Chơi bằng: aoe-mac play   (hoặc tạo app: aoe-mac build-app)"
}

cmd_update() {
  require_game
  cmd_install "$@"
}

# --- balance ------------------------------------------------------------------

current_balance() {
  local cur name file
  cur="$(sha256_of "$AOE_GAME_DIR/data/empires.dat")"
  balance_profiles | while IFS='|' read -r name file _; do
    if [ -f "$AOE_GAME_DIR/data/$file" ] && [ "$(sha256_of "$AOE_GAME_DIR/data/$file")" = "$cur" ]; then
      printf '%s\n' "$name"
      return 0
    fi
  done
}

set_balance() {
  local name="$1" file
  file="$(balance_file_for "$name")"
  [ -n "$file" ] || die "Bản cân bằng không hợp lệ: $name (chọn: ror, de, mace, original)"
  [ -f "$AOE_GAME_DIR/data/$file" ] || die "Thiếu file dữ liệu: data/$file"
  cp -f "$AOE_GAME_DIR/data/$file" "$AOE_GAME_DIR/data/empires.dat"
}

cmd_balance() {
  require_game
  local name="${1:-}" cur
  if [ "$name" = "current" ]; then
    cur="$(current_balance)"
    printf '%s\n' "${cur:-không rõ}"
    return 0
  fi
  if [ -z "$name" ] || [ "$name" = "status" ] || [ "$name" = "list" ]; then
    cur="$(current_balance)"
    balance_profiles | while IFS='|' read -r n _ desc; do
      if [ "$n" = "$cur" ]; then printf ' * %-9s %s\n' "$n" "$desc"; else printf '   %-9s %s\n' "$n" "$desc"; fi
    done
    [ -n "$cur" ] || echo "   (empires.dat hiện tại không khớp bản nào ở trên)"
    return 0
  fi
  set_balance "$name"
  config_set BALANCE "$name"
  log "Đã chuyển sang bản cân bằng: $name"
}

# --- display ------------------------------------------------------------------

# Display modes:
#   cnc / cnc-window: cnc-ddraw (MIT, github.com/FunkyFr3sh/cnc-ddraw) replaces
#     DirectDraw and scales the 8-bit picture into a borderless fullscreen or
#     a window, so the real display mode never changes. Apple Silicon Macs no
#     longer offer the low modes the game requests (black screen otherwise).
#     Default on macOS.
#   windowed / fullscreen: the game's bundled data\wndmode.dll wrapper drives
#     DirectDraw (UseWindowMode=1/0 in data/wndmode.ini).
#   native: no wrapper; Wine's own DirectDraw switches the real display mode.
# wndmode.dll hooks ddraw/d3d/dinput/user32 by patching code, which crashed
# under Wine + Rosetta on Apple Silicon, so every mode but windowed/fullscreen
# switches it off (renamed, never deleted).
OFF_SUFFIX=".aoe-mac-off"
# Flags wndmode.ini hands the game; modes without wndmode pass them directly:
# nostartup skips the intro videos, systemmemory and mfill avoid DirectDraw
# rendering glitches on modern systems.
NATIVE_GAME_ARGS="nostartup systemmemory mfill"

AOE_CNC_DDRAW_URL_DEFAULT="https://github.com/FunkyFr3sh/cnc-ddraw/releases/download/v7.1.0.0/cnc-ddraw.zip"
AOE_CNC_DDRAW_SHA256_DEFAULT="0b13ab89a64c9918189b1dadd449ef6ed3cb3b7b19cabd96d8adbd95505bb908"

# file_enable PATH / file_disable PATH: toggle a DLL by renaming it.
file_enable() {
  if [ ! -f "$1" ] && [ -f "$1$OFF_SUFFIX" ]; then mv "$1$OFF_SUFFIX" "$1"; fi
}
file_disable() {
  if [ -f "$1" ]; then mv -f "$1" "$1$OFF_SUFFIX"; fi
}

cnc_ddraw_dll() { printf '%s\n' "$AOE_GAME_DIR/ddraw.dll"; }

# Download (once, checksum-verified) and place cnc-ddraw's ddraw.dll.
cnc_ddraw_install() {
  local url sha zip dll
  dll="$(cnc_ddraw_dll)"
  file_enable "$dll"
  url="${AOE_CNC_DDRAW_URL:-$AOE_CNC_DDRAW_URL_DEFAULT}"
  sha="${AOE_CNC_DDRAW_SHA256:-$AOE_CNC_DDRAW_SHA256_DEFAULT}"
  zip="$AOE_CACHE/cnc-ddraw-$sha.zip"
  if [ ! -f "$zip" ] || [ "$(sha256_of "$zip")" != "$sha" ]; then
    need_cmd curl "Cần curl để tải cnc-ddraw."
    mkdir -p "$AOE_CACHE"
    log "Tải cnc-ddraw: $url"
    curl -fsSL --retry 3 -o "$zip.part" "$url" || die "Tải cnc-ddraw thất bại."
    mv "$zip.part" "$zip"
  fi
  [ "$(sha256_of "$zip")" = "$sha" ] || { rm -f "$zip"; die "SHA-256 của cnc-ddraw không khớp, đã xoá file tải."; }
  if [ ! -f "$dll" ] || [ "$zip" -nt "$dll" ]; then
    need_cmd unzip "Cần unzip để giải nén cnc-ddraw."
    unzip -o -q -j "$zip" ddraw.dll -d "$AOE_GAME_DIR" || die "Giải nén cnc-ddraw thất bại."
    touch "$dll"
  fi
}

CNC_RENDERERS="gdi opengl openglcore direct3d9 auto"

cnc_ddraw_configure() {
  local fullscreen="$1" renderer
  renderer="$(config_get CNC_RENDERER gdi)"
  # CNC_TWEAKS holds "key=value;key=value" set with "aoe-mac tweak": each key
  # replaces its line in every section that has it, or is added to [ddraw].
  sed -e "s/@FULLSCREEN@/$fullscreen/" -e "s/@RENDERER@/$renderer/" \
    "$(toolkit_root)/templates/cnc-ddraw.ini.in" |
    AOE_TWEAKS="$(config_get CNC_TWEAKS)" awk '
      BEGIN {
        n = split(ENVIRON["AOE_TWEAKS"], pairs, ";")
        for (i = 1; i <= n; i++) {
          if (pairs[i] == "") continue
          eq = index(pairs[i], "=")
          k = substr(pairs[i], 1, eq - 1); v = substr(pairs[i], eq + 1)
          val[k] = v; order[++count] = k
        }
      }
      function flush_ddraw(   j) {
        for (j = 1; j <= count; j++) if (!(order[j] in seen)) print order[j] "=" val[order[j]]
      }
      /^\[/ { if (section == "ddraw") flush_ddraw(); section = substr($0, 2, index($0, "]") - 2) }
      {
        eq = index($0, "=")
        if (eq > 1 && substr($0, 1, 1) != ";") {
          k = substr($0, 1, eq - 1)
          if (k in val) { if (section == "ddraw") seen[k] = 1; print k "=" val[k]; next }
        }
        print
      }
      END { if (section == "ddraw") flush_ddraw() }
    ' > "$AOE_GAME_DIR/ddraw.ini"
}

reapply_cnc_config() {
  case "$(current_display)" in
    cnc) cnc_ddraw_configure true ;;
    cnc-window) cnc_ddraw_configure false ;;
    *) return 1 ;;
  esac
}

# Expert knob for trying cnc-ddraw settings (see the comments in cnc-ddraw's
# own ddraw.ini) without a new aoe-mac release.
cmd_tweak() {
  require_game
  local arg="${1:-}" key value current new pair
  current="$(config_get CNC_TWEAKS)"
  case "$arg" in
    "")
      if [ -z "$current" ]; then echo "(chưa có tinh chỉnh nào)"; else printf '%s\n' "$current" | tr ';' '\n'; fi
      return 0 ;;
    --reset)
      config_set CNC_TWEAKS ""
      reapply_cnc_config || true
      log "Đã xoá mọi tinh chỉnh cnc-ddraw."
      return 0 ;;
  esac
  case "$arg" in
    *=*) key="${arg%%=*}"; value="${arg#*=}" ;;
    *) die "Cách dùng: aoe-mac tweak KEY=VALUE | aoe-mac tweak --reset" ;;
  esac
  printf '%s' "$key" | grep -Eq '^[A-Za-z0-9_]+$' || die "Tên tuỳ chọn không hợp lệ: $key"
  case "$value" in *";"*) die "Giá trị không được chứa dấu ';'" ;; esac
  case "$key" in renderer) die "Dùng 'aoe-mac renderer' để đổi renderer." ;; esac
  new=""
  local IFS=';'
  for pair in $current; do
    [ -n "$pair" ] && [ "${pair%%=*}" != "$key" ] && new="${new:+$new;}$pair"
  done
  unset IFS
  [ -n "$value" ] && new="${new:+$new;}$key=$value"
  config_set CNC_TWEAKS "$new"
  reapply_cnc_config || warn "Tinh chỉnh chỉ có tác dụng ở chế độ cnc/cnc-window (aoe-mac display cnc)."
  log "cnc-ddraw: $key=${value:-(mặc định)}"
}

cmd_renderer() {
  require_game
  local renderer="${1:-}" r valid=0
  if [ -z "$renderer" ]; then
    config_get CNC_RENDERER gdi
    return 0
  fi
  for r in $CNC_RENDERERS; do [ "$r" = "$renderer" ] && valid=1; done
  [ "$valid" -eq 1 ] || die "Renderer không hợp lệ: $renderer (chọn: $CNC_RENDERERS)"
  config_set CNC_RENDERER "$renderer"
  reapply_cnc_config || warn "Renderer chỉ có tác dụng ở chế độ cnc/cnc-window (aoe-mac display cnc)."
  log "Renderer cnc-ddraw: $renderer"
}

set_display() {
  local ini="$AOE_GAME_DIR/data/wndmode.ini" wnd="$AOE_GAME_DIR/data/wndmode.dll"
  case "$1" in
    cnc|cnc-window)
      cnc_ddraw_install
      if [ "$1" = "cnc" ]; then cnc_ddraw_configure true; else cnc_ddraw_configure false; fi
      file_disable "$wnd" ;;
    windowed) file_disable "$(cnc_ddraw_dll)"; file_enable "$wnd"; ini_set "$ini" UseWindowMode 1 ;;
    fullscreen) file_disable "$(cnc_ddraw_dll)"; file_enable "$wnd"; ini_set "$ini" UseWindowMode 0 ;;
    native) file_disable "$(cnc_ddraw_dll)"; file_disable "$wnd" ;;
    *) die "Chế độ hiển thị không hợp lệ: $1 (chọn: cnc, cnc-window, windowed, fullscreen, native)" ;;
  esac
}

current_display() {
  if [ -f "$(cnc_ddraw_dll)" ]; then
    if [ "$(ini_get "$AOE_GAME_DIR/ddraw.ini" fullscreen)" = "true" ]; then echo cnc; else echo cnc-window; fi
    return 0
  fi
  if [ ! -f "$AOE_GAME_DIR/data/wndmode.dll" ]; then
    echo native
    return 0
  fi
  case "$(ini_get "$AOE_GAME_DIR/data/wndmode.ini" UseWindowMode)" in
    0) echo fullscreen ;;
    *) echo windowed ;;
  esac
}

# --- DirectPlay (multiplayer) --------------------------------------------------
#   wine:      Wine's own DirectPlay. Joins games but cannot host: its TCP/IP
#              provider returns DPERR_UNSUPPORTED for session creation.
#   microsoft: the complete DirectPlay 5.3 set (dplayx, dpwsockx, dpmodemx,
#              dplaysvr) from Microsoft's DirectX February 2010 redistributable,
#              installed into the prefix's 32-bit system folder, as winetricks'
#              "directplay" verb does. The game's own dplayx.dll (XP
#              5.1, without a matching dpwsockx) is switched off because the
#              game folder is searched first; on its own it hung the game.
AOE_DXREDIST_SHA256_DEFAULT="f6d191e89a963d7cca34f169d30f49eab99c1ed3bb92da73ec43617caaa1e93f"
# Microsoft removed the original download; these are the archive.org copy of
# it (what winetricks uses) and the winetricks fallback mirror. Same file,
# verified by SHA-256.
AOE_DXREDIST_URLS_DEFAULT="https://web.archive.org/web/20100205000000id_/https://download.microsoft.com/download/E/E/1/EE17FF74-6C45-4575-9CF4-7FC2597ACD18/directx_feb2010_redist.exe https://files.holarse-linuxgaming.de/mirrors/microsoft/directx_feb2010_redist.exe"
DPLAY_MS_FILES="dplayx.dll dpwsockx.dll dpmodemx.dll dplaysvr.exe"
DPLAY_MS_OVERRIDES="dplayx=n,b;dpwsockx=n,b;dpmodemx=n,b;dplaysvr.exe=n,b"

# 32-bit system folder of the prefix (syswow64 on 64-bit/WoW64 prefixes).
prefix_sys32_dir() {
  if [ -d "$AOE_PREFIX/drive_c/windows/syswow64" ]; then
    printf '%s\n' "$AOE_PREFIX/drive_c/windows/syswow64"
  else
    printf '%s\n' "$AOE_PREFIX/drive_c/windows/system32"
  fi
}

# bsdtar reads Microsoft's self-extracting CAB files; macOS's tar is bsdtar.
cab_tool() {
  if command -v bsdtar >/dev/null 2>&1; then echo bsdtar
  elif is_macos; then echo tar
  else die "Cần bsdtar để giải nén gói DirectX (Ubuntu/Debian: apt install libarchive-tools)."
  fi
}

directplay_ms_download() {
  local sha urls url dest
  sha="${AOE_DXREDIST_SHA256:-$AOE_DXREDIST_SHA256_DEFAULT}"
  urls="${AOE_DXREDIST_URL:-$AOE_DXREDIST_URLS_DEFAULT}"
  dest="$AOE_CACHE/directx_feb2010_redist-$sha.exe"
  if [ -f "$dest" ] && [ "$(sha256_of "$dest")" = "$sha" ]; then
    printf '%s\n' "$dest"; return 0
  fi
  need_cmd curl "Cần curl để tải gói DirectX."
  mkdir -p "$AOE_CACHE"
  for url in $urls; do
    log "Tải DirectX (Microsoft, khoảng 105 MB): $url"
    if curl -fL --retry 2 --progress-bar -o "$dest.part" "$url" && [ "$(sha256_of "$dest.part")" = "$sha" ]; then
      mv "$dest.part" "$dest"
      printf '%s\n' "$dest"; return 0
    fi
    warn "Không tải được hoặc SHA-256 không khớp, thử nguồn khác."
    rm -f "$dest.part"
  done
  die "Không tải được gói DirectX từ nguồn nào."
}

directplay_ms_install() {
  local redist tool work sys f
  sys="$(prefix_sys32_dir)"
  local all_present=1
  for f in $DPLAY_MS_FILES; do
    [ -f "$sys/$f.aoe-mac-ms" ] || all_present=0
  done
  if [ "$all_present" -eq 0 ]; then
    redist="$(directplay_ms_download)"
    tool="$(cab_tool)"
    work="$AOE_CACHE/dplay-extract"
    rm -rf "$work"; mkdir -p "$work"
    "$tool" -xf "$redist" -C "$work" dxnt.cab || die "Không tách được dxnt.cab từ gói DirectX."
    # shellcheck disable=SC2086  # file list is a fixed set of names
    (cd "$work" && "$tool" -xf dxnt.cab $DPLAY_MS_FILES) || die "Không tách được file DirectPlay từ dxnt.cab."
    for f in $DPLAY_MS_FILES; do
      [ -s "$work/$f" ] || die "Thiếu $f trong gói DirectX."
      # Keep a pristine copy so re-applying never needs the download again.
      cp -f "$work/$f" "$sys/$f.aoe-mac-ms"
    done
    # The pristine copies above are all that is needed from now on.
    rm -rf "$work" "$redist"
  fi
  for f in $DPLAY_MS_FILES; do
    cp -f "$sys/$f.aoe-mac-ms" "$sys/$f"
  done
}

set_directplay() {
  case "$1" in
    wine) file_enable "$AOE_GAME_DIR/dplayx.dll" ;;
    microsoft)
      directplay_ms_install
      file_disable "$AOE_GAME_DIR/dplayx.dll" ;;
    *) die "Giá trị không hợp lệ: $1 (chọn: wine, microsoft)" ;;
  esac
}

cmd_directplay() {
  require_game
  local mode="${1:-}"
  # "native" (0.2.x) meant the game's lone XP dplayx.dll, which hung; map it
  # to the complete Microsoft set.
  [ "$mode" = "native" ] && mode=microsoft
  case "$mode" in
    "") config_get DIRECTPLAY wine; return 0 ;;
    wine|microsoft) ;;
    *) die "Giá trị không hợp lệ: $mode (chọn: wine, microsoft)" ;;
  esac
  set_directplay "$mode"
  config_set DIRECTPLAY "$mode"
  log "DirectPlay: $mode"
  if [ "$mode" = "wine" ]; then
    log "DirectPlay của Wine vào được phòng (Join) nhưng chưa tạo được phòng (Create)."
  else
    log "Khi tạo phòng, nếu macOS hỏi cho phép 'wine' nhận kết nối mạng, hãy chọn Cho phép."
  fi
}

# Mouse cursor: the game's own (redrawn with each frame, choppy when the
# frame rate drops) or the system one (smooth, drawn by macOS).
set_cursor() {
  local value tmpdir
  case "$1" in
    system) value=00000000 ;;
    game) value=00000001 ;;
    *) die "Giá trị không hợp lệ: $1 (chọn: system, game)" ;;
  esac
  tmpdir="$AOE_GAME_DIR/.aoe-mac"
  mkdir -p "$tmpdir"
  sed "s/@CUSTOM_MOUSE@/$value/" "$(toolkit_root)/templates/cursor.reg.in" > "$tmpdir/cursor.reg"
  import_reg "$tmpdir/cursor.reg" || die "Không ghi được registry con trỏ chuột."
  wine_wait
}

cmd_cursor() {
  require_game
  case "${1:-}" in
    "") config_get CURSOR game; return 0 ;;
    system|game) ;;
    *) die "Giá trị không hợp lệ: $1 (chọn: system, game)" ;;
  esac
  require_wine
  set_cursor "$1"
  config_set CURSOR "$1"
  log "Con trỏ chuột: $1"
}

# Modes that do not go through wndmode.dll need its flags passed directly.
display_uses_wndmode() {
  case "$(current_display)" in windowed|fullscreen) return 0 ;; *) return 1 ;; esac
}

cmd_display() {
  require_game
  local mode="${1:-}"
  if [ -z "$mode" ] || [ "$mode" = "status" ]; then
    current_display
    return 0
  fi
  set_display "$mode"
  config_set DISPLAY_MODE "$mode"
  log "Chế độ hiển thị: $mode"
}

# --- play ---------------------------------------------------------------------

cmd_play() {
  local mode="single" exe logfile
  case "${1:-}" in
    ""|single|don) mode="single" ;;
    multi|lan|mang) mode="multi" ;;
    *) die "Chế độ chơi không hợp lệ: $1 (chọn: single, multi)" ;;
  esac
  [ $# -gt 0 ] && shift
  require_wine
  require_game
  if [ "$mode" = "multi" ]; then exe="EMPIRESX.EXE"; else exe="empires.exe"; fi
  if [ $# -eq 0 ] && ! display_uses_wndmode; then
    # shellcheck disable=SC2086  # intentional word splitting of the flag list
    set -- $NATIVE_GAME_ARGS
  fi
  local overrides=""
  case "$(current_display)" in
    # Wine prefers its builtin ddraw; load cnc-ddraw from the game folder.
    cnc|cnc-window) overrides="ddraw=n,b" ;;
  esac
  if [ "$(config_get DIRECTPLAY wine)" = "microsoft" ]; then
    overrides="${overrides:+$overrides;}$DPLAY_MS_OVERRIDES"
  fi
  if [ -n "$overrides" ]; then
    WINEDLLOVERRIDES="$overrides${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
    export WINEDLLOVERRIDES
  fi
  mkdir -p "$AOE_LOG_DIR"
  logfile="$AOE_LOG_DIR/game-$(timestamp).log"
  log "Khởi động $exe (log: $logfile)"
  write_log_header "$exe" "$@" > "$logfile"
  # Wine maps the Unix working directory to C:\Games\AoE, which the game
  # needs to find data\, data2\ and its DLLs.
  cd "$AOE_GAME_DIR" || die "Không vào được thư mục game."
  local rc=0 pid
  log "Game đang chạy. Terminal sẽ chờ đến khi bạn thoát game."
  log "Không thấy cửa sổ game hoặc game bị treo: nhấn Ctrl+C (hoặc chạy 'aoe-mac stop' ở tab khác)."
  # Keep Wine errors in the log (cheap, and the only clue when the game
  # fails to start); the player can still override WINEDEBUG.
  # Run in the background and wait: a GUI program under Wine may ignore
  # Ctrl+C, while "wait" returns at once so the trap can stop the prefix.
  WINEDEBUG="${WINEDEBUG:-$AOE_PLAY_WINEDEBUG}" wine_run "$AOE_GAME_DIR_WIN\\$exe" "$@" >>"$logfile" 2>&1 &
  pid=$!
  AOE_PLAY_LOG="$logfile"
  trap 'stop_on_signal' INT TERM
  wait "$pid" || rc=$?
  trap - INT TERM
  wine_wait
  printf '\n=== exit code: %s (%s) ===\n' "$rc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$logfile"
  [ "$rc" -eq 0 ] || warn "Game thoát với mã $rc. Xem log: aoe-mac logs"
  # Keep the last 10 logs only.
  # shellcheck disable=SC2012  # log names are generated by us, no spaces
  ls -1t "$AOE_LOG_DIR"/game-*.log 2>/dev/null | tail -n +11 | while IFS= read -r old; do rm -f "$old"; done
  return $rc
}

# Default Wine logging for play: errors, plus one line per loaded DLL so a
# silent hang still shows the last DLL that was loaded.
AOE_PLAY_WINEDEBUG="err+all,fixme-all,+loaddll"

# Kill every Wine process of the game prefix (hung game, invisible window).
stop_game_processes() {
  local ws
  ws="$(wineserver_bin)"
  if [ -n "$ws" ]; then WINEPREFIX="$AOE_PREFIX" "$ws" -k >/dev/null 2>&1 || true; fi
}

stop_on_signal() {
  trap - INT TERM
  stop_game_processes
  printf '\n=== stopped by user (%s) ===\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${AOE_PLAY_LOG:-/dev/null}"
  warn "Đã dừng game. Log: aoe-mac logs"
  exit 130
}

cmd_stop() {
  require_wine
  stop_game_processes
  log "Đã dừng mọi tiến trình Wine của game."
}

# Environment summary at the top of each game log, so a log pasted into a
# support ticket is enough to diagnose without a second round trip.
write_log_header() {
  local exe="$1"; shift
  echo "=== aoe-mac $(cat "$(toolkit_root)/VERSION" 2>/dev/null) $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo "system   : $(uname -s) $(uname -r) $(uname -m)"
  if is_macos; then echo "macOS    : $(sw_vers -productVersion 2>/dev/null)"; fi
  echo "wine     : $WINE_BIN ($(wine_version))"
  echo "command  : $exe $*"
  echo "balance  : $(current_balance || true)"
  echo "display  : $(current_display)"
  echo "cnc-ddraw: $([ -f "$(cnc_ddraw_dll)" ] && echo "on, renderer=$(ini_get "$AOE_GAME_DIR/ddraw.ini" renderer), tweaks=$(config_get CNC_TWEAKS)" || echo off)"
  echo "wndmode  : $([ -f "$AOE_GAME_DIR/data/wndmode.dll" ] && echo on || echo off) $(grep -E '^(UseWindowMode|CommandLine)=' "$AOE_GAME_DIR/data/wndmode.ini" 2>/dev/null | tr -d '\r' | tr '\n' ' ')"
  echo "directplay: $(config_get DIRECTPLAY wine)"
  echo "cursor   : $(config_get CURSOR game)"
  echo "WINEDEBUG: ${WINEDEBUG:-$AOE_PLAY_WINEDEBUG}"
  echo "WINEDLLOVERRIDES: ${WINEDLLOVERRIDES:-}"
  echo "=== wine output ==="
}

latest_log() {
  # shellcheck disable=SC2012  # log names are generated by us, no spaces
  ls -1t "$AOE_LOG_DIR"/game-*.log 2>/dev/null | head -n 1
}

cmd_logs() {
  local file
  file="$(latest_log)"
  [ -n "$file" ] || die "Chưa có log nào trong $AOE_LOG_DIR"
  case "${1:-}" in
    --path) printf '%s\n' "$file" ;;
    "")
      # Always show the environment header (settings of that run), then the
      # last 200 lines of Wine output.
      awk '{ print } /^=== wine output ===$/ { exit }' "$file"
      local total header
      total="$(wc -l < "$file" | tr -d ' ')"
      header="$(awk '/^=== wine output ===$/ { print NR; exit }' "$file")"
      if [ -n "$header" ] && [ $((total - header)) -gt 200 ]; then
        echo "... ($((total - header - 200)) dòng bị lược, xem đủ: aoe-mac logs --path) ..."
        tail -n 200 "$file"
      elif [ -n "$header" ]; then
        tail -n +$((header + 1)) "$file"
      else
        tail -n 200 "$file"
      fi ;;
    *) die "Tham số không hợp lệ cho logs: $1" ;;
  esac
}

# Open Wine's configuration GUI for the game prefix (audio, graphics...).
cmd_winecfg() {
  require_wine
  wine_run winecfg
}

# --- uninstall ----------------------------------------------------------------

safe_rm_rf() {
  local target="$1"
  case "$target" in
    ""|"/"|"$HOME"|"$HOME/") die "Từ chối xoá đường dẫn nguy hiểm: '$target'" ;;
  esac
  case "$target" in
    "$AOE_HOME"|"$AOE_HOME"/*) rm -rf "$target" ;;
    *) die "Từ chối xoá ngoài thư mục dữ liệu AoE-Mac: $target" ;;
  esac
}

cmd_uninstall() {
  local all=0 yes=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --all) all=1 ;;
      -y|--yes) yes=1 ;;
      *) die "Tham số không hợp lệ cho uninstall: $1" ;;
    esac
    shift
  done
  if [ "$all" -eq 1 ]; then
    [ "$yes" -eq 1 ] || confirm "Xoá TOÀN BỘ $AOE_HOME (Wine, game, bản lưu)?" || die "Đã huỷ."
    safe_rm_rf "$AOE_HOME"
  else
    [ "$yes" -eq 1 ] || confirm "Xoá game và bản lưu trong $AOE_PREFIX (giữ lại Wine)?" || die "Đã huỷ."
    [ -n "$(find_wine || true)" ] && { require_wine; WINEPREFIX="$AOE_PREFIX" "$(wineserver_bin)" -k 2>/dev/null || true; }
    safe_rm_rf "$AOE_PREFIX"
    safe_rm_rf "$AOE_CACHE"
  fi
  log "Đã gỡ."
}
