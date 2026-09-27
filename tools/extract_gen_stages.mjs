// Estrae dal prototipo (senza modificare l'HTML) le fixture di parita' del generatore e dei
// fluidi per il porting GDScript (WorldGenerator, FluidSystem, IsoNoise, JsMath).
// Il sorgente di ISO_CORE viene copiato e rattoppato con piccole sostituzioni di stringa
// per esporre le funzioni interne e agganciare callback fra le passate.
//
// Uscita: tests/fixtures/gen_v064/
//   samples.json            campioni di rumore, RNG, subSeed, Math.* (double come hex IEEE)
//   <nome>/manifest.json    sha256 per passata e per fase, statistiche, scenario gameplay
//   <nome>/*.gz             buffer completi (solo mondi piccoli: servono ai diff nei test)
// Uso: node tools/extract_gen_stages.mjs
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const htmlPath = path.join(root, 'reference/isoterra_proto_v0_64_humanoids.html');
const outRoot = path.join(root, 'tests/fixtures/gen_v064');

const html = fs.readFileSync(htmlPath);
const sha = (b) => crypto.createHash('sha256').update(b).digest('hex');
const m = html.toString('utf8').match(/<script id="iso-core">([\s\S]*?)<\/script>/);
if (!m) throw new Error('script iso-core non trovato');
const coreSrc = m[1];

// --- rattoppi (ognuno deve applicarsi esattamente una volta)
const patches = [
  // hook dopo ogni passata
  ['fn(c,mulberry32(subSeed(seed,name)));',
   'fn(c,mulberry32(subSeed(seed,name)));if(root.__afterPass)root.__afterPass(name,c,world);'],
  // hook prima/dopo shapeRiverBanks e dopo initFluid
  ['shapeRiverBanks(world);initFluid(world);for(let tick=0;tick<160&&world.fluidQueue.size;tick++)stepFluid(world,200000);',
   'if(root.__stage)root.__stage("pre_fluid",world,c);shapeRiverBanks(world);if(root.__stage)root.__stage("banks",world,c);initFluid(world);if(root.__stage)root.__stage("init_fluid",world,c);let __ticks=0;for(let tick=0;tick<160&&world.fluidQueue.size;tick++){stepFluid(world,200000);__ticks++;}world.__ticks=__ticks;'],
  // funzioni interne esposte
  ['const ISO_CORE={',
   'const ISO_CORE={__in:{hash3,smooth,subSeed,spline,GEN_PASSES,shapeRiverBanks,fluidPass,authoredFall,fluidSpread,wakeFluid,fluidDirty,fluidAt},'],
];
let src = coreSrc;
for (const [a, b] of patches) {
  const n = src.split(a).length - 1;
  if (n !== 1) throw new Error(`rattoppo non univoco (${n}): ${a.slice(0, 60)}`);
  src = src.replace(a, b);
}
const sandbox = { console, Math, Date };
sandbox.globalThis = sandbox; sandbox.self = sandbox;
vm.createContext(sandbox);
vm.runInContext(src, sandbox, { filename: 'iso-core-patched.js' });
const C = sandbox.ISO_CORE;
const I = C.__in;

const f64 = new Float64Array(1);
const hex = (v) => { f64[0] = v; return Buffer.from(f64.buffer).toString('hex'); };
const bytesOf = (arr) => Buffer.from(arr.buffer, arr.byteOffset, arr.byteLength);
const shaOf = (arr) => sha(bytesOf(arr));

// ---------------------------------------------------------------- campioni
function samples() {
  const R = C.mulberry32(20260927);
  const pts = [];
  for (let i = 0; i < 24; i++) pts.push([(R() - 0.5) * 400, (R() - 0.5) * 100, (R() - 0.5) * 400]);
  pts.push([0, 0, 0], [-0.5, -1e-9, 0.5], [1e6, 3, -1e6], [123.456, 7.89, -45.6]);
  const seeds = [1931, 7, 0, -5, 1931 + 9, 4194303, 4194304, 2147483647, -2147483648, 4294967295, 123456789012];
  const out = { mulberry32: {}, sub_seed: {}, hash3: [], noise2: [], noise3: [], fbm2: [], math: {}, round: [], spline: [] };
  for (const s of [0, 1, 7, 1931, -1, 2147483647, 4294967295, 3735928559]) {
    const r = C.mulberry32(s); out.mulberry32[s] = Array.from({ length: 12 }, () => hex(r()));
  }
  const names = I.GEN_PASSES.map((p) => p[0]).concat(['geografia', '', 'àè']);
  for (const s of [1931, 7, 0, -5, 2147483647, 4294967295]) {
    out.sub_seed[s] = Object.fromEntries(names.map((n) => [n, I.subSeed(s, n)]));
  }
  for (const s of seeds) {
    for (const [x, y, z] of pts.slice(0, 16)) {
      const xi = Math.floor(x), yi = Math.floor(y), zi = Math.floor(z);
      out.hash3.push([xi, yi, zi, s, hex(I.hash3(xi, yi, zi, s))]);
    }
    out.hash3.push([4000000, -3000000, 5000000, s, hex(I.hash3(4000000, -3000000, 5000000, s))]);
    for (const [x, y, z] of pts) {
      out.noise2.push([hex(x), hex(z), s, hex(C.noise2(x, z, s))]);
      out.noise3.push([hex(x), hex(y), hex(z), s, hex(C.noise3(x, y, z, s))]);
      out.fbm2.push([hex(x / 7), hex(z / 7), s, 3, hex(C.fbm2(x / 7, z / 7, s, 3))]);
    }
  }
  const MR = C.mulberry32(99);
  const fn = { sin: [], cos: [], exp: [], atan2: [], hypot: [] };
  const edge = [0, -0, 1, -1, 0.5, Math.PI, -Math.PI, Math.PI / 2, Math.PI / 4, 1e-9, 3 * Math.PI / 4, 700, -700, 710, -746, 1e6, 1e-300];
  for (const v of edge) { fn.sin.push([hex(v), hex(Math.sin(v))]); fn.cos.push([hex(v), hex(Math.cos(v))]); fn.exp.push([hex(v), hex(Math.exp(v))]); }
  for (let i = 0; i < 1200; i++) {
    const a = MR() * 170 - 20, b = -MR() * 120 + (i % 10 === 0 ? 100 : 0), c = MR() * 40 - 20, d = MR() * 40 - 20;
    fn.sin.push([hex(a), hex(Math.sin(a))]); fn.cos.push([hex(a), hex(Math.cos(a))]);
    fn.exp.push([hex(b), hex(Math.exp(b))]); fn.atan2.push([hex(c), hex(d), hex(Math.atan2(c, d))]);
    fn.hypot.push([hex(c), hex(d), hex(Math.hypot(c, d))]);
  }
  for (const [c, d] of [[0, 0], [0, -1], [-0, -1], [1, 0], [-1, 0], [0, 1], [1, 1], [-1, -1], [1e-20, 1e3], [1e3, 1e-20], [-1e3, -1e-20], [Infinity, 1], [1, Infinity], [Infinity, -Infinity]]) {
    fn.atan2.push([hex(c), hex(d), hex(Math.atan2(c, d))]); fn.hypot.push([hex(c), hex(d), hex(Math.hypot(c, d))]);
  }
  out.math = fn;
  for (const v of [0.5, -0.5, 1.5, -1.5, 2.5, -2.5, 0.49999999999999994, -0.49999999999999994, 4503599627370495.5, -7.5, 1e-300, 12.4999, -12.5001]) out.round.push([hex(v), hex(Math.round(v))]);
  const CONT = [[0, -2], [.30, 0], [.45, 1], [.52, 2], [.60, 7], [.80, 9], [1, 11]];
  for (let i = 0; i < 50; i++) { const x = MR() * 1.4 - 0.2; out.spline.push([hex(x), hex(I.spline(CONT, x))]); }
  return out;
}

// ---------------------------------------------------------------- mondi
const i16 = (arr) => arr; // Int16Array: i byte sono gia' little-endian
function runWorld(cfg) {
  const { X, Y, Z, seed, caves, full } = cfg;
  const passes = [];
  const stages = {};
  const bufs = {};
  sandbox.__afterPass = (name, c, world) => {
    const e = { name, blocks: shaOf(world.blocks), hh: shaOf(i16(c.HH)) };
    if (c.WL) e.wl = shaOf(c.WL);
    if (name === 'Campi') for (const k of Object.keys(c.F)) e['f_' + k] = shaOf(c.F[k]);
    if (name === 'Campi') e.massif = [hex(c.massif.x), hex(c.massif.z)];
    if (name === 'Laghi') e.lakes = c.lakes.map((l) => [hex(l.x), hex(l.z), hex(l.r), l.level, l.cells]);
    if (name === 'Fiumi') {
      e.rivers = c.rivers; e.river_mask = shaOf(world.riverMask); e.water_flow = shaOf(world.waterFlow);
      e.water_guide = shaOf(world.waterGuide); e.waterfall_mask = shaOf(world.waterfallMask);
      e.waterfall_base = shaOf(world.waterfallBase); e.waterfall_top = shaOf(world.waterfallTop);
    }
    if (name === 'Biomi') { e.biome = shaOf(world.biome); e.climate = shaOf(world.climate); }
    if (name === 'Strati') { e.surface = shaOf(world.surface); e.water_level = shaOf(world.waterLevel); }
    passes.push(e);
  };
  const stageBufs = {
    pre_fluid: ['blocks', 'biome', 'surface', 'waterLevel', 'climate', 'riverMask', 'waterfallMask', 'waterfallBase', 'waterfallTop', 'waterGuide', 'waterFlow'],
    banks: ['blocks', 'surface'],
    init_fluid: ['blocks', 'fluid', 'waterLevel', 'waterFlow', 'waterBodies'],
  };
  sandbox.__stage = (name, world) => {
    const s = {};
    for (const k of stageBufs[name]) {
      s[k] = shaOf(world[k]);
      if (full) bufs[`${name}.${k}`] = world[k];
    }
    if (name === 'init_fluid') {
      s.queue_size = world.fluidQueue.size;
      s.queue_head = Array.from(world.fluidQueue).slice(0, 20);
      s.queue_tail = Array.from(world.fluidQueue).slice(-20);
      s.dirty = Array.from(world.fluidDirty);
    }
    if (name === 'banks') s.bank_blocks = world.bankBlocks;
    stages[name] = s;
  };
  const world = new C.World(X, Y, Z);
  const t0 = Date.now();
  C.generate(world, seed, { caves });
  const genMs = Date.now() - t0;
  sandbox.__afterPass = null; sandbox.__stage = null;
  const finalNames = ['blocks', 'fluid', 'surface', 'biome', 'waterLevel', 'waterFlow', 'waterBodies', 'climate', 'riverMask', 'waterGuide'];
  const fin = {};
  for (const k of finalNames) { fin[k] = shaOf(world[k]); if (full) bufs[`final.${k}`] = world[k]; }
  fin.queue_size = world.fluidQueue.size;
  fin.dirty = Array.from(world.fluidDirty);
  const stats = {
    ticks: world.__ticks, spawn: C.spawnPoint(world), biome_share: world.biomeShare, massif: [hex(world.massif.x), hex(world.massif.z)],
    lakes: world.waterInfo.lakes, rivers: world.waterInfo.rivers, cells: world.waterInfo.cells, bank_blocks: world.bankBlocks,
    gen_log: world.genLog, gen_ms: genMs,
  };
  const gameplay = cfg.gameplay ? scenario(world) : null;
  return { cfg, passes, stages, final: fin, stats, gameplay, bufs };
}

// Scenario "gameplay" sul mondo generato: campioni d'acqua, poi si scava accanto
// all'acqua (editFluid) e si fanno 40 tick di stepFluid col budget di default.
function scenario(world) {
  const { X, Y, Z } = world;
  const out = { samples: [], spread: [], ticks: [] };
  const MR = C.mulberry32(4242);
  const wet = [];
  for (let z = 0; z < Z; z++) for (let x = 0; x < X; x++) if (world.waterLevel[z * X + x]) wet.push([x, z]);
  for (let k = 0; k < 60; k++) {
    let x, z, y;
    if (k < 40 && wet.length) { const p = wet[(MR() * wet.length) | 0]; x = p[0] + MR(); z = p[1] + MR(); y = world.waterLevel[(p[1]) * X + p[0]] - 1.5 + MR() * 2; }
    else { x = MR() * X; z = MR() * Z; y = MR() * Y; }
    const s = C.sampleWater(world, x, y, z);
    out.samples.push({ p: [hex(x), hex(y), hex(z)], wet: s.wet, level: hex(s.level), depth: hex(s.depth), floor: s.floor ?? null,
      immersion: hex(s.immersion), flow: [hex(s.flowX), hex(s.flowY), hex(s.flowZ)], body: s.body, falling: s.falling });
  }
  // fluidSpread / fluidSurface / fluidCorner su celle d'acqua
  const cache = new Map();
  let n = 0;
  for (let i = 0; i < world.fluid.length && n < 200; i++) {
    if (!world.fluid[i]) continue; if (MR() > 0.2) continue;
    const XZ = X * Z, y = (i / XZ) | 0, z = ((i - y * XZ) / X) | 0, x = i % X;
    const v = C.fluidVelocity(world, x, y, z);
    out.spread.push([x, y, z, I.fluidSpread(world, x, y, z, cache), hex(C.fluidCorner(world, x, y, z)), hex(C.fluidHeight(world, x, y, z)),
      hex(C.fluidSurface(world, x + 0.3, y, z + 0.6)), hex(v.x), hex(v.y), hex(v.z)]);
    n++;
  }
  // edit: scava pozzi di 3 celle accanto all'acqua, toglie una sorgente e versa acqua
  // in aria sopra il terreno (cascate e spandimento libero)
  const edits = [];
  const step = Math.max(1, (wet.length / 6) | 0);
  for (let k = 0; k < wet.length && edits.length < 18; k += step) {
    const [wx, wz] = wet[k]; const y = world.waterLevel[wz * X + wx] - 1;
    for (const [dx, dz] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const x = wx + dx, z = wz + dz;
      if (world.inside(x, y, z) && world.isSolidAt(x, y, z) && y > 3) {
        for (let yy = y; yy > y - 3; yy--) if (world.isSolidAt(x, yy, z)) edits.push([x, yy, z, 0]);
        break;
      }
    }
  }
  if (wet.length) { const [wx, wz] = wet[wet.length >> 1]; edits.push([wx, world.waterLevel[wz * X + wx] - 1, wz, 0]); }
  for (let k = 0; k < 3; k++) { const x = 4 + ((MR() * (X - 8)) | 0), z = 4 + ((MR() * (Z - 8)) | 0), y = Math.min(Y - 2, world.surface[z * X + x] + 3); edits.push([x, y, z, C.B.WATER]); }
  for (const [x, y, z, id] of edits) { world.set(x, y, z, id); C.editFluid(world, x, y, z, id); }
  out.edits = edits;
  out.after_edit = { queue_size: world.fluidQueue.size, queue_head: Array.from(world.fluidQueue).slice(0, 30), dirty: Array.from(world.fluidDirty) };
  for (let t = 0; t < 40; t++) {
    const upd = C.stepFluid(world);
    out.ticks.push({ updates: upd.length, upd_sha: sha(Buffer.from(Int32Array.from(upd.flat()).buffer)), queue: world.fluidQueue.size,
      fluid: shaOf(world.fluid), blocks: shaOf(world.blocks), water_level: shaOf(world.waterLevel), water_flow: shaOf(world.waterFlow), water_bodies: shaOf(world.waterBodies) });
  }
  out.final_dirty = Array.from(world.fluidDirty);
  return out;
}

function writeWorld(name, res) {
  const dir = path.join(outRoot, name);
  fs.mkdirSync(dir, { recursive: true });
  const files = {};
  for (const [k, arr] of Object.entries(res.bufs)) {
    const raw = bytesOf(arr);
    fs.writeFileSync(path.join(dir, `${k}.gz`), zlib.gzipSync(raw, { level: 9 }));
    files[k] = { file: `${k}.gz`, bytes: raw.length, sha256: sha(raw) };
  }
  const { bufs, ...rest } = res;
  const manifest = { source: { file: 'reference/isoterra_proto_v0_64_humanoids.html', sha256: sha(html), core_sha256: sha(Buffer.from(coreSrc)) },
    tool: 'tools/extract_gen_stages.mjs', ...rest, files };
  fs.writeFileSync(path.join(dir, 'manifest.json'), JSON.stringify(manifest, null, 1) + '\n');
  console.log(name, JSON.stringify({ ticks: res.stats.ticks, spawn: res.stats.spawn, lakes: res.stats.lakes, rivers: res.stats.rivers, gen_ms: res.stats.gen_ms }));
}

fs.mkdirSync(outRoot, { recursive: true });
fs.writeFileSync(path.join(outRoot, 'samples.json'), JSON.stringify(samples()) + '\n');
writeWorld('seed7_64x32x64_caves', runWorld({ X: 64, Y: 32, Z: 64, seed: 7, caves: true, full: true, gameplay: true }));
writeWorld('seed1931_96x40x80_caves', runWorld({ X: 96, Y: 40, Z: 80, seed: 1931, caves: true, full: false, gameplay: true }));
writeWorld('seed1931_192x48x192', runWorld({ X: 192, Y: 48, Z: 192, seed: 1931, caves: false, full: false, gameplay: true }));
writeWorld('seed42_192x48x192_caves', runWorld({ X: 192, Y: 48, Z: 192, seed: 42, caves: true, full: false, gameplay: false }));
