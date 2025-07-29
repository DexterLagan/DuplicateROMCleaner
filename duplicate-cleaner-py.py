#!/usr/bin/env python3
import argparse
import os
import sys
import zipfile
import zlib
from pathlib import Path


def crc32_of_file(path: Path, chunk_size: int = 65536) -> int:
    """Compute CRC32 of a file in chunks."""
    crc = 0
    with path.open('rb') as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            crc = zlib.crc32(chunk, crc)
    return crc & 0xFFFFFFFF


def find_duplicates(folder: Path):
    """Yield tuples of (zip_path, file_path) for duplicates."""
    files = [p for p in folder.iterdir() if p.is_file()]
    basenames = {}
    for p in files:
        base = p.stem
        basenames.setdefault(base, []).append(p)
    for group in basenames.values():
        zip_files = [p for p in group if p.suffix.lower() == '.zip']
        other_files = [p for p in group if p.suffix.lower() != '.zip']
        if not zip_files or not other_files:
            continue
        zip_file = zip_files[0]
        try:
            with zipfile.ZipFile(zip_file) as zf:
                for other in other_files:
                    try:
                        info = zf.getinfo(other.name)
                    except KeyError:
                        continue
                    crc_local = crc32_of_file(other)
                    if info.CRC == crc_local and info.file_size == other.stat().st_size:
                        yield zip_file, other
        except zipfile.BadZipFile:
            pass


def find_orphans(folder: Path):
    """Return list of file paths without matching zip."""
    orphans = []
    for p in folder.iterdir():
        if p.is_file() and p.suffix.lower() != '.zip':
            zip_path = p.with_suffix('.zip')
            if not zip_path.exists():
                orphans.append(p)
    return orphans


def compress_orphan(path: Path):
    zip_path = path.with_suffix('.zip')
    with zipfile.ZipFile(zip_path, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
        zf.write(path, arcname=path.name)
    # verify
    with zipfile.ZipFile(zip_path) as zf:
        info = zf.getinfo(path.name)
        if info.file_size == path.stat().st_size and info.CRC == crc32_of_file(path):
            return True
    zip_path.unlink(missing_ok=True)
    return False


def process_folder(folder: Path, execute: bool, compress: bool):
    print(f"\nProcessing folder: {folder}")
    for zip_path, dup_path in find_duplicates(folder):
        print(f"  Duplicate found: {dup_path.name} -> {zip_path.name}")
        if execute:
            dup_path.unlink()
            print("    [DELETED]")
    if compress:
        for orphan in find_orphans(folder):
            print(f"  Orphan: {orphan.name}")
            if execute:
                if compress_orphan(orphan):
                    orphan.unlink()
                    print("    [COMPRESSED]")


def main():
    parser = argparse.ArgumentParser(description="Duplicate Cleaner Prototype (CRC)")
    parser.add_argument('path', nargs='?', default='.', help='Folder or drive to scan')
    parser.add_argument('-e', '--execute', action='store_true', help='Perform deletions/compressions')
    parser.add_argument('-c', '--compress-orphans', action='store_true', help='Compress orphan files')
    args = parser.parse_args()

    root = Path(args.path)
    if not root.exists() or not root.is_dir():
        print(f"Path not found: {root}")
        sys.exit(1)

    for folder, dirs, files in os.walk(root):
        process_folder(Path(folder), args.execute, args.compress_orphans)


if __name__ == '__main__':
    main()

