"""Read-only inventory of literal Godot resource dependencies (including UIDs).

This is a review aid, not proof that a resource is unused: constructed paths,
directory scans, editor discovery and external saves still require inspection.
"""
import argparse
import json
import re
import subprocess
from pathlib import Path

TEXT_SUFFIXES = {'.gd', '.gdshader', '.tscn', '.tres', '.godot', '.import', '.json', '.cfg', '.ps1', '.py', '.yml', '.yaml', '.cs', '.js', '.ts', '.sh'}
IGNORED = ('docs/', 'artifacts/', 'output/', 'meshy_output/', '.git/')
PATH = re.compile(r'res://([^"\'\n\r<>]+)')
UID = re.compile(r'uid://[a-z0-9]+')
EXTERNAL_RESOURCE = re.compile(r'^\[ext_resource\b[^\n]*\bpath="res://([^"\n]+)"', re.M)


def inventory(root):
    raw = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=root)
    files = sorted({p.decode('utf-8') for p in raw.split(b'\0') if p})
    texts, owners = {}, {}
    for name in files:
        path = root / name
        if name.startswith(IGNORED) or not path.is_file():
            continue
        if path.suffix == '.uid':
            owners[path.read_text().strip()] = name[:-4]
        elif path.suffix in TEXT_SUFFIXES:
            texts[name] = path.read_text(encoding='utf-8-sig', errors='replace')
            if path.suffix in {'.tres', '.tscn'}:
                match = UID.search(texts[name].splitlines()[0])
                if match:
                    owners[match.group()] = name
            elif path.suffix == '.import':
                match = re.search(r'^uid="(uid://[a-z0-9]+)"', texts[name], re.M)
                if match:
                    owners[match.group(1)] = name[:-7]
    incoming = {}
    for source, body in texts.items():
        targets = set(PATH.findall(body))
        targets.update(owners[u] for u in UID.findall(body) if u in owners)
        for target in targets:
            if target != source and source != target + '.import':
                incoming.setdefault(target, set()).add(source)
    return files, incoming


def review(root, prefixes):
    files, incoming = inventory(root)
    candidates = {p for p in files if not p.startswith(IGNORED) and any(prefix == '.' or p == prefix or p.startswith(prefix.rstrip('/') + '/') for prefix in prefixes) and (root / p).is_file()}
    return [{'path': p, 'bytes': (root / p).stat().st_size,
             'external_references': sorted(incoming.get(p, set()) - candidates),
             'internal_references': sorted(incoming.get(p, set()) & candidates)} for p in sorted(candidates)]


def missing_external_resources(root, rows):
    """Check serialized scene/resource paths within their nearest Godot project.

    This deliberately does not infer script loads or dynamically built paths.
    A valid UID does not excuse a stale path: both must survive a clean checkout.
    """
    root = root.resolve()
    missing = []
    for row in rows:
        path = root / row['path']
        if path.suffix not in {'.tscn', '.tres'}:
            continue
        project_root = root
        for parent in path.parents:
            if not parent.is_relative_to(root):
                break
            if (parent / 'project.godot').is_file():
                project_root = parent
                break
        for target in EXTERNAL_RESOURCE.findall(path.read_text(encoding='utf-8-sig')):
            if not (project_root / target).is_file():
                missing.append({'source': row['path'], 'target': target})
    return missing


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('prefix', nargs='+', help='Repository-relative file or directory')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--check-resources', action='store_true', help='Fail on missing serialized ext_resource paths; use . for the whole repository')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    rows = review(root, args.prefix)
    missing = missing_external_resources(root, rows) if args.check_resources else []
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({'limitations': __doc__, 'files': rows, 'missing_external_resources': missing}, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'files': len(rows), 'bytes': sum(r['bytes'] for r in rows),
                      'with_external_references': sum(bool(r['external_references']) for r in rows), 'missing_external_resources': len(missing), 'report': str(args.output)}))
    return 1 if missing else 0


if __name__ == '__main__':
    raise SystemExit(main())
