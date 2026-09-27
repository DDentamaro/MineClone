// Estrae ISO_CORE dall'HTML di riferimento (senza modificarlo) e genera la fixture
// del mondo originale con le stesse opzioni del bootstrap worker: World(192,48,192),
// generate(world, seed, {caves:false}), computeLight(world).
// Uso: node tools/extract_fixture.mjs [seed] [outDir]
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const htmlPath = path.join(root, 'reference/isoterra_proto_v0_64_humanoids.html');
const seed = Number(process.argv[2] ?? 1931);
const outDir = path.resolve(process.argv[3] ?? path.join(root, 'tests/fixtures', `seed${seed}_v064`));

const html = fs.readFileSync(htmlPath);
const sha = (b) => crypto.createHash('sha256').update(b).digest('hex');
const text = html.toString('utf8');
const m = text.match(/<script id="iso-core">([\s\S]*?)<\/script>/);
if (!m) throw new Error('script iso-core non trovato');
const coreSrc = m[1];

const sandbox = { console, Math, Date };
sandbox.globalThis = sandbox; sandbox.self = sandbox;
vm.createContext(sandbox);
vm.runInContext(coreSrc, sandbox, { filename: 'iso-core.js' });
const C = sandbox.ISO_CORE;

const X = 192, Y = 48, Z = 192;
const run = () => { const w = new C.World(X, Y, Z); C.generate(w, seed, { caves: false }); return w; };
const t0 = Date.now();
const world = run();
const genMs = Date.now() - t0;
const t1 = Date.now();
C.computeLight(world);
const lightMs = Date.now() - t1;
const again = run();
const deterministic = Buffer.compare(Buffer.from(world.blocks), Buffer.from(again.blocks)) === 0
  && Buffer.compare(Buffer.from(world.fluid), Buffer.from(again.fluid)) === 0;

const spawn = C.spawnPoint(world);
const buffers = {
  blocks: world.blocks, fluid: world.fluid, sun: world.sun, blk: world.blk,
  surface: world.surface, biome: world.biome, waterLevel: world.waterLevel,
};
fs.mkdirSync(outDir, { recursive: true });
const files = {};
for (const [name, arr] of Object.entries(buffers)) {
  const raw = Buffer.from(arr.buffer, arr.byteOffset, arr.byteLength);
  const gz = zlib.gzipSync(raw, { level: 9 });
  fs.writeFileSync(path.join(outDir, `${name}.u8.gz`), gz);
  files[name] = { file: `${name}.u8.gz`, type: 'Uint8Array', bytes: raw.length, sha256: sha(raw), gz_sha256: sha(gz) };
}
// statistiche di controllo
const count = (arr, pred) => { let n = 0; for (let i = 0; i < arr.length; i++) if (pred(arr[i])) n++; return n; };
const blockHist = {};
for (let i = 0; i < world.blocks.length; i++) { const id = world.blocks[i]; blockHist[id] = (blockHist[id] || 0) + 1; }
let waterCols = 0;
for (let z = 0; z < Z; z++) for (let x = 0; x < X; x++) {
  for (let y = 0; y < Y; y++) if (world.blocks[world.idx(x, y, z)] === C.B.WATER) { waterCols++; break; }
}
const sample = C.meshChunk(world, 6, 1, 6, Y - 1);
let finite = true; for (const v of sample.position) if (!Number.isFinite(v)) { finite = false; break; }

const manifest = {
  source: { file: 'reference/isoterra_proto_v0_64_humanoids.html', sha256: sha(html), bytes: html.length, core_sha256: sha(Buffer.from(coreSrc)) },
  generator: { name: 'ISO_CORE.generate', version: 'v0_64', options: { caves: false }, seed, dims: { X, Y, Z }, chunk: C.CH,
    index: 'i = (y*Z + z)*X + x', light: 'computeLight(world) dopo generate' },
  block_ids: Object.fromEntries(Object.entries(C.B)),
  names: Array.from(C.NAMES),
  opaque: Array.from(C.OPAQUE), solid: Array.from(C.SOLID), emit: Array.from(C.EMIT),
  biomes: C.BIOMES.map((b) => b.name ?? b.id ?? b),
  spawn,
  stats: {
    cells: X * Y * Z, chunks: Math.ceil(X / C.CH) * Math.ceil(Y / C.CH) * Math.ceil(Z / C.CH),
    biome_share_pct: Array.from(world.biomeShare), lakes: world.waterInfo.lakes, rivers: world.waterInfo.rivers.length,
    water_level_cells: world.waterInfo.cells, water_columns: waterCols, water_blocks: count(world.blocks, (v) => v === C.B.WATER),
    block_histogram: blockHist, sample_chunk_6_1_6: { quads: sample.index.length / 6, vertices: sample.position.length / 3, finite },
    deterministic_two_runs: deterministic, gen_ms: genMs, light_ms: lightMs,
  },
  files,
};
fs.writeFileSync(path.join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 1) + '\n');
console.log(JSON.stringify({ outDir, spawn, deterministic, blocks_sha256: files.blocks.sha256, stats: manifest.stats }, null, 1));
