#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

KNOWN_DIR="$PROJECT_DIR/known"
RECENT_DIR="$PROJECT_DIR/recent"
LOG_DIR="$PROJECT_DIR/log"
LOG_FILE="$LOG_DIR/sart_checker.log"
LOG_PREFIX="[sart_checker]"

USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

SOURCES=(
    "https://www.teknofest.org/tr/yarismalar/insansiz-su-alti-sistemleri-yarismasi/|AUV_REPORT.pdf"
    "https://www.teknofest.org/tr/yarismalar/insansiz-deniz-araci-yarismasi/|USV_REPORT.pdf"
    "https://www.teknofest.org/tr/yarismalar/su-alti-roket-yarismasi/|AUR_REPORT.pdf"
)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}$LOG_PREFIX [INFO]  $(date '+%Y-%m-%d %H:%M:%S') — $*${NC}" | tee -a "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}$LOG_PREFIX [WARN]  $(date '+%Y-%m-%d %H:%M:%S') — $*${NC}" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}$LOG_PREFIX [ERROR] $(date '+%Y-%m-%d %H:%M:%S') — $*${NC}" | tee -a "$LOG_FILE"; }

check_deps() {
    local deps=(curl grep sha256sum sed awk notify-send)
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "'$cmd' komutu bulunamadı. Lütfen yükleyin."
            exit 1
        fi
    done
}

setup_display_env() {
    [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && return 0

    local uid
    uid="$(id -u)"

    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus"

    if [[ -z "${DISPLAY:-}" ]]; then
        local x_sock
        x_sock=$(find /tmp/.X11-unix -name "X*" -type s 2>/dev/null | sort | head -n 1)
        if [[ -n "$x_sock" ]]; then
            export DISPLAY=":$(basename "$x_sock" | sed 's/X//')"
        else
            export DISPLAY=":0"
        fi
    fi
    
    if [[ -z "${XAUTHORITY:-}" ]]; then
         local xauth_file
         xauth_file=$(find "/run/user/$uid/" -name "xauth_*" 2>/dev/null | head -n 1) # KDE genelde burada tutar
         if [[ -n "$xauth_file" ]]; then
             export XAUTHORITY="$xauth_file"
         elif [[ -f "$HOME/.Xauthority" ]]; then
             export XAUTHORITY="$HOME/.Xauthority"
         fi
    fi
}

send_notification() {
    local title="$1"
    local body="$2"
    
    if notify-send --urgency=critical --app-name="sart_checker" --icon=dialog-warning "$title" "$body"; then
        log_info "Bildirim gönderildi: $title"
    else
        log_warn "Bildirim gönderilemedi (DBUS/DISPLAY sorunu olabilir)."
    fi
}

main() {
    check_deps
    setup_display_env
    mkdir -p "$RECENT_DIR" "$LOG_DIR" "$KNOWN_DIR"

    log_info "Tarama başlatılıyor..."

    local changed_files=()
    local error_files=()

    for entry in "${SOURCES[@]}"; do
        local url="${entry%%|*}"
        local filename="${entry##*|}"
        local recent_file="$RECENT_DIR/$filename"
        local known_file="$KNOWN_DIR/$filename"

        log_info "Kontrol ediliyor: $filename ($url)"

        local html_content
        if ! html_content=$(curl -sL -A "$USER_AGENT" --max-time 30 --retry 2 "$url"); then
            log_error "Erişim hatası: $url"
            error_files+=("$filename")
            continue
        fi

        local pdf_url=""
        
        pdf_url=$(echo "$html_content" | grep -oP 'href=[\"'"'"']\K[^\"'"'"']+/media/upload/[^\"'"'"']+\.pdf' | head -n 1 || true)
        
        if [[ -z "$pdf_url" ]]; then
             pdf_url=$(echo "$html_content" | grep -oP 'href=[\"'"'"']\K[^\"'"'"']+\.pdf' | head -n 1 || true)
        fi

        if [[ -z "$pdf_url" ]]; then
            log_warn "PDF linki sayfada bulunamadı! ($url)"
            error_files+=("$filename")
            continue
        fi

        if [[ "$pdf_url" == /* ]]; then
            pdf_url="https://www.teknofest.org${pdf_url}"
        elif [[ "$pdf_url" != http* ]]; then
             pdf_url="https://www.teknofest.org/${pdf_url}"
        fi

        log_info "PDF Bulundu: $pdf_url"

        if ! curl -sL -A "$USER_AGENT" --max-time 60 --retry 2 -o "$recent_file" "$pdf_url"; then
            log_error "İndirme başarısız: $pdf_url"
            error_files+=("$filename")
            continue
        fi

        if [[ ! -s "$recent_file" ]]; then
             log_error "İndirilen dosya 0 byte: $filename"
             error_files+=("$filename")
             rm -f "$recent_file"
             continue
        fi

        if [[ ! -f "$known_file" ]]; then
            log_warn "Referans dosya ($filename) 'known/' klasöründe yok. İlk kez çalışıyor olabilir."
            log_info "Lütfen '$recent_file' dosyasını inceleyip '$known_file' olarak kaydedin."
            continue
        fi

        local hash_known
        local hash_recent
        hash_known=$(sha256sum "$known_file" | awk '{print $1}')
        hash_recent=$(sha256sum "$recent_file" | awk '{print $1}')

        if [[ "$hash_known" != "$hash_recent" ]]; then
            log_warn "⚠️ DEĞİŞİKLİK TESPİT EDİLDİ: $filename"
            changed_files+=("$filename")
        else
            log_info "Dosya güncel: $filename"
        fi
    done

    if [[ ${#changed_files[@]} -gt 0 ]]; then
        local msg_list=$(printf ", %s" "${changed_files[@]}")
        msg_list="${msg_list:2}"
        
        send_notification "⚠️ Şartname Değişikliği Tespit Edildi!" "Değişen dosyalar: $msg_list\nLütfen 'known/' klasörünü güncelleyin."
        log_warn "DEĞİŞENLER: $msg_list"
    else
        log_info "Hiçbir değişiklik tespit edilmedi."
    fi

    if [[ ${#error_files[@]} -gt 0 ]]; then
        local err_list=$(printf ", %s" "${error_files[@]}")
        log_error "Hata alınan dosyalar: ${err_list:2}"
    fi

    log_info "İşlem tamamlandı."
}

main
