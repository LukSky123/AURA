"""Create a review-first dataset manifest without copying or changing audio.

Every record starts ineligible. A human licence review must explicitly set
commercial_eligible=true before training selection code can consume it.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import wave
from pathlib import Path

AUDIO_EXTENSIONS = {".wav", ".flac", ".mp3", ".ogg", ".m4a", ".aac", ".opus"}


def checksum(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def duration_seconds(path: Path) -> str:
    if path.suffix.lower() != ".wav":
        return ""
    try:
        with wave.open(str(path), "rb") as audio:
            return f"{audio.getnframes() / audio.getframerate():.3f}"
    except (wave.Error, ZeroDivisionError):
        return ""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path, help="Dataset root to inventory")
    parser.add_argument("--source", required=True, help="Human-readable source name")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--label-from-parent", action="store_true")
    args = parser.parse_args()
    files = sorted(path for path in args.root.rglob("*") if path.is_file() and path.suffix.lower() in AUDIO_EXTENSIONS)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fields = ["relative_path", "source", "label", "licence", "commercial_eligible", "provenance_reviewed", "split", "duration_seconds", "sha256"]
    with args.output.open("w", newline="", encoding="utf-8") as destination:
        writer = csv.DictWriter(destination, fieldnames=fields)
        writer.writeheader()
        for path in files:
            writer.writerow({
                "relative_path": path.relative_to(args.root).as_posix(),
                "source": args.source,
                "label": path.parent.name if args.label_from_parent else "",
                "licence": "UNVERIFIED",
                "commercial_eligible": "false",
                "provenance_reviewed": "false",
                "split": "unassigned",
                "duration_seconds": duration_seconds(path),
                "sha256": checksum(path),
            })


if __name__ == "__main__":
    main()
