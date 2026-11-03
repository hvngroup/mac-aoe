# shellcheck shell=bash disable=SC2034  # globals consumed by the other lib files
# Shared helpers for aoe-mac. Must stay compatible with bash 3.2 (macOS default):
# no associative arrays, no ${var,,}, no mapfile, no GNU-only flags.

AOE_GAME_REPO_DEFAULT="https://github.com/hvngroup/age_of_empires_ror_hd.git"
AOE_GAME_REF_DEFAULT="master"

# Folder name inside the prefix and its Windows path. Keep both in sync.
AOE_GAME_DIR_REL="drive_c/Games/AoE"
AOE_GAME_DIR_WIN='C:\Games\AoE'

log()  { printf '==> %s\n' "$*" >&2; }
warn() { printf 'CẢNH BÁO: %s\n' "$*" >&2; }
die()  { printf 'LỖI: %s\n' "$*" >&2; exit 1; }

os_name() { uname -s; }
is_macos() { [ "$(os_name)" = "Darwin" ]; }

# Default data root: one self-contained folder holding Wine, the prefix,
# the downloaded game source, logs and the config file.
default_aoe_home() {
  if is_macos; then
    printf '%s\n' "$HOME/Library/Application Support/AoE-Mac"
  else
    printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/aoe-mac"
  fi
}

init_paths() {
  AOE_HOME="${AOE_HOME:-$(default_aoe_home)}"
  AOE_CONFIG="$AOE_HOME/config"
  AOE_PREFIX="${AOE_PREFIX:-$AOE_HOME/prefix}"
  AOE_WINE_DIR="$AOE_HOME/wine"
  AOE_CACHE="$AOE_HOME/cache"
  AOE_LOG_DIR="$AOE_HOME/logs"
  AOE_GAME_DIR="$AOE_PREFIX/$AOE_GAME_DIR_REL"
  export AOE_HOME AOE_PREFIX
}

# --- config file: plain KEY=VALUE lines, values never evaluated as code ---

config_get() {
  # config_get KEY [DEFAULT]
  local key="$1" def="${2:-}" line
  if [ -f "$AOE_CONFIG" ]; then
    line="$(grep -E "^${key}=" "$AOE_CONFIG" | tail -n 1 || true)"
    if [ -n "$line" ]; then
      printf '%s\n' "${line#*=}"
      return 0
    fi
  fi
  printf '%s\n' "$def"
}

config_set() {
  # config_set KEY VALUE
  local key="$1" value="$2" tmp
  case "$value" in *"
"*) die "Giá trị cấu hình không được chứa xuống dòng: $key" ;; esac
  mkdir -p "$AOE_HOME"
  tmp="$AOE_CONFIG.tmp.$$"
  if [ -f "$AOE_CONFIG" ]; then
    grep -vE "^${key}=" "$AOE_CONFIG" > "$tmp" || true
  else
    : > "$tmp"
  fi
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$AOE_CONFIG"
}

# --- portable file helpers ---

# Portable in-place edit of one INI key inside a section-less or sectioned file.
# ini_set FILE KEY VALUE  (replaces "KEY=..." lines; appends if missing)
ini_set() {
  local file="$1" key="$2" value="$3" tmp
  [ -f "$file" ] || die "Không tìm thấy file: $file"
  tmp="$file.tmp.$$"
  if grep -qE "^${key}=" "$file"; then
    # Preserve CRLF line endings if the file uses them.
    awk -v k="$key" -v v="$value" '
      BEGIN { FS = "=" }
      $1 == k { cr = ""; if ($0 ~ /\r$/) cr = "\r"; print k "=" v cr; next }
      { print }
    ' "$file" > "$tmp"
  else
    cat "$file" > "$tmp"
    printf '%s=%s\r\n' "$key" "$value" >> "$tmp"
  fi
  mv "$tmp" "$file"
}

ini_get() {
  # ini_get FILE KEY -> value without CR
  local file="$1" key="$2"
  grep -E "^${key}=" "$file" 2>/dev/null | tail -n 1 | cut -d= -f2- | tr -d '\r'
}

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

timestamp() { date -u +%Y%m%dT%H%M%SZ; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Thiếu lệnh '$1'. $2"
}

# Directory of the toolkit (works when called from the repo or from the .app).
toolkit_root() {
  (cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
}
