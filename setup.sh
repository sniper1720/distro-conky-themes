#!/bin/bash
# Distro Conky Themes Installer

set -e

# Tokyo Night palette (true color)
GREEN='\033[38;2;158;206;106m'    # #9ece6a success
BLUE='\033[38;2;122;162;247m'     # #7aa2f7 secondary
YELLOW='\033[38;2;224;175;104m'  # #e0af68 warning
RED='\033[38;2;247;118;142m'     # #f7768e error
CYAN='\033[38;2;125;207;255m'    # #7dcfff accent
BOLD='\033[1m'
DIM='\033[38;2;86;95;137m'       # #565f89 dimmed
NC='\033[0m'

if [[ ! -t 1 ]]; then
    GREEN='' BLUE='' YELLOW='' RED='' CYAN='' BOLD='' DIM='' NC=''
fi

log() { printf '%b\n' "$*"; }
sep() { log "${DIM}$(printf '─%.0s' {1..50})${NC}"; }
header() {
    local title="$1"
    local label="┌─── ${title} "
    local pad=$((50 - ${#label} - 1))
    log
    log "${BOLD}${label}$(printf '─%.0s' $(seq 1 $pad))┐${NC}"
}

FONT_MANIFEST="$HOME/.config/conky/.fonts-installed"
APPIMAGE_MANIFEST="$HOME/.config/conky/.appimage-installed"

TEMP_DIR=""
CORE_FILE=""
cleanup() {
    [[ -n "${TEMP_DIR:-}" ]] && rm -rf -- "$TEMP_DIR"
    [[ -n "${CORE_FILE:-}" ]] && rm -f -- "$CORE_FILE"
}
trap cleanup EXIT

# Remote Clone Support
if [ ! -d "pure" ] && [ ! -d "octopus" ]; then
    log "${BLUE}Cloning the repository...${NC}"

    if ! command -v git &> /dev/null; then
        log "${RED}Git is not installed. Please install git first.${NC}"
        exit 1
    fi

    TEMP_DIR=$(mktemp -d)
    git clone --depth 1 https://github.com/sniper1720/distro-conky-themes.git "$TEMP_DIR"
    cd "$TEMP_DIR"
    bash ./setup.sh local < /dev/tty
    exit 0
fi

# Uninstallation Support
if [ "$1" == "--uninstall" ]; then
    log "${CYAN}Uninstalling Conky Themes...${NC}"

    OUR_PIDS=$(pgrep -u "$UID" -f "conky.*-c.*/conky/(octopus|pure)" 2>/dev/null || true)
    if [ -n "$OUR_PIDS" ]; then
        echo "$OUR_PIDS" | xargs -r kill 2>/dev/null || true
        log "  ${GREEN}[✓]${NC} Stopped running themes"
    fi

    rm -rf "$HOME/.config/conky/pure"
    rm -rf "$HOME/.config/conky/octopus"
    rm -f "$HOME/.config/autostart/conky-themes.desktop"

    if [ -f "$FONT_MANIFEST" ]; then
        while IFS= read -r font_file; do
            [ -n "$font_file" ] || continue
            rm -f "$HOME/.local/share/fonts/$font_file"
        done < "$FONT_MANIFEST"
        rm -f "$FONT_MANIFEST"
        if command -v fc-cache &>/dev/null; then
            fc-cache -f &>/dev/null || true
        fi
        log "  ${GREEN}[✓]${NC} Fonts removed"
    fi

    if [ -f "$APPIMAGE_MANIFEST" ]; then
        # shellcheck disable=SC1090
        . "$APPIMAGE_MANIFEST"
        [ -n "$APPIMAGE_PATH" ] && rm -f "$APPIMAGE_PATH" "$APPIMAGE_PATH.sha256"
        [ -n "$APPIMAGE_APPDIR" ] && rm -rf "$(dirname "$APPIMAGE_APPDIR")"
        [ -n "$APPIMAGE_WRAPPER" ] && rm -f "$APPIMAGE_WRAPPER"
        rm -f "$APPIMAGE_MANIFEST"
        log "  ${GREEN}[✓]${NC} AppImage removed"
    fi

    log "${GREEN}[✓] Uninstall complete.${NC}"
    exit 0
fi

[ "$1" == "local" ] && shift

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# Distro Detection and Selection
detect_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

DISTRO_ID=$(detect_distro)

# Distro display names
declare -A DISTRO_NAMES=(
    [solus]="Solus"
    [fedora]="Fedora"
    [arch]="Arch Linux"
    [ubuntu]="Ubuntu"
    [debian]="Debian"
    [opensuse]="openSUSE"
    [nixos]="NixOS"
    [pop]="Pop!_OS"
    [cachyos]="CachyOS"
    [linuxmint]="Linux Mint"
)

get_distro_display_name() {
    local id="$1"
    echo "${DISTRO_NAMES[$id]:-$id}"
}

# Package Manager Detection
detect_package_manager() {
    for pm in eopkg apt-get dnf pacman zypper apk nix-env emerge; do
        if command -v "$pm" &> /dev/null; then
            echo "$pm"
            return 0
        fi
    done
    return 1
}

package_manager_command() {
    case "$1" in
        eopkg)    echo "eopkg it" ;;
        apt-get)  echo "apt-get install -y" ;;
        dnf)      echo "dnf install -y" ;;
        pacman)   echo "pacman -S --noconfirm" ;;
        zypper)   echo "zypper install -y" ;;
        apk)      echo "apk add" ;;
        nix-env)  echo "nix-env -iA nixpkgs" ;;
        emerge)   echo "emerge --ask=n" ;;
    esac
}

PACKAGE_MANAGER=$(detect_package_manager || true)

if [ "$(id -u)" -eq 0 ]; then
    SUDO_PREFIX=""
else
    if ! command -v sudo &> /dev/null; then
        log "${RED}Package installation requires sudo or root. Aborting.${NC}"
        exit 1
    fi
    SUDO_PREFIX="sudo"
fi

install_packages() {
    [ -n "$PACKAGE_MANAGER" ] || return 1
    local -a pm_args
    read -r -a pm_args <<< "$(package_manager_command "$PACKAGE_MANAGER")"
    if [ -n "$SUDO_PREFIX" ]; then
        sudo "${pm_args[@]}" "$@"
    else
        "${pm_args[@]}" "$@"
    fi
}

# Conky version check: 0 = >= 1.24.3, 1 = >= 1.23.0 but < 1.24.3, 2 = < 1.23.0 or unknown
check_conky_version() {
    CONKY_VERSION=$(conky --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -z "$CONKY_VERSION" ]; then
        CONKY_VERSION="unknown"
        return 2
    fi
    local major minor patch
    major=$(echo "$CONKY_VERSION" | cut -d. -f1)
    minor=$(echo "$CONKY_VERSION" | cut -d. -f2)
    patch=$(echo "$CONKY_VERSION" | cut -d. -f3)
    patch=${patch:-0}
    if [ "$major" -gt 1 ] || { [ "$major" -eq 1 ] && [ "$minor" -ge 23 ]; }; then
        if [ "$major" -gt 1 ] || { [ "$major" -eq 1 ] && [ "$minor" -gt 24 ]; } \
            || { [ "$major" -eq 1 ] && [ "$minor" -eq 24 ] && [ "$patch" -ge 3 ]; }; then
            return 0
        fi
        return 1
    fi
    return 2
}

# Compare two version strings: returns 0 if $1 >= $2
version_gte() {
    local IFS='.'
    # shellcheck disable=SC2206
    local -a v1=($1) v2=($2)
    local i a b
    for i in 0 1 2; do
        a=${v1[$i]:-0}
        b=${v2[$i]:-0}
        if (( a > b )); then return 0; fi
        if (( a < b )); then return 1; fi
    done
    return 0
}

# Query available conky version from the distro's repository
query_repo_conky_version() {
    if command -v pacman &>/dev/null; then
        pacman -Si conky 2>/dev/null | grep -i "^Version" | awk '{print $3}' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
    elif command -v dnf &>/dev/null; then
        dnf info conky 2>/dev/null | grep -i "^Version" | awk '{print $3}' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
    elif command -v apt-cache &>/dev/null; then
        apt-cache policy conky 2>/dev/null | grep -i "Candidate:" | awk '{print $2}' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
    elif command -v zypper &>/dev/null; then
        zypper info conky 2>/dev/null | grep -i "^Version" | awk '{print $2}' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
    elif command -v eopkg &>/dev/null; then
        eopkg info conky 2>/dev/null | grep -i "version" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
    elif command -v nix-env &>/dev/null; then
        nix-env -qa conky 2>/dev/null | grep -oE 'conky-[0-9]+\.[0-9]+\.[0-9]+' | sed 's/conky-//' | head -1
    elif command -v portageq &>/dev/null; then
        portageq best_visible / net-misc/conky 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
    fi
    return 0
}

# Conky AppImage support
APPIMAGE_DIR_BASE="$HOME/.local/share/conky"

resolve_latest_conky() {
    curl -fsSL --max-time 15 \
        "https://api.github.com/repos/sniper1720/conky/releases/latest" 2>/dev/null \
        | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"v[0-9]+\.[0-9]+\.[0-9]+(-patched\.[0-9]+)?"' \
        | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+(-patched\.[0-9]+)?' \
        | head -1 || true
}

is_musl() {
    if command -v ldd &> /dev/null && ldd --version 2>&1 | grep -qi musl; then
        return 0
    fi
    [ -f /etc/alpine-release ]
}

glibc_version_ok() {
    local glibc_version
    glibc_version=$(ldd --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    [ -n "$glibc_version" ] || return 1
    awk -v version="$glibc_version" 'BEGIN { split(version, part, "."); exit (part[1] < 2 || (part[1] == 2 && part[2] < 35)) }'
}

appimage_supported() {
    if [ "$(uname -m)" != "x86_64" ]; then
        log "  ${RED}[✗] x86_64 only (detected $(uname -m))${NC}"
        return 1
    fi
    if is_musl; then
        log "  ${RED}[✗] glibc required (musl detected)${NC}"
        return 1
    fi
    if ! glibc_version_ok; then
        log "  ${RED}[✗] glibc 2.35+ required${NC}"
        return 1
    fi
    if ! command -v sha256sum &> /dev/null; then
        log "  ${RED}[✗] sha256sum required${NC}"
        return 1
    fi
    return 0
}

# Screen-size probes
probe_display_config_size() {
    local bus_name object_path interface state result
    bus_name=$1
    object_path=$2
    interface=$3
    command -v busctl &> /dev/null || return 0
    command -v jq &> /dev/null || return 0
    state=$(busctl --user call "$bus_name" "$object_path" "$interface" \
        GetCurrentState --json=short 2>/dev/null) || return 0
    result=$(printf '%s' "$state" | jq -r '
        . as $root
        | [.data[2][] | select(.[4] == true)] | .[0] as $lm
        | $lm[5][0][0] as $conn
        | $root.data[1][] | select(.[0][0] == $conn)
        | .[1][] | select(.[6]["is-current"]["data"] == true)
        | "\(((.[1] / $lm[2]) | round))x\(((.[2] / $lm[2]) | round))"') || return 0
    [[ "$result" =~ ^[0-9]+x[0-9]+$ ]] || return 0
    printf '%s' "$result"
}

probe_mutter_size() {
    probe_display_config_size org.gnome.Mutter.DisplayConfig \
        /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig
}

probe_cinnamon_size() {
    probe_display_config_size org.cinnamon.Muffin.DisplayConfig \
        /org/cinnamon/Muffin/DisplayConfig org.cinnamon.Muffin.DisplayConfig
}

probe_wlr_randr_size() {
    command -v wlr-randr &> /dev/null || return 0
    command -v jq &> /dev/null || return 0
    local result
    result=$(wlr-randr --json 2>/dev/null | jq -r '
        [.[] | select(.enabled == true) | . as $o
         | (.modes[] | select(.current == true)
            | "\((.width / $o.scale) | round)x\((.height / $o.scale) | round)")] |
        .[0]')
    [[ "$result" =~ ^[0-9]+x[0-9]+$ ]] || return 0
    printf '%s' "$result"
}

probe_kscreen_size() {
    command -v kscreen-doctor &> /dev/null || return 0
    command -v jq &> /dev/null || return 0
    local result
    result=$(kscreen-doctor -j 2>/dev/null | jq -r '
        [.outputs[] | select(.enabled == true and .connected == true)] |
        sort_by(.priority) |
        .[0] |
        "\(((.size.width / .scale) | round))x\(((.size.height / .scale) | round))"')
    [[ "$result" =~ ^[0-9]+x[0-9]+$ ]] || return 0
    printf '%s' "$result"
}

probe_hyprland_size() {
    command -v hyprctl &> /dev/null || return 0
    command -v jq &> /dev/null || return 0
    local result
    result=$(hyprctl monitors -j 2>/dev/null | jq -r '
        [.[] | select(.focused == true)] |
        .[0] |
        "\(((.width / .scale) - (.reserved[0] + .reserved[2])) | round)x\(((.height / .scale) - (.reserved[1] + .reserved[3])) | round)"')
    [[ "$result" =~ ^[0-9]+x[0-9]+$ ]] || return 0
    printf '%s' "$result"
}

detect_screen_size() {
    SCREEN_WIDTH=""
    SCREEN_HEIGHT=""
    XINERAMA_HEAD=""
    local size desktop probe_result
    size=""

    if [ "$CURRENT_SESSION" == "wayland" ]; then
        probe_result=""
        desktop=$(printf '%s' "${XDG_CURRENT_DESKTOP:-}" | tr '[:upper:]' '[:lower:]')
        case "$desktop" in
            *gnome*)         probe_result=$(probe_mutter_size) ;;
            *kde*|*plasma*)  probe_result=$(probe_kscreen_size) ;;
            *hyprland*)      probe_result=$(probe_hyprland_size) ;;
            *cinnamon*)      probe_result=$(probe_cinnamon_size) ;;
            *sway*|*wayfire*|*river*|*niri*)
                             probe_result=$(probe_wlr_randr_size) ;;
        esac
        if [ -z "$probe_result" ]; then
            probe_result=$(probe_mutter_size)
            if [ -z "$probe_result" ]; then probe_result=$(probe_cinnamon_size); fi
            if [ -z "$probe_result" ]; then probe_result=$(probe_wlr_randr_size); fi
            if [ -z "$probe_result" ]; then probe_result=$(probe_kscreen_size); fi
            if [ -z "$probe_result" ]; then probe_result=$(probe_hyprland_size); fi
        fi
        size=$probe_result
    else
        local workarea desktop_no
        workarea=$(xprop -root _NET_WORKAREA 2>/dev/null) || true
        if [ -n "$workarea" ]; then
            desktop_no=$(xprop -root _NET_CURRENT_DESKTOP 2>/dev/null | sed -nE 's/^_NET_CURRENT_DESKTOP[^=]*= *([0-9]+).*/\1/p' | head -1)
            desktop_no=${desktop_no:-0}
            size=$(printf '%s' "$workarea" | awk -v d="$desktop_no" '{
                sub(/^.*= */, "")
                gsub(/, */, " ")
                i = d * 4 + 1
                if (i + 3 <= NF) printf "%sx%s", $(i+2), $(i+3)
            }')
        fi
        if [ -z "$size" ] && command -v xdpyinfo &> /dev/null; then
            size=$(xdpyinfo 2>/dev/null | awk '/dimensions:/{print $2; exit}')
        fi
        local heads
        heads=""
        if command -v xdpyinfo &> /dev/null; then
            heads=$(xdpyinfo -ext XINERAMA 2>/dev/null | sed -nE 's/^[[:space:]]*head #([0-9]+): ([0-9]+)x([0-9]+).*/\1 \2 \3/p')
        fi
        if [ "$(printf '%s\n' "$heads" | sed '/^$/d' | wc -l)" -ge 2 ]; then
            local primary_head
            primary_head=$(printf '%s\n' "$heads" | grep -E '^0 ' | head -1)
            if [ -n "$primary_head" ]; then
                local -a head_fields
                read -r -a head_fields <<< "$primary_head"
                XINERAMA_HEAD=${head_fields[0]}
                SCREEN_WIDTH=${head_fields[1]}
                SCREEN_HEIGHT=${head_fields[2]}
                return 0
            fi
        fi
    fi

    if [ -n "$size" ]; then
        SCREEN_WIDTH=${size%x*}
        SCREEN_HEIGHT=${size#*x}
    fi
}

install_appimage() {
    APPIMAGE_VERSION=$(resolve_latest_conky)
    APPIMAGE_VERSION=${APPIMAGE_VERSION:-1.24.3-patched.1}
    APPIMAGE_ASSET="conky-x86_64-${APPIMAGE_VERSION}-release.AppImage"
    APPIMAGE_PATH="$APPIMAGE_DIR_BASE/${APPIMAGE_ASSET}"
    APPIMAGE_DIR="$APPIMAGE_DIR_BASE/conky-${APPIMAGE_VERSION}"
    APPIMAGE_APPDIR="$APPIMAGE_DIR/squashfs-root"
    APPIMAGE_URL="https://github.com/sniper1720/conky/releases/download/${APPIMAGE_VERSION}/${APPIMAGE_ASSET}"

    mkdir -p "$APPIMAGE_DIR_BASE"

    log "  ${BLUE}Downloading Conky ${APPIMAGE_VERSION} (~30 MB)...${NC}"
    if ! curl -fL --retry 3 -o "$APPIMAGE_PATH" "$APPIMAGE_URL"; then
        log "  ${RED}[✗] Download failed${NC}"
        rm -f "$APPIMAGE_PATH" "$APPIMAGE_PATH.sha256"
        return 1
    fi
    if ! curl -fL --retry 3 -o "$APPIMAGE_PATH.sha256" "$APPIMAGE_URL.sha256"; then
        log "  ${RED}[✗] Checksum download failed${NC}"
        return 1
    fi

    log "  ${BLUE}Verifying checksum...${NC}"
    local expected_sha actual_sha
    expected_sha=$(awk '{print $1}' "$APPIMAGE_PATH.sha256")
    actual_sha=$(sha256sum "$APPIMAGE_PATH" | awk '{print $1}')
    if [ -z "$expected_sha" ] || [ "${expected_sha,,}" != "${actual_sha,,}" ]; then
        log "  ${RED}[✗] Checksum mismatch${NC}"
        rm -f "$APPIMAGE_PATH" "$APPIMAGE_PATH.sha256"
        return 1
    fi
    log "  ${GREEN}[✓]${NC} Checksum verified"

    chmod +x "$APPIMAGE_PATH"

    log "  ${BLUE}Extracting...${NC}"
    rm -rf "$APPIMAGE_DIR"
    mkdir -p "$APPIMAGE_DIR"
    if ! (cd "$APPIMAGE_DIR" && "$APPIMAGE_PATH" --appimage-extract > /dev/null 2>&1); then
        log "  ${RED}[✗] Extraction failed${NC}"
        return 1
    fi
    if [ ! -x "$APPIMAGE_APPDIR/AppRun" ]; then
        log "  ${RED}[✗] No AppRun found${NC}"
        return 1
    fi

    log "  ${BLUE}Verifying features...${NC}"
    local appimage_features
    appimage_features=$("$APPIMAGE_APPDIR/AppRun" --version 2>&1) || {
        log "  ${RED}[✗] Binary failed to run${NC}"
        return 1
    }
    echo "$appimage_features" | grep -qi "conky" || {
        log "  ${RED}[✗] Unexpected output${NC}"
        return 1
    }
    for feature in Lua Cairo X11; do
        echo "$appimage_features" | grep -qi "$feature" || {
            log "  ${RED}[✗] Missing $feature${NC}"
            return 1
        }
    done
    if ! echo "$appimage_features" | grep -qi "Wayland"; then
        log "  ${YELLOW}[!] No Wayland support (needs XWayland)${NC}"
    fi

    log "  ${GREEN}[✓]${NC} AppImage $APPIMAGE_VERSION ready"
    return 0
}

write_appimage_launcher() {
    local pause_args=""
    [ "$CURRENT_SESSION" == "wayland" ] && pause_args="--pause=5"
    cat > "$APPIMAGE_WRAPPER" << EOF
#!/bin/sh
# Distro Conky Themes launcher for the Conky AppImage
export APPDIR="$APPIMAGE_APPDIR"
export APPIMAGE="$APPIMAGE_PATH"
export LUA_CPATH="\$APPDIR/usr/lib/conky/lib?.so;;"
exec "\$APPDIR/AppRun" $pause_args -c "$INSTALL_DIR/conky.conf"
EOF
    chmod +x "$APPIMAGE_WRAPPER"
}

write_appimage_manifest() {
    cat > "$APPIMAGE_MANIFEST" << EOF
APPIMAGE_VERSION=$APPIMAGE_VERSION
APPIMAGE_PATH="$APPIMAGE_PATH"
APPIMAGE_APPDIR="$APPIMAGE_APPDIR"
APPIMAGE_WRAPPER="$APPIMAGE_WRAPPER"
EOF
}

reuse_installed_appimage() {
    [ -f "$APPIMAGE_MANIFEST" ] || return 1
    # shellcheck disable=SC1090
    . "$APPIMAGE_MANIFEST"
    [ -n "$APPIMAGE_VERSION" ] || return 1
    [ -x "$APPIMAGE_APPDIR/AppRun" ] || return 1
    [ -f "$APPIMAGE_PATH" ] || return 1
    local features version major minor
    features=$("$APPIMAGE_APPDIR/AppRun" --version 2>&1) || return 1
    echo "$features" | grep -qi "conky" || return 1
    version=$(echo "$features" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -n "$version" ] || return 1
    major=$(echo "$version" | cut -d. -f1)
    minor=$(echo "$version" | cut -d. -f2)
    [ "$major" -gt 1 ] || { [ "$major" -eq 1 ] && [ "$minor" -ge 23 ]; } || return 1
    for feature in Lua Cairo X11; do
        echo "$features" | grep -qi "$feature" || return 1
    done
    return 0
}

ensure_appimage() {
    if reuse_installed_appimage; then
        log "  ${GREEN}[✓]${NC} AppImage $APPIMAGE_VERSION ready"
        USE_APPIMAGE=true
        APPIMAGE_WRAPPER="$HOME/.config/conky/conky-run"
        return 0
    fi
    return 1
}

offer_appimage() {
    local reason="${1:-}"
    log
    if [ -n "$reason" ]; then
        log "  ${YELLOW}[!]${NC} $reason"
        log
    fi
    log "  A patched AppImage gives you the fixed Conky without touching your system packages."
    local reply
    read -p "  Download now? [y/N] " -r reply < /dev/tty
    log
    if ! [[ $reply =~ ^[Yy] ]]; then
        log "  ${YELLOW}Skipped.${NC}"
        return 1
    fi
    if ! appimage_supported; then
        log "  ${RED}AppImage not supported on this system.${NC}"
        return 1
    fi
    if install_appimage; then
        USE_APPIMAGE=true
        APPIMAGE_WRAPPER="$HOME/.config/conky/conky-run"
        return 0
    else
        log "  ${RED}AppImage install failed.${NC}"
        return 1
    fi
}

log "${CYAN}"
log " :'######::' #######::'##::: ##:'##:::'##:'##:::'##:"
log " '##... ##:'##.... ##: ###:: ##: ##::'##::. ##:'##::"
log "  ##:::..:: ##:::: ##: ####: ##: ##:'##::::. ####:::"
log "  ##::::::: ##:::: ##: ## ## ##: #####::::::. ##::::"
log "  ##::::::: ##:::: ##: ##. ####: ##. ##:::::: ##::::"
log "  ##::: ##: ##:::: ##: ##:. ###: ##:. ##::::: ##::::"
log " . ######::. #######:: ##::. ##: ##::. ##:::: ##::::"
log " :......::::.......:::..::::..::..::::..:::::..:::::"
log "${NC}"
log "${BLUE}  Universal Conky Themes Installer${NC}"
sep

# Distro Detection
header "Distribution"

if [ -n "${DISTRO_NAMES[$DISTRO_ID]}" ]; then
    DETECTED_NAME=$(get_distro_display_name "$DISTRO_ID")
    log "  Detected: ${CYAN}$DETECTED_NAME${NC}"
    read -p "  Use detected distro ($DETECTED_NAME)? [Y/n]: " -r CONFIRM_DISTRO < /dev/tty
    if [[ $CONFIRM_DISTRO =~ ^[Nn] ]]; then
        DETECTED_NAME=""
    fi
fi

if [ -z "${DETECTED_NAME:-}" ]; then
    log
    log "  ${GREEN}1)${NC}  Solus"
    log "  ${GREEN}2)${NC}  Fedora"
    log "  ${GREEN}3)${NC}  Arch Linux"
    log "  ${GREEN}4)${NC}  Ubuntu"
    log "  ${GREEN}5)${NC}  Debian"
    log "  ${GREEN}6)${NC}  openSUSE"
    log "  ${GREEN}7)${NC}  NixOS"
    log "  ${GREEN}8)${NC}  Pop!_OS"
    log "  ${GREEN}9)${NC}  CachyOS"
    log "  ${GREEN}10)${NC} Linux Mint"
    log
    read -p "  Select distro [1-10]: " -r DISTRO_CHOICE < /dev/tty

    case $DISTRO_CHOICE in
        1) DISTRO_ID="solus" ;;
        2) DISTRO_ID="fedora" ;;
        3) DISTRO_ID="arch" ;;
        4) DISTRO_ID="ubuntu" ;;
        5) DISTRO_ID="debian" ;;
        6) DISTRO_ID="opensuse" ;;
        7) DISTRO_ID="nixos" ;;
        8) DISTRO_ID="pop" ;;
        9) DISTRO_ID="cachyos" ;;
        10) DISTRO_ID="linuxmint" ;;
        *) log "${RED}  [✗] Invalid choice. Defaulting to Solus.${NC}"; DISTRO_ID="solus" ;;
    esac
fi

DISTRO_DISPLAY=$(get_distro_display_name "$DISTRO_ID")
log "  ${GREEN}[✓]${NC} $DISTRO_DISPLAY"

# Session Detection
header "Session"
CURRENT_SESSION="${XDG_SESSION_TYPE:-unknown}"
IS_KDE=false
[[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* || "${XDG_CURRENT_DESKTOP:-}" == *Plasma* ]] && IS_KDE=true

if [ "$CURRENT_SESSION" == "wayland" ] && [ "$IS_KDE" = true ]; then
    log "  ${CYAN}$CURRENT_SESSION${NC}: KDE Plasma Wayland"
elif [ "$CURRENT_SESSION" == "wayland" ] && [[ "$XDG_CURRENT_DESKTOP" == *GNOME* ]]; then
    log "  ${CYAN}$CURRENT_SESSION${NC}: GNOME (always-below window; see README for mutter-layer-shell)"
else
    log "  ${CYAN}$CURRENT_SESSION${NC}: native"
fi

conky_install_command() {
    if command -v pacman &>/dev/null; then
        echo "sudo pacman -S conky"
    elif command -v dnf &>/dev/null; then
        echo "sudo dnf install conky"
    elif command -v apt-get &>/dev/null; then
        echo "sudo apt-get install conky"
    elif command -v zypper &>/dev/null; then
        echo "sudo zypper install conky"
    elif command -v eopkg &>/dev/null; then
        echo "sudo eopkg install conky"
    elif command -v nix-env &>/dev/null; then
        echo "nix-env -iA nixpkgs.conky"
    elif command -v emerge &>/dev/null; then
        echo "sudo emerge net-misc/conky"
    fi
}

# Dependency Check
header "Dependencies"

# curl
MISSING_DEPS=""
command -v curl &> /dev/null || MISSING_DEPS="$MISSING_DEPS curl"

if [ -n "$MISSING_DEPS" ]; then
    if [ -z "$PACKAGE_MANAGER" ]; then
        log "${RED}  Missing:$MISSING_DEPS. Install manually and re-run${NC}"
        exit 1
    fi
    log "  ${YELLOW}Missing:$MISSING_DEPS${NC}"
    read -p "  Install with $PACKAGE_MANAGER? [y/N] " -r INSTALL_REPLY < /dev/tty
    log
    if [[ $INSTALL_REPLY =~ ^[Yy] ]]; then
        install_packages curl
        log "  ${GREEN}[✓]${NC} curl installed"
    else
        log "  ${YELLOW}Skipped. Install$MISSING_DEPS manually and re-run.${NC}"
        exit 1
    fi
fi

# Conky
log "  Checking Conky..."
CONKY_CHECK=0
set +e
check_conky_version
CONKY_CHECK=$?
set -e

USE_APPIMAGE=false

if [ "$CONKY_CHECK" -eq 0 ]; then
    log "  ${GREEN}[✓]${NC} System Conky $CONKY_VERSION (up to date)"
else
    REPO_CONKY_VERSION=$(query_repo_conky_version || true)

    if [ -n "$REPO_CONKY_VERSION" ]; then
        if version_gte "$REPO_CONKY_VERSION" "1.24.3"; then
            log "  ${GREEN}[✓]${NC} $REPO_CONKY_VERSION available in repo"
            INSTALL_CMD=$(conky_install_command)
            if [ -n "$INSTALL_CMD" ]; then
                log "    Install with: ${CYAN}$INSTALL_CMD${NC}"
            fi
            read -p "  Install system Conky now? [Y/n] " -r INSTALL_CONKY_REPLY < /dev/tty
            if [[ ! $INSTALL_CONKY_REPLY =~ ^[Nn] ]]; then
                log "  Installing Conky $REPO_CONKY_VERSION..."
                if [ -n "$PACKAGE_MANAGER" ] && install_packages conky; then
                    log "  ${GREEN}[✓]${NC} System Conky installed"
                else
                    log "  ${YELLOW}[!]${NC} Install failed, using AppImage"
                    ensure_appimage || offer_appimage "System Conky install failed" || { log "${RED}No usable Conky found. Aborting.${NC}"; exit 1; }
                fi
            else
                log "  ${YELLOW}Skipped, using AppImage.${NC}"
                ensure_appimage || offer_appimage "System Conky install skipped" || { log "${RED}No usable Conky found. Aborting.${NC}"; exit 1; }
            fi
        elif version_gte "$REPO_CONKY_VERSION" "1.23.0"; then
            ensure_appimage || offer_appimage "Repo Conky $REPO_CONKY_VERSION has known Wayland bugs (fixed in 1.24.3)" || log "  ${YELLOW}[!]${NC} Continuing with system Conky $CONKY_VERSION.${NC}"
        else
            ensure_appimage || offer_appimage "Repo Conky $REPO_CONKY_VERSION is too old for these themes (need ≥ 1.23.0)" || { log "${RED}No usable Conky found. Aborting.${NC}"; exit 1; }
        fi
    else
        ensure_appimage || offer_appimage "Could not query the repo Conky version" || { log "${RED}No usable Conky found. Aborting.${NC}"; exit 1; }
    fi
fi

# Theme Selection
header "Theme"
log "  ${GREEN}1)${NC}  Octopus  ${DIM}: Dashboard, Cairo curves${NC}"
log "  ${GREEN}2)${NC}  Pure     ${DIM}: Sidebar, bars and metrics${NC}"
log
read -p "  Select theme [1-2]: " -r THEME_CHOICE < /dev/tty

case $THEME_CHOICE in
    2) THEME_DIR="pure"; THEME_NAME="pure"; USE_LUA=false ;;
    *) THEME_DIR="octopus"; THEME_NAME="octopus"; USE_LUA=true ;;
esac

# Sidebar Position (Pure only)
SIDEBAR_SIDE="right"
if [ "$THEME_DIR" = "pure" ]; then
    log
    log "  Sidebar position:"
    log "    ${GREEN}1)${NC}  Right ${DIM}(default)${NC}"
    log "    ${GREEN}2)${NC}  Left"
    log
    read -p "  Select position [1-2]: " -r SIDE_CHOICE < /dev/tty
    case $SIDE_CHOICE in
        2) SIDEBAR_SIDE="left" ;;
    esac
fi

INSTALL_DIR="$HOME/.config/conky/$THEME_NAME"
CONFIG_FILE="$INSTALL_DIR/conky.conf"

log "  ${GREEN}[✓]${NC} $THEME_NAME"

if [ ! -d "$THEME_DIR" ]; then
    log "${RED}Error: Theme directory '$THEME_DIR' not found.${NC}"
    exit 1
fi

# Font Installation
header "Fonts"
mkdir -p "$HOME/.local/share/fonts"
mkdir -p "$HOME/.config/conky"
touch "$FONT_MANIFEST"
if [ -d "assets/fonts" ]; then
    for font_file in assets/fonts/*.ttf; do
        [ -f "$font_file" ] || continue
        font_family=$(fc-scan --format='%{family[0]}\n' "$font_file" 2>/dev/null | head -1)
        if [ -n "$font_family" ] && fc-list : family 2>/dev/null | grep -qx "$font_family"; then
            log "  ${DIM}$font_family already installed, skipping${NC}"
            continue
        fi
        cp "$font_file" "$HOME/.local/share/fonts/"
        basename "$font_file" >> "$FONT_MANIFEST"
        log "  ${GREEN}[✓]${NC} Installed $font_family"
    done
fi
if command -v fc-cache &>/dev/null; then
    fc-cache -f &>/dev/null || true
fi

# Theme Installation
header "Installing"
[ -d "$INSTALL_DIR" ] && rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r "$THEME_DIR/"* "$INSTALL_DIR/"

log "  ${GREEN}[✓]${NC} $INSTALL_DIR"

# Branding
header "Branding"

# Distro Logo Swapping
if [ "$USE_LUA" = true ]; then
    DISTRO_LOGO="distros/$DISTRO_ID/logo.png"
    if [ -f "$DISTRO_LOGO" ]; then
        cp "$DISTRO_LOGO" "$INSTALL_DIR/assets/dark/linux.png"
        cp "$DISTRO_LOGO" "$INSTALL_DIR/assets/white/linux.png"
        log "  ${GREEN}[✓]${NC} $DISTRO_DISPLAY logo"
    else
        log "  ${YELLOW}[!]${NC} Logo not found for $DISTRO_DISPLAY, using default"
    fi
fi

# Pure Theme Color Injection
if [ "$USE_LUA" = false ] && [ -f "distros/$DISTRO_ID/colors.sh" ]; then
    # shellcheck disable=SC1091
    . "distros/$DISTRO_ID/colors.sh"
    COLOR_PRIMARY="${DISTRO_COLOR_PRIMARY:-${COLOR1:-}}"
    COLOR_LIGHT="${DISTRO_COLOR_LIGHT:-${COLOR2:-}}"
    COLOR_MUTED="${DISTRO_COLOR_MUTED:-${COLOR3:-}}"
    if [ -n "$COLOR_PRIMARY" ] && [ -n "$COLOR_LIGHT" ] && [ -n "$COLOR_MUTED" ]; then
        DISTRO_HEADER_UP="$(get_distro_display_name "$DISTRO_ID")"
        DISTRO_HEADER_UP="${DISTRO_HEADER_UP^^}"
        sed -i "s/LINUX/$DISTRO_HEADER_UP/" "$CONFIG_FILE"
        sed -i "s/local solus_blue = \"[^\"]*\"/local solus_blue = \"$COLOR_PRIMARY\"/" "$CONFIG_FILE"
        sed -i "s/local solus_light = \"[^\"]*\"/local solus_light = \"$COLOR_LIGHT\"/" "$CONFIG_FILE"
        sed -i "s/local solus_muted = \"[^\"]*\"/local solus_muted = \"$COLOR_MUTED\"/" "$CONFIG_FILE"
        log "  ${GREEN}[✓]${NC} $DISTRO_DISPLAY brand"
    else
        log "  ${YELLOW}[!]${NC} Brand incomplete for $DISTRO_DISPLAY, using defaults"
    fi
fi

# Desktop Layer Configuration
header "Layer"
if [ "$CURRENT_SESSION" = "wayland" ]; then
    if [ "$IS_KDE" = true ]; then
        sed -i "s/own_window_type = 'normal'/own_window_type = 'desktop'/" "$CONFIG_FILE"
        sed -i "s/own_window_hints = 'undecorated,sticky,skip_taskbar,skip_pager,below'/own_window_hints = 'undecorated,sticky,skip_taskbar,skip_pager'/" "$CONFIG_FILE"
        log "  ${GREEN}[✓]${NC} Desktop layer: desktop type (KDE Wayland)"
    else
        log "  ${GREEN}[✓]${NC} Desktop layer: normal + below (BOTTOM layer)"
    fi
else
    log "  Desktop layer:"
    log "    ${GREEN}1)${NC}  normal + below ${DIM}(default)${NC}"
    log "    ${GREEN}2)${NC}  desktop type ${DIM}(stays on Show Desktop)${NC}"
    log
    read -p "  Choice [1]: " -r LAYER_CHOICE < /dev/tty

    if [ "$LAYER_CHOICE" = "2" ]; then
        sed -i "s/own_window_type = 'normal'/own_window_type = 'desktop'/" "$CONFIG_FILE"
        sed -i "s/own_window_hints = 'undecorated,sticky,skip_taskbar,skip_pager,below'/own_window_hints = 'undecorated,sticky,skip_taskbar,skip_pager'/" "$CONFIG_FILE"
        log "  ${GREEN}[✓]${NC} Desktop type (stays on Show Desktop)"
    else
        log "  ${GREEN}[✓]${NC} Normal + below (right-click works)"
    fi
fi

# Configuration
header "Configuration"

log "  Network interfaces:"
ip -o link show | awk -F': ' '$2 != "lo" {print $2}' | sed 's/^/    /'
read -p "  Interface [wlan0]: " -r USER_INTERFACE < /dev/tty
USER_INTERFACE=${USER_INTERFACE:-wlan0}

BASE_WIDTH=1920; BASE_HEIGHT=1080
detect_screen_size

if ! [[ "$SCREEN_WIDTH" =~ ^[0-9]{3,5}$ ]] || ! [[ "$SCREEN_HEIGHT" =~ ^[0-9]{3,5}$ ]] \
    || [ "$SCREEN_WIDTH" -lt 320 ] || [ "$SCREEN_HEIGHT" -lt 200 ] \
    || [ "$SCREEN_WIDTH" -gt 16384 ] || [ "$SCREEN_HEIGHT" -gt 16384 ]; then
    SCREEN_WIDTH=""
    SCREEN_HEIGHT=""
fi

if [ "$USE_LUA" = true ]; then
    if [ -n "$SCREEN_WIDTH" ] && [ -n "$SCREEN_HEIGHT" ]; then
        SETTINGS_FILE="$INSTALL_DIR/settings.lua"
        sed -i "s/width = [0-9]*/width = $SCREEN_WIDTH/" "$SETTINGS_FILE"
        sed -i "s/height = [0-9]*/height = $SCREEN_HEIGHT/" "$SETTINGS_FILE"
        log "  ${GREEN}[✓]${NC} Screen: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}"
    else
        log "  ${YELLOW}[!]${NC} Screen size unknown, using default ${BASE_WIDTH}x${BASE_HEIGHT}"
    fi
fi

# Multi-monitor X11
if [ -n "$XINERAMA_HEAD" ]; then
    if [ "$USE_LUA" = true ]; then
        sed -i "s/minimum_height = settings.height,/minimum_height = settings.height,\n    xinerama_head = $XINERAMA_HEAD,/" "$CONFIG_FILE"
    else
        sed -i "s/maximum_width = width,/maximum_width = width,\n    xinerama_head = $XINERAMA_HEAD,/" "$CONFIG_FILE"
    fi
fi

if [ "$USE_LUA" = true ]; then
    SETTINGS_FILE="$INSTALL_DIR/settings.lua"

    log
    log "  Theme mode:"
    log "    ${GREEN}1)${NC}  Dark"
    log "    ${GREEN}2)${NC}  White"
    log
    read -p "  Choice [1]: " -r MODE_CHOICE < /dev/tty
    [ "${MODE_CHOICE:-}" == "2" ] && THEME_MODE="WHITE" || THEME_MODE="DARK"

    sed -i "s/network_interface = \"[^\"]*\"/network_interface = \"$USER_INTERFACE\"/" "$SETTINGS_FILE"
    sed -i "s/theme_mode = \"[^\"]*\"/theme_mode = \"$THEME_MODE\"/" "$SETTINGS_FILE"

    log
    read -p "  Maildir path (empty to skip): " -r USER_MAILDIR < /dev/tty
    if [ -n "$USER_MAILDIR" ]; then
        sed -i "s|mail_dir = \"[^\"]*\"|mail_dir = \"$USER_MAILDIR\"|" "$SETTINGS_FILE"
        log "  ${GREEN}[✓]${NC} Mail: $USER_MAILDIR"
    else
        sed -i "s|mail_dir = \"[^\"]*\"|mail_dir = \"\"|" "$SETTINGS_FILE"
    fi
else
    sed -i "s/local network_interface = \"[^\"]*\"/local network_interface = \"$USER_INTERFACE\"/" "$CONFIG_FILE"

    if [ "$SIDEBAR_SIDE" = "left" ]; then
        sed -i "s/alignment = 'middle_right'/alignment = 'middle_left'/" "$CONFIG_FILE"
    fi

    CPU_CORES=$(nproc --all 2>/dev/null || echo 8)
    [ "$CPU_CORES" -lt 1 ] && CPU_CORES=1
    [ "$CPU_CORES" -gt 32 ] && CPU_CORES=32

    CORE_FILE=$(mktemp)
    ROW_COUNT=0
    ROW=""
    for i in $(seq 1 "$CPU_CORES"); do
        ENTRY="Core $i: \${cpu cpu$i}%"
        if (( i % 4 == 1 )); then
            ROW="$ENTRY"
        else
            ROW="$ROW  $ENTRY"
        fi
        if (( i % 4 == 0 )) || [ "$i" -eq "$CPU_CORES" ]; then
            VOFFSET=2
            [ "$ROW_COUNT" -gt 0 ] && VOFFSET=1
            printf '${voffset %d}${font Roboto:size=]] .. font_small .. [[}${color2}%s${color}${font}\n' \
                "$VOFFSET" "$ROW" >> "$CORE_FILE"
            ROW=""
            ROW_COUNT=$((ROW_COUNT + 1))
        fi
    done

    sed -i "/Core.*cpu cpu/d" "$CONFIG_FILE"
    sed -i "/cpubar cpu0/r $CORE_FILE" "$CONFIG_FILE"
    rm -f "$CORE_FILE"
    CORE_FILE=""
    log "  ${GREEN}[✓]${NC} $CPU_CORES CPU cores"
fi

if [ "$USE_APPIMAGE" = true ]; then
    write_appimage_launcher
    write_appimage_manifest
    log "  ${GREEN}[✓]${NC} AppImage launcher saved"
fi

# Autostart
header "Autostart"
read -p "  Start at login? [y/N] " -r AUTOSTART_REPLY < /dev/tty
log

AUTOSTART_DIR="$HOME/.config/autostart"
DESKTOP_FILE="$AUTOSTART_DIR/conky-themes.desktop"

if [[ $AUTOSTART_REPLY =~ ^[Yy] ]]; then
    mkdir -p "$AUTOSTART_DIR"
    if [ "$USE_APPIMAGE" = true ]; then
        DESKTOP_EXEC="$APPIMAGE_WRAPPER"
    else
        DESKTOP_EXEC="conky -c $INSTALL_DIR/conky.conf"
    fi
    cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Type=Application
Name=Conky Themes ($DISTRO_DISPLAY $THEME_NAME)
Exec=$DESKTOP_EXEC
Hidden=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
Terminal=false
EOF
    log "  ${GREEN}[✓]${NC} Autostart enabled"
else
    [ -f "$DESKTOP_FILE" ] && rm -f "$DESKTOP_FILE"
fi

# Start Now
header "Start"
read -p "  Start now? [y/N] " -r START_REPLY < /dev/tty
log

if [[ $START_REPLY =~ ^[Yy] ]]; then
    pkill -u "$UID" -f "$INSTALL_DIR/conky.conf" 2>/dev/null || true
    sleep 0.5
    if [ "$USE_APPIMAGE" = true ]; then
        setsid "$APPIMAGE_WRAPPER" &>/dev/null &
    else
        setsid conky -c "$INSTALL_DIR/conky.conf" &>/dev/null &
    fi
    log "  ${GREEN}[✓]${NC} Running"
fi

log
sep
log "  ${BOLD}Installed${NC}"
log "    Theme:    ${CYAN}$THEME_NAME${NC} ($DISTRO_DISPLAY)"
log "    Location: ${CYAN}$INSTALL_DIR${NC}"
if [ "$USE_APPIMAGE" = true ]; then
    log "    Conky:    ${CYAN}AppImage $APPIMAGE_VERSION${NC}"
else
    log "    Conky:    ${CYAN}System $CONKY_VERSION${NC}"
fi
if [[ $AUTOSTART_REPLY =~ ^[Yy] ]]; then
    log "    Autostart: ${GREEN}enabled${NC}"
else
    log "    Autostart: ${DIM}disabled${NC}"
fi
log
log "  ${BOLD}Quick Start${NC}"
if [ "$USE_APPIMAGE" = true ]; then
    log "    Start:    ${CYAN}$APPIMAGE_WRAPPER${NC}"
else
    log "    Start:    ${CYAN}conky -c $INSTALL_DIR/conky.conf${NC}"
fi
log "    Stop:     ${CYAN}pkill -f \"$INSTALL_DIR/conky.conf\"${NC}"
log "    Uninstall:${CYAN} bash setup.sh --uninstall${NC}"
sep
log "${CYAN}  Enjoy!${NC}"
