# compress_media

Bash script to compress and convert photos and videos, designed for a Nextcloud server on Arch Linux.

## Features

- **MP4/MOV → H.265** (40–60% size reduction)
- **HEIC → JPG** (universal compatibility)
- **PNG → JPG** (optional, disabled by default)
- Idempotent: already converted files are skipped
- Dry-run mode to preview operations without making any changes
- Detailed log with OK/Skip/Error counters
- Configurable via `.env` file or CLI arguments

## Requirements

```bash
sudo pacman -S ffmpeg
```

## Setup

```bash
cp compress_media.env.example compress_media.env
# Edit compress_media.env with your paths
chmod +x compress_media.sh
```

> ⚠️ Add `compress_media.env` to `.gitignore` — it contains local paths.

## Usage

### With config file (recommended)
```bash
./compress_media.sh --config ./compress_media.env
```

### With CLI arguments
```bash
./compress_media.sh \
  --source /home/nextcloud-data/data/data/arma/files/Toshiba \
  --dest /mnt/nextcloud_hdd/Foto-compresse \
  --crf 26 \
  --preset slow
```

### Dry-run (no changes made)
```bash
./compress_media.sh --config ./compress_media.env --dry-run
```

### Exclude folders (e.g. logos, graphics)
```bash
./compress_media.sh --config ./compress_media.env \
  --exclude "Arma Logo" --exclude "Files"
```

### Enable PNG → JPG
```bash
./compress_media.sh --config ./compress_media.env --convert-png
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--source DIR` | — | Source folder (required) |
| `--dest DIR` | — | Destination folder (required) |
| `--config FILE` | `./compress_media.env` | Config file path |
| `--log FILE` | `/var/log/compress_media.log` | Log file path |
| `--crf N` | `28` | H.265 quality: 24 (high) – 30 (low) |
| `--preset` | `slow` | ffmpeg preset: slow/medium/fast |
| `--convert-png` | disabled | Enable PNG→JPG conversion |
| `--no-heic` | — | Disable HEIC→JPG conversion |
| `--no-video` | — | Disable video compression |
| `--exclude DIR` | — | Exclude a folder (repeatable) |
| `--dry-run` | — | Preview operations without executing |

## Recommended repo structure

```
ArchServer-setup/
└── media/
    ├── compress_media.sh
    ├── compress_media.env.example
    ├── compress_media.env          ← in .gitignore
    └── README.md
```

## Notes

- **NEF (Nikon RAW)** files are never touched
- The script **never deletes originals**
- The physical Toshiba drive is never written to (SOURCE is read-only)
- Safe to re-run: already converted files are skipped automatically
