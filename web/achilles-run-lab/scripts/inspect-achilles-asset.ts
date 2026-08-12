import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

interface GltfNamed { name?: string }
interface GltfJson { meshes?: GltfNamed[]; skins?: GltfNamed[]; animations?: GltfNamed[] }

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const assetPath = path.join(root, 'public', 'assets', 'achilles', 'achilles.glb');
const manifestPath = path.join(root, 'public', 'assets', 'achilles', 'manifest.json');

function parseGlb(buffer: Buffer): GltfJson {
  if (buffer.length < 20 || buffer.readUInt32LE(0) !== 0x46546c67) throw new Error('Signature GLB invalide.');
  if (buffer.readUInt32LE(4) !== 2) throw new Error(`Version GLB non supportée : ${buffer.readUInt32LE(4)}`);
  const declaredLength = buffer.readUInt32LE(8);
  if (declaredLength !== buffer.length) throw new Error(`Longueur GLB incohérente : ${declaredLength} au lieu de ${buffer.length}.`);
  const jsonLength = buffer.readUInt32LE(12);
  const chunkType = buffer.readUInt32LE(16);
  if (chunkType !== 0x4e4f534a) throw new Error('Premier chunk GLB non JSON.');
  const json = buffer.subarray(20, 20 + jsonLength).toString('utf8').replace(/\0+$/u, '').trim();
  return JSON.parse(json) as GltfJson;
}

function names(entries: GltfNamed[] | undefined, prefix: string): string[] {
  return (entries ?? []).map((entry, index) => entry.name?.trim() || `${prefix}_${index}`);
}

const buffer = await readFile(assetPath);
const gltf = parseGlb(buffer);
const detectedMeshes = names(gltf.meshes, 'mesh');
const detectedSkeletons = names(gltf.skins, 'skeleton');
const detectedAnimationGroups = names(gltf.animations, 'animation');
const findClip = (patterns: string[]): string | null => detectedAnimationGroups.find((name) => patterns.some((pattern) => name.toLowerCase().includes(pattern))) ?? null;
const selectedAnimationMapping = {
  idle: findClip(['idle']),
  walk: findClip(['walk', 'run']),
  attack: findClip(['attack', 'strike']),
};
const fallbackRequired = detectedMeshes.length === 0;
const manifest = {
  sourceRepositoryPath: 'assets/characters/Achilles/asset_7Lk6DnzzJFLFGSvx7rQkSa1U.glb',
  sourceGitReference: '8bd9d455bced1c68acf98843e6f6d4844d4174e8',
  sourceFileSize: buffer.length,
  sourceSha256: createHash('sha256').update(buffer).digest('hex'),
  copiedAt: '2026-08-11T21:41:58.1070829Z',
  detectedMeshes,
  detectedSkeletons,
  detectedAnimationGroups,
  selectedAnimationMapping,
  fallbackRequired,
  notes: detectedAnimationGroups.length === 0
    ? 'GLB sans animation déclarée. Le mesh peut être chargé ; toutes les animations utilisent les transforms procéduraux de secours.'
    : 'Clips mappés par recherche insensible à la casse. Tout clip absent utilise un mouvement procédural.',
};
await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
process.stdout.write(`${JSON.stringify(manifest, null, 2)}\n`);
