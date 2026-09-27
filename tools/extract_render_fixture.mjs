// Riferimenti per M2 (resa) estratti dal prototipo v0_64 senza modificarlo:
// clima, densita', mesh greedy di ogni chunk, atlante e texture dell'erba (canvas
// emulato), alberi (posizioni e template) e fili d'erba per colonna di chunk.
// Uso: node tools/extract_render_fixture.mjs [seed] [outDir]
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const html = fs.readFileSync(path.join(root, 'reference/isoterra_proto_v0_64_humanoids.html'), 'utf8');
const seed = Number(process.argv[2] ?? 1931);
const outDir = path.resolve(process.argv[3] ?? path.join(root, 'tests/fixtures', `seed${seed}_v064_render`));
const sha = (b) => crypto.createHash('sha256').update(b).digest('hex');
const bytes = (a) => Buffer.from(a.buffer, a.byteOffset, a.byteLength);

const coreSrc = html.match(/<script id="iso-core">([\s\S]*?)<\/script>/)[1];
const sandbox = { console, Math, Date };
sandbox.globalThis = sandbox; sandbox.self = sandbox;
vm.createContext(sandbox);
vm.runInContext(coreSrc, sandbox);
const C = sandbox.ISO_CORE;

// Canvas 2D minimo: solo fillStyle ('#rgb', '#rrggbb', 'rgb(r,g,b)') e fillRect interi.
function fakeCanvas(w, h) {
  const px = new Uint8Array(w * h * 4);
  let style = [0, 0, 0, 255];
  const parse = (s) => {
    let m;
    if ((m = s.match(/^#([0-9a-f]{3})$/i))) return [...m[1]].map((c) => parseInt(c + c, 16)).concat(255);
    if ((m = s.match(/^#([0-9a-f]{6})$/i))) return [0, 2, 4].map((i) => parseInt(m[1].substr(i, 2), 16)).concat(255);
    if ((m = s.match(/^rgb\((\d+),(\d+),(\d+)\)$/))) return [+m[1], +m[2], +m[3], 255];
    throw new Error('colore non gestito: ' + s);
  };
  const ctx = {
    set fillStyle(s) { style = parse(s); },
    fillRect(x, y, fw, fh) {
      for (let yy = y; yy < y + fh; yy++) for (let xx = x; xx < x + fw; xx++) {
        if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
        px.set(style, (yy * w + xx) * 4);
      }
    },
  };
  return { ctx, px };
}

// makeAtlas (HTML ~5704): stesso codice, canvas emulato.
function makeAtlas() {
  const { ctx: g, px: out } = fakeCanvas(256, 32);
  const rng = C.mulberry32(7);
  const px = (x, y, c) => { g.fillStyle = c; g.fillRect(x, y, 1, 1); };
  const speck = (tx, row, base, dark, light, dens) => { for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) { const r = rng(); px(tx * 16 + x, row * 16 + y, r < dens ? dark : r > 1 - dens * .6 ? light : base); } };
  const both = (t, b, d, l, dens) => { speck(t, 0, b, d, l, dens); speck(t, 1, b, d, l, dens); };
  const ore = (t, dotC) => { both(t, '#6f7478', '#565b60', '#858a8f', .16); for (let row = 0; row < 2; row++) for (let i = 0; i < 7; i++) { const x = 1 + Math.floor(rng() * 13), y = 1 + Math.floor(rng() * 13); px(t * 16 + x, row * 16 + y, dotC); px(t * 16 + x + 1, row * 16 + y, dotC); px(t * 16 + x, row * 16 + y + 1, dotC); } };
  both(0, '#f0f', '#f0f', '#f0f', 0); speck(1, 0, '#5aa63b', '#478a2d', '#77c14e', .2); speck(1, 1, '#8a6a45', '#6f5335', '#a3805a', .18);
  both(2, '#8a6a45', '#6f5335', '#a3805a', .18); both(3, '#6f7478', '#565b60', '#858a8f', .16); both(4, '#d9c47e', '#c4ae66', '#ecd996', .14);
  ore(5, '#d9843a'); ore(6, '#d8c3a5'); ore(7, '#f2d43a'); both(8, '#2e3236', '#202326', '#3c4045', .3); both(9, '#f0782a', '#d5511c', '#ffd05a', .25); both(10, '#c9973a', '#8a5a24', '#ffe680', .2);
  both(11, '#a37c4f', '#7e5c37', '#c39a66', .12); both(12, '#3f7d2f', '#2f6222', '#5a9a42', .28); both(13, '#c9a86a', '#b09056', '#dcc084', .12); both(14, '#45484d', '#33363a', '#55595e', .2);
  return out;
}

// Texture dei fili d'erba (HTML 6734): 32x16, rosso = tono, alfa = pieno.
function makeLeaf() {
  const { ctx: g, px } = fakeCanvas(32, 16);
  const tuft = (ox, blades) => { for (const [x, hh, ln] of blades) for (let y = 0; y < hh; y++) { const t = y / hh; const xx = ox + x + Math.round(ln * t * t * 2); const tone = t > .72 ? 255 : (t > .30 ? 214 : 176); g.fillStyle = 'rgb(' + tone + ',0,0)'; g.fillRect(xx, y, (t < .45 && hh > 7) ? 2 : 1, 1); } };
  tuft(0, [[1, 7, -1], [3, 11, 0], [5, 14, 1], [7, 10, -1], [9, 15, 0], [11, 9, 1], [13, 12, -1], [14, 6, 1]]); tuft(16, [[0, 6, 1], [2, 12, -1], [4, 9, 0], [6, 15, 1], [8, 11, 0], [10, 13, -1], [12, 8, 1], [14, 10, 0]]);
  return px;
}

const X = 192, Y = 48, Z = 192;
const w = new C.World(X, Y, Z);
C.generate(w, seed, { caves: false });
C.computeLight(w);
C.computeDensity(w);

fs.mkdirSync(outDir, { recursive: true });
const files = {};
const save = (name, arr) => {
  const raw = bytes(arr);
  fs.writeFileSync(path.join(outDir, `${name}.gz`), zlib.gzipSync(raw, { level: 9 }));
  files[name] = { file: `${name}.gz`, bytes: raw.length, sha256: sha(raw) };
};
save('climate.u8', w.climate);
save('density.u8', w.density);
save('atlas.rgba', makeAtlas());
save('leaf.rgba', makeLeaf());

const chunks = [];
let totalQuads = 0;
for (let cy = 0; cy < Y / 16; cy++) for (let cz = 0; cz < Z / 16; cz++) for (let cx = 0; cx < X / 16; cx++) {
  const m = C.meshChunk(w, cx, cy, cz, Y - 1);
  totalQuads += m.quads;
  chunks.push({ c: [cx, cy, cz], quads: m.quads, pos: sha(bytes(m.position)), uv: sha(bytes(m.uv)), data: sha(bytes(m.data)), index: sha(bytes(m.index)) });
}

const spots = C.treeSpots(w, seed);
// Binario Float64: il parser JSON di Godot non arrotonda correttamente i decimali lunghi.
save('tree_spots.f64', new Float64Array(spots.flatMap((s) => [s.x, s.y, s.z, s.kind, s.rot, s.scale, s.seed])));
const templates = [];
for (let k = 0; k < 3; k++) for (let v = 0; v < 2; v++) {
  const t = C.makeTreeTemplate(k, seed * 7 + k * 13 + v * 101);
  templates.push({ kind: k, variant: v, seed: seed * 7 + k * 13 + v * 101, verts: t.verts, height: t.height, sha256: sha(bytes(t.data)) });
  save(`tree_template_${k}_${v}.f32`, t.data);
}
const grass = [];
let totalBlades = 0;
for (let cz = 0; cz < Z / 16; cz++) for (let cx = 0; cx < X / 16; cx++) {
  const b = C.grassBlades(w, cx, cz, seed, .27);
  totalBlades += b.length / 7;
  grass.push({ c: [cx, cz], blades: b.length / 7, sha256: sha(bytes(b)) });
  if (cx === 6 && cz === 6) save('grass_6_6.f32', b);
}
const ground = [];
for (const [x, z] of [[96.5, 96.5], [10.2, 150.7], [100.25, 40.75], [150, 150], [0.3, 191.6]]) ground.push({ x, z, h: C.groundHeight(w, x, z) });

const manifest = {
  source_sha256: sha(Buffer.from(html)), seed, dims: { X, Y, Z },
  notes: 'meshChunk(world,cx,cy,cz,Y-1) dopo computeLight; hash su Float32/Uint8/Uint32 little-endian. grassBlades densita .27 come il worker. Winding Three.js (antiorario).',
  files, totals: { quads: totalQuads, trees: spots.length, blades: totalBlades },
  chunks, templates, grass, ground,
  tree_spots: spots.map((s) => [s.x, s.y, s.z, s.kind, s.rot, s.scale, s.seed]),
  biome_vegetation: C.BIOMES.map((b) => ({ id: b.id, name: b.name, trees: b.trees, kinds: b.kinds, treeScale: b.treeScale, grassKeep: b.grassKeep, grassH: b.grassH })),
};
fs.writeFileSync(path.join(outDir, 'manifest.json.gz'), zlib.gzipSync(JSON.stringify(manifest)));
console.log(JSON.stringify({ outDir, totals: manifest.totals, files: Object.keys(files) }));
