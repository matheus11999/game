"""Export Windows x64 and package a previously checksum-verified Node 24 runtime.

Godot templates and NODE_WINDOWS_EXE must already be installed from official,
verified sources. This script never downloads or disables verification. Staging
is fresh on every build, and account data is excluded from both ZIP archives.
"""
from pathlib import Path
import hashlib
import os
import shutil
import struct
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'releases'


def require_windows_x64(path):
    """Reject Linux runtimes, truncated exports and wrong PE architectures."""
    with path.open('rb') as file:
        header = file.read(64)
        if len(header) != 64 or header[:2] != b'MZ':
            raise ValueError(f'{path.name} is not a Windows PE executable')
        file.seek(struct.unpack_from('<I', header, 60)[0])
        pe = file.read(6)
        if len(pe) != 6 or pe[:4] != b'PE\0\0' or struct.unpack_from('<H', pe, 4)[0] != 0x8664:
            raise ValueError(f'{path.name} is not a Windows x64 PE executable')


def excluded_source(path):
    parts = path.relative_to(ROOT).parts
    return (any(part in {'.git', '.godot', 'node_modules', 'releases', 'data',
                            '__pycache__', '.pytest_cache', '.mypy_cache', '.cache'} for part in parts)
            or any(part == '.env' or part.startswith('.env.') for part in parts)
            or path.suffix.lower() in {'.log', '.pyc', '.db', '.sqlite', '.sqlite3'}
            or path.name.endswith(('-wal', '-shm')))


def main():
    node = Path(os.environ['NODE_WINDOWS_EXE'])
    require_windows_x64(node)
    OUT.mkdir(exist_ok=True)
    # Never reuse an old package directory: it can contain user saves or logs.
    with tempfile.TemporaryDirectory(prefix='brumora-package-', dir=OUT) as temporary:
        stage = Path(temporary) / 'TaskMon-Windows'
        stage.mkdir()
        subprocess.run([os.environ.get('GODOT_BIN', 'godot'), '--headless', '--path', str(ROOT),
                        '--export-release', 'Windows Desktop', str(stage / 'TaskMon.exe')], check=True)
        require_windows_x64(stage / 'TaskMon.exe')
        (stage / 'runtime').mkdir()
        shutil.copy2(node, stage / 'runtime' / 'node.exe')
        files = ['server/index.ts', 'server/engine.ts', 'server/progression.ts', 'server/package.json',
                 'tools/launcher.mjs', 'README.md', 'AGENTS.md', 'docs/PLANO.md', 'docs/CLOUD_HANDOFF.md',
                 'docs/ART_DIRECTION.md', 'docs/ASSET_REGISTRY.md', 'docs/ART_PROMPTS.md', 'docs/ART_PROMPTS_PARTS.md', 'docs/TASKMON_PLANO.md', 'docs/CREATURE_MOTION.md', 'docs/DESIGN_REVIEW.md', 'docs/VALIDACAO.md', 'docs/LOCAL_HANDOFF.md', 'docs/THIRD-PARTY.md',
                 'docs/Godot-LICENSE.txt', 'docs/Godot-COPYRIGHT.txt', 'docs/Node-LICENSE.txt']
        # The server reads catalogue JSON from disk, outside Godot's embedded PCK.
        files += [path.relative_to(ROOT).as_posix() for path in sorted((ROOT / 'assets').glob('*.json'))]
        files += [path.relative_to(ROOT).as_posix() for path in sorted((ROOT / 'assets/fonts').glob('*OFL*.txt'))]
        if 'assets/species.json' not in files or 'assets/enemies.json' not in files:
            raise ValueError('Missing required species.json or enemies.json catalogue')
        for relative in files:
            target = stage / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        batches = {
            'Iniciar-TaskMon.bat': '@echo off\nsetlocal\ncd /d "%~dp0"\n"%~dp0runtime\\node.exe" "%~dp0tools\\launcher.mjs"\nif errorlevel 1 pause\n',
            'Iniciar-Servidor.bat': '@echo off\nsetlocal\ncd /d "%~dp0"\nset "BRUMORA_HOST=127.0.0.1"\nset "BRUMORA_PORT=8787"\necho TaskMon - servidor local. Deixe esta janela aberta. Ctrl+C para parar.\n"%~dp0runtime\\node.exe" "%~dp0server\\index.ts"\nif errorlevel 1 pause\n',
        }
        for name, text in batches.items():
            (stage / name).write_bytes(text.replace('\n', '\r\n').encode('ascii'))
        archive = OUT / 'TaskMon-MVP-Windows-x64.zip'
        with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
            for file in sorted(stage.rglob('*')):
                if file.is_file():
                    zipped.write(file, Path('TaskMon-Windows') / file.relative_to(stage))
    source = OUT / 'TaskMon-MVP-Codigo-Fonte.zip'
    with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
        for file in sorted(ROOT.rglob('*')):
            if file.is_file() and not excluded_source(file):
                zipped.write(file, Path('TaskMon-Fonte') / file.relative_to(ROOT))
    checks = []
    for file in [archive, source]:
        digest = hashlib.sha256(file.read_bytes()).hexdigest()
        checks.append(f'{digest}  {file.name}')
        print(file.name, round(file.stat().st_size / 1024 / 1024, 2), 'MiB', digest)
    (OUT / 'SHA256SUMS.txt').write_text('\n'.join(checks) + '\n')


if __name__ == '__main__':
    main()
