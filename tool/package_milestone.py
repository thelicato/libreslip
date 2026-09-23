"""Package the current source milestone and optional preview APK."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE_FILES = {
    '.gitignore', '.metadata', 'AGENTS.md', 'README.md',
    'analysis_options.yaml', 'l10n.yaml', 'pubspec.yaml', 'pubspec.lock',
}
SOURCE_DIRS = {'android', 'docs', 'lib', 'test', 'integration_test', 'tool'}
EXCLUDED_DIRS = {
    '.git', '.agents', '.codex', '.gradle', '.kotlin', '.cxx', '.idea',
    '.dart_tool', 'build', 'dist', '__pycache__', 'captures',
}
EXCLUDED_FILES = {
    'local.properties', 'key.properties', 'GeneratedPluginRegistrant.java',
    '.DS_Store',
}


def source_files():
    for path in sorted(ROOT.iterdir()):
        if path.is_file() and path.name in SOURCE_FILES:
            yield path
        elif path.is_dir() and path.name in SOURCE_DIRS:
            for child in sorted(path.rglob('*')):
                relative = child.relative_to(ROOT)
                if not child.is_file() or child.is_symlink():
                    continue
                if EXCLUDED_DIRS.intersection(relative.parts):
                    continue
                if child.name in EXCLUDED_FILES or child.name.startswith('.env'):
                    continue
                if child.suffix in {'.jks', '.keystore', '.iml', '.pyc', '.apk', '.zip'}:
                    continue
                yield child


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--include-apk', action='store_true')
    args = parser.parse_args()
    if args.include_apk:
        metadata_path = ROOT / 'build/app/outputs/apk/release/output-metadata.json'
        metadata = json.loads(metadata_path.read_text())
        if metadata.get('applicationId') != 'io.thelicato.libreslip':
            raise RuntimeError('Build a fresh LibreSlip release before packaging')
        built = ROOT / 'build/app/outputs/flutter-apk/app-release.apk'
        canonical = metadata_path.parent / 'app-release.apk'
        if hashlib.sha256(built.read_bytes()).digest() != hashlib.sha256(canonical.read_bytes()).digest():
            raise RuntimeError('Flutter and Gradle APK outputs do not match')
    destination = ROOT / 'dist'
    destination.mkdir(exist_ok=True)
    source = destination / 'LibreSlip-task-02-foundation.zip'
    included = list(source_files())
    with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in included:
            archive.write(path, 'LibreSlip/' + path.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(source) as archive:
        if archive.testzip() is not None:
            raise RuntimeError('Source archive integrity check failed')
        for path in included:
            name = 'LibreSlip/' + path.relative_to(ROOT).as_posix()
            if archive.read(name) != path.read_bytes():
                raise RuntimeError(f'Archive content mismatch: {name}')
    outputs = [source]
    if args.include_apk:
        built = ROOT / 'build/app/outputs/flutter-apk/app-release.apk'
        apk = destination / 'LibreSlip-task-02-preview.apk'
        shutil.copy2(built, apk)
        outputs.append(apk)
    checksums = []
    for output in outputs:
        digest = hashlib.sha256(output.read_bytes()).hexdigest()
        checksums.append(f'{digest}  {output.name}\n')
        print(f'{output.relative_to(ROOT)} ({output.stat().st_size:,} bytes)')
    (destination / 'LibreSlip-task-02-SHA256SUMS.txt').write_text(''.join(checksums))
    print(f'Verified {len(included)} source files; SHA-256 checksums written.')


if __name__ == '__main__':
    main()
