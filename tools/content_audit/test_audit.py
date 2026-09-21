import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from audit import inventory, review, missing_external_resources


class ResourceAuditTests(unittest.TestCase):
    def setUp(self):
        artifacts = Path(__file__).resolve().parents[2] / 'artifacts' / 'content_audit_tests'
        artifacts.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=artifacts)
        assert Path(self.temp.name).resolve().is_relative_to(artifacts.resolve())
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.files = []
        mock_git = patch('audit.subprocess.check_output', side_effect=lambda *a, **kw: b'\0'.join(p.encode('utf-8') for p in self.files))
        mock_git.start()
        self.addCleanup(mock_git.stop)

    def write(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding='utf-8')
        self.files.append(path)

    def test_unicode_untracked_paths_and_external_references(self):
        self.write('data/alliés/héros.tres', '[gd_resource format=3]')
        self.write('core/use.gd', 'load("res://data/alliés/héros.tres")')
        rows = review(self.root, ['data/alliés'])
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['external_references'], ['core/use.gd'])

    def test_uid_references_are_not_confused_with_declarations(self):
        self.write('data/room.tres', '[gd_resource uid="uid://abc"]')
        self.write('data/picture.png', 'image')
        self.write('data/picture.png.import', 'uid="uid://def"\nsource_file="res://data/picture.png"')
        self.write('core/room.gd', 'load("uid://abc")\nload("uid://def")')
        _, incoming = inventory(self.root)
        self.assertEqual(incoming['data/room.tres'], {'core/room.gd'})
        self.assertEqual(incoming['data/picture.png'], {'core/room.gd'})

    def test_internal_cycles_stay_visible_but_are_not_external(self):
        self.write('legacy/a.tres', 'load("res://legacy/b.tres")')
        self.write('legacy/b.tres', 'load("res://legacy/a.tres")')
        rows = review(self.root, ['legacy'])
        self.assertTrue(all(not row['external_references'] for row in rows))
        self.assertTrue(all(row['internal_references'] for row in rows))

    def test_reports_and_deleted_tracked_files_are_excluded(self):
        self.write('data/a.tres', '[gd_resource format=3]')
        self.write('gone.gd', 'load("res://data/a.tres")')
        self.write('artifacts/report.json', '"res://data/a.tres"')
        (self.root / 'gone.gd').unlink()
        self.assertEqual(review(self.root, ['data'])[0]['external_references'], [])

    def test_shader_and_script_uid_dependencies(self):
        self.write('core/helper.gd', 'extends RefCounted')
        self.write('core/helper.gd.uid', 'uid://abc')
        self.write('core/use.gd', 'load("uid://abc")')
        self.write('assets/a.gdshader', '#include "res://assets/b.gdshader"')
        self.write('assets/b.gdshader', '// shared')
        _, incoming = inventory(self.root)
        self.assertEqual(incoming['core/helper.gd'], {'core/use.gd'})
        self.assertEqual(incoming['assets/b.gdshader'], {'assets/a.gdshader'})

    def test_missing_serialized_path_fails_even_with_uid(self):
        self.write('scene.tscn', '[gd_scene format=3]\n[ext_resource type="Script" uid="uid://abc" path="res://gone.gd" id="1"]')
        self.assertEqual(missing_external_resources(self.root, review(self.root, ['.'])),
                         [{'source': 'scene.tscn', 'target': 'gone.gd'}])

    def test_nested_godot_projects_resolve_against_their_own_root(self):
        self.write('project.godot', '')
        self.write('tools/lab/project.godot', '')
        self.write('tools/lab/study.gd', 'extends Node')
        self.write('tools/lab/Study.tscn', '[gd_scene format=3]\n[ext_resource type="Script" path="res://study.gd" id="1"]')
        self.write('artifacts/stale.tscn', '[ext_resource path="res://absent.gd"]')
        self.assertEqual(missing_external_resources(self.root, review(self.root, ['.'])), [])


if __name__ == '__main__':
    unittest.main()
