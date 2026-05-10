#!/bin/bash
# =============================================================================
# media_report.sh
# Report spazio occupato da sorgente vs destinazione compressa
# =============================================================================

SOURCE="${1:-/home/nextcloud-data/data/data/arma/files/Toshiba}"
DEST="${2:-/mnt/nextcloud_hdd/Foto-compresse}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}       MEDIA COMPRESSION REPORT        ${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "Data: $(date '+%Y-%m-%d %H:%M')\n"

# ── SORGENTE ─────────────────────────────────────────────────────────────────
SRC_SIZE=$(du -sb "$SOURCE" 2>/dev/null | cut -f1)
SRC_HUMAN=$(du -sh "$SOURCE" 2>/dev/null | cut -f1)
SRC_FILES=$(find "$SOURCE" -type f | wc -l)
SRC_VIDEO=$(find "$SOURCE" -type f \( -iname "*.mp4" -o -iname "*.mov" \) | wc -l)
SRC_HEIC=$(find "$SOURCE" -type f -iname "*.heic" | wc -l)
SRC_JPG=$(find "$SOURCE" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | wc -l)

echo -e "${YELLOW}📂 SORGENTE: $SOURCE${NC}"
echo -e "   Spazio totale : $SRC_HUMAN"
echo -e "   File totali   : $SRC_FILES"
echo -e "   Video (mp4/mov): $SRC_VIDEO"
echo -e "   HEIC           : $SRC_HEIC"
echo -e "   JPG/JPEG       : $SRC_JPG"

# ── DESTINAZIONE ─────────────────────────────────────────────────────────────
if [ -d "$DEST" ]; then
    DST_SIZE=$(du -sb "$DEST" 2>/dev/null | cut -f1)
    DST_HUMAN=$(du -sh "$DEST" 2>/dev/null | cut -f1)
    DST_FILES=$(find "$DEST" -type f | wc -l)
    DST_VIDEO=$(find "$DEST" -type f -iname "*.mp4" | wc -l)
    DST_JPG=$(find "$DEST" -type f -iname "*.jpg" | wc -l)

    echo -e "\n${YELLOW}📦 DESTINAZIONE: $DEST${NC}"
    echo -e "   Spazio totale  : $DST_HUMAN"
    echo -e "   File totali    : $DST_FILES"
    echo -e "   Video H.265    : $DST_VIDEO"
    echo -e "   JPG (da HEIC)  : $DST_JPG"

    # ── RISPARMIO ────────────────────────────────────────────────────────────
    if [ "$SRC_SIZE" -gt 0 ] && [ "$DST_SIZE" -gt 0 ]; then
        SAVED=$((SRC_SIZE - DST_SIZE))
        SAVED_HUMAN=$(numfmt --to=iec $SAVED 2>/dev/null || echo "$((SAVED / 1024 / 1024)) MB")
        PCT=$((SAVED * 100 / SRC_SIZE))

        echo -e "\n${GREEN}💾 RISPARMIO${NC}"
        echo -e "   Spazio risparmiato : $SAVED_HUMAN"
        echo -e "   Riduzione          : ${PCT}%"
    fi
else
    echo -e "\n⚠️  Destinazione non trovata ancora — compressione in corso?"
fi

# ── DISCO ──────────────────────────────────
