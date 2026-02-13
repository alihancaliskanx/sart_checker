#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

KNOWN_DIR="$PROJECT_DIR/known"
RECENT_DIR="$PROJECT_DIR/recent"
LOG_DIR="$PROJECT_DIR/log"
LOG_FILE="$LOG_DIR/sart_checker.log"
LOG_PREFIX="[sart_checker]"

log_info()  { echo "$LOG_PREFIX [INFO]  $(date '+%Y-%m-%d %H:%M:%S') — $*" >&2; }
log_warn()  { echo "$LOG_PREFIX [WARN]  $(date '+%Y-%m-%d %H:%M:%S') — $*" >&2; }
log_error() { echo "$LOG_PREFIX [ERROR] $(date '+%Y-%m-%d %H:%M:%S') — $*" >&2; }

SOURCES=(
    "https://www.teknofest.org/tr/yarismalar/insansiz-su-alti-sistemleri-yarismasi/|AUV_REPORT.pdf"
    "https://www.teknofest.org/tr/yarismalar/insansiz-deniz-araci-yarismasi/|USV_REPORT.pdf"
    "https://www.teknofest.org/tr/yarismalar/su-alti-roket-yarismasi/|AUR_REPORT.pdf"
)

for cmd in curl grep sha256sum; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "'$cmd' bulunamadi."
        exit 1
    fi
done

# X11/Wayland/DBUS otomatik tespit (systemd service icinden calisma destegi)
setup_display_env() {
    local uid
    uid="$(id -u)"

    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        local dbus_path="/run/user/$uid/bus"
        [[ -S "$dbus_path" ]] && export DBUS_SESSION_BUS_ADDRESS="unix:path=$dbus_path"
    fi

    if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        local wayland_sock
        wayland_sock=$(find "/run/user/$uid/" -maxdepth 1 -name "wayland-*" -type s 2>/dev/null | head -n 1)
        if [[ -n "$wayland_sock" ]]; then
            export WAYLAND_DISPLAY="$(basename "$wayland_sock")"
            export XDG_RUNTIME_DIR="/run/user/$uid"
        fi
    fi

    if [[ -z "${DISPLAY:-}" ]]; then
        if [[ -d /tmp/.X11-unix ]]; then
            local x_sock
            x_sock=$(find /tmp/.X11-unix -name "X*" -type s 2>/dev/null | head -n 1)
            if [[ -n "$x_sock" ]]; then
                export DISPLAY=":$(basename "$x_sock" | sed 's/X//')"
            fi
        fi
    fi

    [[ -z "${XDG_RUNTIME_DIR:-}" ]] && export XDG_RUNTIME_DIR="/run/user/$uid"

    return 0
}

send_notification() {
    local title="$1" body="$2"

    if ! command -v notify-send &>/dev/null; then
        log_warn "notify-send bulunamadi, bildirim sadece log'a yazildi."
        return 0
    fi

    if ! notify-send --urgency=critical --app-name="sart_checker" --icon=dialog-warning "$title" "$body" 2>/dev/null; then
        log_warn "notify-send basarisiz oldu (DISPLAY/DBUS eksik olabilir)"
        return 0
    fi
}

setup_display_env
mkdir -p "$RECENT_DIR" "$LOG_DIR"

CHANGED=()
ERRORS=()

for entry in "${SOURCES[@]}"; do
    URL="${entry%%|*}"
    FILENAME="${entry##*|}"

    log_info "Isleniyor: $FILENAME"

    HTML=""
    if ! HTML=$(curl -sL --max-time 30 --retry 2 "$URL"); then
        log_error "HTML cekilemedi: $URL"
        ERRORS+=("$FILENAME")
        continue
    fi

    PDF_URL=""
    PDF_URL=$(echo "$HTML" | grep -oP 'https://cdn\.teknofest\.org/[^"'"'"'\s<>]+\.pdf' | head -n 1)

    if [[ -z "$PDF_URL" ]]; then
        log_warn "PDF linki bulunamadi: $URL"
        ERRORS+=("$FILENAME")
        continue
    fi

    RECENT_FILE="$RECENT_DIR/$FILENAME"

    if ! curl -sL --max-time 60 --retry 2 -o "$RECENT_FILE" "$PDF_URL"; then
        log_error "PDF indirilemedi: $PDF_URL"
        ERRORS+=("$FILENAME")
        continue
    fi

    if [[ ! -s "$RECENT_FILE" ]]; then
        log_error "Indirilen dosya bos: $RECENT_FILE"
        ERRORS+=("$FILENAME")
        continue
    fi

    log_info "Indirildi: $FILENAME ($(du -h "$RECENT_FILE" | cut -f1))"

    KNOWN_FILE="$KNOWN_DIR/$FILENAME"

    if [[ ! -f "$KNOWN_FILE" ]]; then
        log_warn "Referans dosya yok: $FILENAME"
        continue
    fi

    HASH_KNOWN=$(sha256sum "$KNOWN_FILE" | awk '{print $1}')
    HASH_RECENT=$(sha256sum "$RECENT_FILE" | awk '{print $1}')

    if [[ "$HASH_KNOWN" != "$HASH_RECENT" ]]; then
        log_warn "DEGISIKLIK: $FILENAME"
        CHANGED+=("$FILENAME")
    else
        log_info "Degisiklik yok: $FILENAME"
    fi
done

if [[ ${#CHANGED[@]} -gt 0 ]]; then
    CHANGED_LIST=$(printf ", %s" "${CHANGED[@]}")
    CHANGED_LIST="${CHANGED_LIST:2}"

    send_notification "Sartname Degisikligi Tespit Edildi" "Degisen dosyalar: $CHANGED_LIST"
    log_warn "Degisen: $CHANGED_LIST"
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    ERROR_LIST=$(printf ", %s" "${ERRORS[@]}")
    ERROR_LIST="${ERROR_LIST:2}"
    log_error "Hatali kaynaklar: $ERROR_LIST"
fi

# log/ dizinine 1 satirlik ozet yaz
SUMMARY="$(date '+%Y-%m-%d %H:%M:%S') | changed=${#CHANGED[@]} errors=${#ERRORS[@]} sources=${#SOURCES[@]}"
echo "$SUMMARY" >> "$LOG_FILE"

log_info "Tamamlandi."
