#!/bin/bash
# =============================================================================
# compress_media.sh
# Compressione e conversione foto/video per server Nextcloud (o altro)
#
# Uso:
#   ./compress_media.sh [opzioni]
#   ./compress_media.sh --source /path/foto --dest /path/output
#   ./compress_media.sh --config /path/config.env
#   ./compress_media.sh --dry-run
#
# Repo: https://github.com/tuoutente/ArchServer-setup
# =============================================================================

set -euo pipefail

# ── VALORI DEFAULT (sovrascrivibili da config.env o argomenti) ────────────────
SOURCE=""
DEST=""
LOG_FILE="/var/log/compress_media.log"
DRY_RUN=false
CONVERT_HEIC=true
CONVERT_PNG=false        # PNG→JPG: false di default (potrebbero essere grafica)
COMPRESS_VIDEO=true
VIDEO_CRF=28             # qualità video H.265: 24 (alta) – 30 (bassa)
VIDEO_PRESET="slow"      # slow = miglior compressione, fast = più veloce
JPEG_QUALITY=4           # ffmpeg -q:v: 2 (alta) – 6 (bassa)
# Cartelle da ignorare (separate da spazio)
EXCLUDE_DIRS=()

# ── COLORI ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── CONTATORI ────────────────────────────────────────────────────────────────
COUNT_OK=0
COUNT_SKIP=0
COUNT_ERR=0

# ── FUNZIONI ─────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Uso: $(basename "$0") [opzioni]

Opzioni:
  --source DIR        Cartella sorgente (obbligatorio se non in config)
  --dest DIR          Cartella destinazione (obbligatorio se non in config)
  --config FILE       File di configurazione .env (default: ./compress_media.env)
  --log FILE          File di log (default: /var/log/compress_media.log)
  --crf N             Qualità video H.265, 24–30 (default: 28)
  --preset PRESET     Preset ffmpeg: slow|medium|fast (default: slow)
  --convert-png       Abilita conversione PNG→JPG (default: disabilitato)
  --no-heic           Disabilita conversione HEIC→JPG
  --no-video          Disabilita compressione video
  --exclude DIR       Escludi una cartella (ripetibile)
  --dry-run           Mostra cosa verrebbe fatto, senza modificare nulla
  -h, --help          Mostra questo aiuto

Esempio:
  ./compress_media.sh --source /home/nextcloud-data/data/arma/files/Toshiba \\
                      --dest /mnt/nextcloud_hdd/Foto-compresse \\
                      --crf 26 --dry-run
EOF
    exit 0
}

log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${ts} [${level}] ${msg}" | tee -a "$LOG_FILE"
}

log_ok()   { log "${GREEN}OK   ${NC}" "$@"; COUNT_OK=$((COUNT_OK+1)); }
log_skip() { log "${BLUE}SKIP ${NC}" "$@"; COUNT_SKIP=$((COUNT_SKIP+1)); }
log_err()  { log "${RED}ERR  ${NC}" "$@"; COUNT_ERR=$((COUNT_ERR+1)); }
log_info() { log "${YELLOW}INFO ${NC}" "$@"; }

check_deps() {
    local missing=()
    for cmd in ffmpeg find; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        log_err "Dipendenze mancanti: ${missing[*]}"
        log_err "Installa con: sudo pacman -S ${missing[*]}"
        exit 1
    fi
}

# Costruisce l'argomento -prune per find basandosi su EXCLUDE_DIRS
build_exclude_args() {
    local args=()
    for dir in "${EXCLUDE_DIRS[@]}"; do
        args+=(-path "*/${dir}" -prune -o)
    done
    printf '%s\0' "${args[@]}"
}

process_video() {
    local file="$1"
    local relative
    relative="$(realpath --relative-to="$SOURCE" "$file")"
    local outfile="${DEST}/${relative%.*}.mp4"

    mkdir -p "$(dirname "$outfile")"

    if [ -f "$outfile" ]; then
        log_skip "$outfile"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] VIDEO: $file → $outfile"
        return
    fi

    log_info "VIDEO: $(basename "$file") → $outfile"
    if ffmpeg -nostdin -i "$file" \
              -c:v libx265 -crf "$VIDEO_CRF" -preset "$VIDEO_PRESET" \
              -c:a aac -b:a 128k \
              -tag:v hvc1 \
              -y "$outfile" \
              >> "$LOG_FILE" 2>&1 < /dev/null; then
        log_ok "$(basename "$outfile")"
    else
        log_err "Fallito: $file"
        rm -f "$outfile"
    fi
}

process_heic() {
    local file="$1"
    local relative
    relative="$(realpath --relative-to="$SOURCE" "$file")"
    local outfile="${DEST}/${relative%.*}.jpg"

    mkdir -p "$(dirname "$outfile")"

    if [ -f "$outfile" ]; then
        log_skip "$outfile"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] HEIC: $file → $outfile"
        return
    fi

    log_info "HEIC: $(basename "$file") → $outfile"
    if ffmpeg -i "$file" -q:v "$JPEG_QUALITY" -y "$outfile" >> "$LOG_FILE" 2>&1 < /dev/null; then
        log_ok "$(basename "$outfile")"
    else
        log_err "Fallito: $file"
    fi
}

process_png() {
    local file="$1"
    local relative
    relative="$(realpath --relative-to="$SOURCE" "$file")"
    local outfile="${DEST}/${relative%.*}.jpg"

    mkdir -p "$(dirname "$outfile")"

    if [ -f "$outfile" ]; then
        log_skip "$outfile"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] PNG: $file → $outfile"
        return
    fi

    log_info "PNG: $(basename "$file") → $outfile"
    if ffmpeg -i "$file" -q:v "$JPEG_QUALITY" -y "$outfile" >> "$LOG_FILE" 2>&1 < /dev/null; then
        log_ok "$(basename "$outfile")"
    else
        log_err "Fallito: $file"
    fi
}

# ── PARSING ARGOMENTI ─────────────────────────────────────────────────────────
CONFIG_FILE="$(dirname "$0")/compress_media.env"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)      SOURCE="$2";       shift 2 ;;
        --dest)        DEST="$2";         shift 2 ;;
        --config)      CONFIG_FILE="$2";  shift 2 ;;
        --log)         LOG_FILE="$2";     shift 2 ;;
        --crf)         VIDEO_CRF="$2";    shift 2 ;;
        --preset)      VIDEO_PRESET="$2"; shift 2 ;;
        --convert-png) CONVERT_PNG=true;  shift   ;;
        --no-heic)     CONVERT_HEIC=false; shift  ;;
        --no-video)    COMPRESS_VIDEO=false; shift ;;
        --exclude)     EXCLUDE_DIRS+=("$2"); shift 2 ;;
        --dry-run)     DRY_RUN=true;      shift   ;;
        -h|--help)     usage ;;
        *) echo "Opzione sconosciuta: $1"; usage ;;
    esac
done

# ── CARICA CONFIG FILE (se esiste) ───────────────────────────────────────────
if [ -f "$CONFIG_FILE" ]; then
    log_info "Carico configurazione da: $CONFIG_FILE"
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# ── VALIDAZIONE ───────────────────────────────────────────────────────────────
if [ -z "$SOURCE" ] || [ -z "$DEST" ]; then
    echo -e "${RED}Errore: --source e --dest sono obbligatori (o definiti in config.env)${NC}"
    echo "Usa --help per vedere le opzioni."
    exit 1
fi

if [ ! -d "$SOURCE" ]; then
    echo -e "${RED}Errore: la cartella sorgente non esiste: $SOURCE${NC}"
    exit 1
fi

# ── AVVIO ─────────────────────────────────────────────────────────────────────
mkdir -p "$DEST"
mkdir -p "$(dirname "$LOG_FILE")"

log_info "============================================="
log_info "compress_media.sh — avvio $(date)"
log_info "SOURCE:   $SOURCE"
log_info "DEST:     $DEST"
log_info "LOG:      $LOG_FILE"
log_info "DRY_RUN:  $DRY_RUN"
log_info "CRF:      $VIDEO_CRF | PRESET: $VIDEO_PRESET"
log_info "HEIC→JPG: $CONVERT_HEIC | PNG→JPG: $CONVERT_PNG | VIDEO: $COMPRESS_VIDEO"
[ ${#EXCLUDE_DIRS[@]} -gt 0 ] && log_info "ESCLUDI:  ${EXCLUDE_DIRS[*]}"
log_info "============================================="

check_deps

EXCLUDE_ARGS=()
if [ ${#EXCLUDE_DIRS[@]} -gt 0 ]; then
    while IFS= read -r -d '' arg; do
        EXCLUDE_ARGS+=("$arg")
    done < <(build_exclude_args)
fi

# ── ELABORAZIONE VIDEO ────────────────────────────────────────────────────────
if [ "$COMPRESS_VIDEO" = true ]; then
    log_info "--- Video (MP4, MOV) ---"
    while IFS= read -r -d '' file; do
        process_video "$file"
    done < <(find "$SOURCE" "${EXCLUDE_ARGS[@]}" -type f \
             \( -iname "*.mp4" -o -iname "*.mov" \) -print0)
fi

# ── ELABORAZIONE HEIC ─────────────────────────────────────────────────────────
if [ "$CONVERT_HEIC" = true ]; then
    log_info "--- HEIC → JPG ---"
    while IFS= read -r -d '' file; do
        process_heic "$file"
    done < <(find "$SOURCE" "${EXCLUDE_ARGS[@]}" -type f -iname "*.heic" -print0)
fi

# ── ELABORAZIONE PNG ──────────────────────────────────────────────────────────
if [ "$CONVERT_PNG" = true ]; then
    log_info "--- PNG → JPG ---"
    while IFS= read -r -d '' file; do
        process_png "$file"
    done < <(find "$SOURCE" "${EXCLUDE_ARGS[@]}" -type f -iname "*.png" -print0)
fi

# ── RIEPILOGO ─────────────────────────────────────────────────────────────────
log_info "============================================="
log_info "RIEPILOGO:"
log_info "  ✅ OK:      $COUNT_OK"
log_info "  ⏭️  Skip:   $COUNT_SKIP"
log_info "  ❌ Errors:  $COUNT_ERR"
log_info "Fine: $(date)"
log_info "============================================="

[ "$COUNT_ERR" -gt 0 ] && exit 1 || exit 0
