"""Prepare bundled offline ASR assets at development time; never called by the app."""
import hashlib
import json
from pathlib import Path
import shutil
import tarfile
import urllib.request
import wave

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets' / 'offline_voice'
CACHE = ROOT / '.dart_tool' / 'voice_model'
URL = ('https://github.com/k2-fsa/sherpa-onnx/releases/download/'
       'asr-models/sherpa-onnx-whisper-base.tar.bz2')
FILES = {
    'base-encoder.int8.onnx': 'encoder.int8.onnx',
    'base-decoder.int8.onnx': 'decoder.int8.onnx',
    'base-tokens.txt': 'tokens.txt',
}


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    archive = CACHE / 'whisper-base.tar.bz2'
    manifest_path = DEST / 'manifest.json'
    expected = json.loads(manifest_path.read_text()) if manifest_path.exists() else None
    if not archive.exists():
        print('Downloading multilingual model for bundling (~208 MB).', flush=True)
        partial = archive.with_suffix('.partial')
        with urllib.request.urlopen(URL, timeout=120) as source, partial.open('wb') as target:
            shutil.copyfileobj(source, target)
        partial.replace(archive)
    archive_hash = sha256(archive)
    if expected and expected['archive_sha256'] != archive_hash:
        raise RuntimeError('Model archive differs from the pinned manifest.')
    found = {}
    with tarfile.open(archive, 'r:bz2') as bundle:
        # Extract only named regular files; never trust archive paths or links.
        for member in bundle:
            name = Path(member.name).name
            if member.isfile() and member.name.endswith('/test_wavs/0.wav'):
                sample = CACHE / 'sample.wav'
                sample.write_bytes(bundle.extractfile(member).read())
                with wave.open(str(sample), 'rb') as wav:
                    if wav.getframerate() != 16000 or wav.getnchannels() != 1 or wav.getsampwidth() != 2:
                        raise RuntimeError('Unexpected test waveform format')
                    (CACHE / 'sample.pcm').write_bytes(wav.readframes(wav.getnframes()))
            if name not in FILES or not member.isfile():
                continue
            target = DEST / FILES[name]
            with bundle.extractfile(member) as source, target.open('wb') as output:
                shutil.copyfileobj(source, output)
            found[target.name] = {'bytes': target.stat().st_size, 'sha256': sha256(target)}
    if set(found) != set(FILES.values()):
        raise RuntimeError(f'Missing model files; found {list(found)}')
    if expected and expected['files'] != found:
        raise RuntimeError('Extracted model files do not match the pinned manifest.')
    manifest_path.write_text(json.dumps({
        'model': 'multilingual-whisper-base-int8', 'source': URL,
        'archive_sha256': archive_hash, 'files': found,
    }, indent=2) + '\n')
    print(f'Offline model ready: {sum(f["bytes"] for f in found.values()) / 1048576:.1f} MiB', flush=True)


if __name__ == '__main__':
    main()
