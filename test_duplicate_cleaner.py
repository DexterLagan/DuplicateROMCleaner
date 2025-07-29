import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

def create_test_tree(base: Path):
    folder1 = base / 'folder1'
    folder2 = base / 'folder2'
    folder3 = base / 'folder3'
    folder1.mkdir()
    folder2.mkdir()
    folder3.mkdir()

    # Folder1: three orphan txt files
    for i in range(1, 4):
        (folder1 / f'test{i}.txt').write_text(f'orphan {i}')

    # Folder2: orphan + zipped copy
    file2 = folder2 / 'othertest1.txt'
    file2.write_text('some data')
    with zipfile.ZipFile(folder2 / 'othertest1.zip', 'w') as z:
        z.write(file2, arcname='othertest1.txt')

    # Folder3: only zip files containing txt
    for i in range(1, 4):
        tmp = folder3 / f'tmp{i}.txt'
        tmp.write_text(f'data {i}')
        with zipfile.ZipFile(folder3 / f'zip{i}.zip', 'w') as z:
            z.write(tmp, arcname=tmp.name)
        tmp.unlink()

    return folder1, folder2, folder3


def run_tool(base: Path) -> str:
    result = subprocess.run([
        sys.executable,
        'duplicate-cleaner-py.py',
        str(base),
        '-e',
        '-c'
    ], capture_output=True, text=True)
    print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    if result.returncode != 0:
        raise RuntimeError('Tool failed')
    return result.stdout


def verify(base: Path, log: str, folders):
    folder1, folder2, folder3 = folders
    # Folder1: expect zip files, no txt files
    for i in range(1, 4):
        assert not (folder1 / f'test{i}.txt').exists(), 'orphan txt not removed'
        assert (folder1 / f'test{i}.zip').exists(), 'zip not created'

    # Folder2: expect txt removed, zip remains
    assert not (folder2 / 'othertest1.txt').exists(), 'duplicate txt not deleted'
    assert (folder2 / 'othertest1.zip').exists(), 'zip missing in folder2'

    # Folder3: zip files untouched
    for i in range(1, 4):
        assert (folder3 / f'zip{i}.zip').exists(), 'zip file missing in folder3'

    # Log checks
    assert 'Orphan: test1.txt' in log
    assert 'Duplicate found: othertest1.txt' in log


def main():
    base = Path(tempfile.mkdtemp(prefix='dup_test_'))
    try:
        folders = create_test_tree(base)
        log = run_tool(base)
        verify(base, log, folders)
        print('All checks passed.')
    finally:
        shutil.rmtree(base)


if __name__ == '__main__':
    main()

