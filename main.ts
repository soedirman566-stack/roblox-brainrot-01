// BRAINROT TYCOON — the hand-in program for the roblox-brainrot-01 entry.
//
// The game itself is the Rojo project in this directory: Luau sources under
// src/ and a world described by default.project.json (emitted by
// tools/generate-project.mjs), built into game.rbxl with
//   rojo build default.project.json --output game.rbxl
// This program's one job is to hand that game in: it copies game.rbxl,
// PLAY.json, src/ and screenshots/ into the output directory and writes the
// dossier the judge reads, using the vendored make.fun library
// (vendor/makefun-roblox.ts, untouched).
//
// Names in the output must start with a letter, digit or underscore and use
// only letters, digits, '.', '_' and '-', so every copy below skips any
// name starting with a dot (.git, .DS_Store and friends would fail the
// entry). Outside the grader, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

const keepName = (path: string): boolean => !basename(path).startsWith('.');

// Pre-flight: the hand-in is only worth making if the built place and at
// least one Luau source are actually here — fail loudly rather than hand
// in a starter or an empty shell.
const luauFiles: string[] = [];
const collectLuau = (dir: string): void => {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) collectLuau(full);
    else if (entry.name.endsWith('.luau')) luauFiles.push(full);
  }
};
collectLuau(join(here, 'src'));
if (!existsSync(join(here, 'game.rbxl')) || luauFiles.length === 0) {
  throw new Error('game.rbxl or src/*.luau missing — build the game first (rojo build)');
}

mkdirSync(out, { recursive: true });
copyFileSync(join(here, 'game.rbxl'), join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: keepName });
mkdirSync(join(out, 'screenshots'), { recursive: true });
if (existsSync(join(here, 'screenshots'))) {
  cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: keepName });
}

// The dossier, with the scorer's caps passed through so this program fails
// exactly where the scorer would: too many or too heavy screenshots, a
// place past the instance cap, script sources or paths past their caps.
writeFileSync(
  join(out, 'dossier.json'),
  buildDossier(out, {
    text_max_bytes: 65536,
    screenshots: { max: 4, max_bytes: 262144 },
    max_instances: 500000,
    scripts_max_source_bytes: 8388608,
    scripts_max_path_chars: 1048576,
  }),
);

console.log(`Brainrot Tycoon handed in: game.rbxl, PLAY.json, ${luauFiles.length} Luau sources, screenshots/, dossier.json`);
