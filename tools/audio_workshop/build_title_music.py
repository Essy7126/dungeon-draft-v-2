"""Import the eight approved title candidates as local, level-matched game assets."""
from pathlib import Path
import hashlib
import json
import re
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'artifacts/audio/python'))
import numpy as np
import soundfile as sf


def main():
    catalog = (ROOT / 'tools/audio_workshop/title_music_catalog.js').read_text(encoding='utf-8')
    tracks = []
    for block in re.findall(r'\{(.*?)\}', catalog, re.S):
        track = {key: re.search(rf"\b{key}: '([^']+)'", block).group(1)
                 for key in ['id', 'title', 'author', 'source', 'audio']}
        assert re.fullmatch('[a-z]+', track['id'])
        tracks.append(track)
    assert len(tracks) == 8
    sources = ROOT / 'artifacts/audio/title_music_import/sources'
    output = ROOT / 'assets/audio/title'
    sources.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    records = []
    for track in tracks:
        source = sources / (track['id'] + '.mp3')
        if not source.exists():
            request = urllib.request.Request(track['audio'], headers={'User-Agent': 'CatabaseAudioImport/1.0'})
            with urllib.request.urlopen(request, timeout=90) as response:
                payload = response.read()
            assert len(payload) > 10000
            source.write_bytes(payload)
        data, rate = sf.read(source, dtype='float32', always_2d=True)
        assert len(data) / rate > 120 and np.isfinite(data).all()
        # Static gain preserves musical dynamics. Peak headroom protects the
        # loudest passage instead of compressing the arrangement for a menu.
        peak = float(np.max(np.abs(data)))
        rms = float(np.sqrt(np.mean(np.square(data), dtype=np.float64)))
        gain = min(10 ** (-24 / 20) / max(rms, 1e-9), 10 ** (-8 / 20) / max(peak, 1e-9))
        data *= gain
        edge = min(round(rate * .025), len(data) // 2)
        data[:edge] *= np.linspace(0, 1, edge, dtype=np.float32)[:, None]
        data[-edge:] *= np.linspace(1, 0, edge, dtype=np.float32)[:, None]
        target = output / (track['id'] + '.ogg')
        staging = target.with_suffix('.part')
        # Bounded writes avoid libvorbis stack allocation on a whole long track.
        with sf.SoundFile(staging, mode='w', samplerate=rate, channels=data.shape[1],
                          format='OGG', subtype='VORBIS') as encoder:
            for start in range(0, len(data), 65536):
                encoder.write(data[start:start + 65536])
        decoded, decoded_rate = sf.read(staging, dtype='float32', always_2d=True)
        final_peak = float(np.max(np.abs(decoded)))
        final_rms = float(np.sqrt(np.mean(np.square(decoded), dtype=np.float64)))
        assert decoded_rate == rate and abs(len(decoded) - len(data)) < rate
        assert np.isfinite(decoded).all() and 0.005 < final_peak < .5
        staging.replace(target)
        record = dict(track, resource='res://assets/audio/title/' + target.name,
                      duration_seconds=len(decoded) / rate, sample_rate=rate, channels=decoded.shape[1],
                      gain_db=20 * np.log10(gain), peak_dbfs=20 * np.log10(final_peak),
                      rms_dbfs=20 * np.log10(final_rms), bytes=target.stat().st_size,
                      source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                      output_sha256=hashlib.sha256(target.read_bytes()).hexdigest())
        records.append(record)
        print(json.dumps({'track': track['title'], 'seconds': record['duration_seconds'],
                          'peak_dbfs': record['peak_dbfs'], 'rms_dbfs': record['rms_dbfs']}), flush=True)
    manifest = {'passed': True, 'license': 'CC BY 4.0', 'date': '2026-09-12',
                'adaptations': 'Static level adjustment, 25 ms edge fades, Ogg Vorbis encoding; original pitch, tempo and stereo preserved.',
                'tracks': records}
    (output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    credit = '# Catabase — musiques de l’écran titre\n\n'
    credit += 'Les huit morceaux sont utilisés sous Creative Commons Attribution 4.0 International.\n'
    credit += 'Licence : https://creativecommons.org/licenses/by/4.0/\n\n'
    credit += 'Adaptations : ajustement de niveau, fondus de 25 ms aux extrémités et conversion Ogg Vorbis. '
    credit += 'Tempo, hauteur et stéréo conservés. Les auteurs ne cautionnent pas cette adaptation.\n\n'
    for track in tracks:
        credit += f"## {track['title']}\n\nMusique : **{track['title']}**, par **{track['author']}**.\n\nSource et conditions : {track['source']}\n\nLicence : CC BY 4.0.\n\n"
    credit += 'Conserver ces crédits avec toute distribution du jeu. Ils sont aussi accessibles depuis son écran titre.\n'
    (output / 'CREDITS.md').write_text(credit, encoding='utf-8')
    print(json.dumps({'passed': True, 'tracks': len(records), 'bytes': sum(row['bytes'] for row in records)}), flush=True)


if __name__ == '__main__':
    main()
