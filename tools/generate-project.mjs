// generate-project.mjs — emits default.project.json for BRAINROT TYCOON.
//
// The world is laid out by code so the six base plots, the conveyor lane,
// the shop row and the decorations stay regular: loops place them, this
// file is the source of truth, and `node tools/generate-project.mjs`
// rewrites default.project.json next to the repo root. Rojo then builds
// game.rbxl from that JSON plus the Luau sources under src/.
//
// Layout (studs, X east / Z south):
//   - the conveyor lane runs along Z = 0 from X -105 (shop end) to X +105,
//     a red carpet on the belt, glowing edge strips, and six arches over
//     it carrying the rarity ladder COMMON -> DEWA LANGIT.
//   - six base plots, three north (Z -56) and three south (Z +56). Each
//     is a furnished pen: carpet, 24 podium pads, wall trim, a money
//     vault, a rebirth crystal, an egg nest and a pen-upgrade post.
//   - the shop row sits at the west end; the egg hatchery just south of
//     it; the lucky block stand just north of it; the treadmill station
//     east of the spawn plaza.
//   - players spawn on a checkered plaza west of the lane, under a sign
//     tower whose block letters spell BRAINROT TYCOON — the in-world logo.

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const rgb = (r, g, b) => [r / 255, g / 255, b / 255];
const lighten = (color, f) => color.map((c) => c + (1 - c) * f);

function part(size, position, color, extra = {}) {
  return {
    $className: 'Part',
    $properties: {
      Anchored: true,
      Color: color,
      Position: position,
      Size: size,
      ...extra,
    },
  };
}

// A sign board: a plain part here; the server Signs module finds every
// named board at runtime and hangs a SurfaceGui text label on it, because
// Rojo's project JSON cannot express UDim2 sizes.
function sign(size, position, color) {
  return part(size, position, color);
}

function tree(x, z, trunkColor, leafColor) {
  return {
    Trunk: part([2, 9, 2], [x, 4.5, z], trunkColor),
    Canopy: part([11, 11, 11], [x, 13, z], leafColor, { Shape: 'Ball' }),
    CanopyTop: part([7, 7, 7], [x, 18, z], leafColor, { Shape: 'Ball' }),
  };
}

function lamp(x, z) {
  return {
    Pole: part([1, 12, 1], [x, 6, z], rgb(40, 40, 48)),
    Head: part([2.4, 2.4, 2.4], [x, 12.6, z], rgb(255, 226, 130)),
  };
}

const BASE_COLORS = [
  rgb(232, 76, 76),
  rgb(76, 132, 232),
  rgb(88, 204, 110),
  rgb(245, 197, 66),
  rgb(168, 102, 232),
  rgb(245, 140, 66),
];
const BASE_NAMES = ['Base1', 'Base2', 'Base3', 'Base4', 'Base5', 'Base6'];
// North row west→east, then south row west→east.
const BASE_CENTERS = [
  [-72, -56], [0, -56], [72, -56],
  [-72, 56], [0, 56], [72, 56],
];

function basePlot(index) {
  const [cx, cz] = BASE_CENTERS[index];
  const color = BASE_COLORS[index];
  const dir = cz < 0 ? 1 : -1; // entrance side faces the lane at Z = 0
  const node = {
    $className: 'Folder',
    Floor: part([42, 1, 42], [cx, 0, cz], color),
    // A carpet inset so the pen reads as furnished, not a bare slab.
    Carpet: part([36, 0.18, 36], [cx, 0.56, cz], lighten(color, 0.35)),
    // Low walls on the four edges so a plot reads as its own yard, with
    // a roofline trim beam along the top of each wall.
    WallN: part([42, 2.4, 1.4], [cx, 1.2, cz - 21], color),
    WallS: part([42, 2.4, 1.4], [cx, 1.2, cz + 21], color),
    WallW: part([1.4, 2.4, 42], [cx - 21, 1.2, cz], color),
    WallE: part([1.4, 2.4, 42], [cx + 21, 1.2, cz], color),
    TrimN: part([42, 0.8, 1.9], [cx, 2.85, cz - 21], lighten(color, 0.45)),
    TrimS: part([42, 0.8, 1.9], [cx, 2.85, cz + 21], lighten(color, 0.45)),
    TrimW: part([1.9, 0.8, 42], [cx - 21, 2.85, cz], lighten(color, 0.45)),
    TrimE: part([1.9, 0.8, 42], [cx + 21, 2.85, cz], lighten(color, 0.45)),
    // The pad the owner respawns on, by the plot's entrance.
    HomePad: part([6, 0.7, 6], [cx, 0.85, cz + dir * 17.8], rgb(245, 245, 245)),
    // Step here to lock the base against thieves for a minute.
    LockPad: part([5, 0.7, 5], [cx + 13, 0.85, cz + dir * 17.8], rgb(30, 30, 36)),
    // The incubator nest: bought eggs sit here until they hatch.
    Nest: part([6, 1, 6], [cx - 13, 0.5, cz + dir * 17.8], rgb(196, 158, 92)),
    // The money vault prop in the back corner.
    Vault: part([5, 4.5, 4], [cx - 17, 2.25, cz - dir * 16], rgb(52, 54, 64)),
    VaultDoor: part([3, 3, 0.4], [cx - 17, 2.1, cz - dir * 13.8], rgb(255, 205, 55)),
    // A little rebirth corner marker: pedestal + glowing crystal.
    RebirthPedestal: part([2, 1.6, 2], [cx + 17, 0.8, cz - dir * 16], rgb(120, 120, 130)),
    RebirthCrystal: part([1.8, 1.8, 1.8], [cx + 17, 2.6, cz - dir * 16], rgb(168, 102, 232), { Material: 'Neon', Shape: 'Ball' }),
    SignPost: part([2, 9, 2], [cx - 17, 4.5, cz + dir * 19], rgb(60, 48, 36)),
    SignBoard: sign([16, 6, 1], [cx - 17, 11, cz + dir * 19], color),
    // The pen-upgrade post and its little level board.
    PenPost: part([1.6, 7, 1.6], [cx + 18.5, 3.5, cz + dir * 10], rgb(90, 70, 40)),
    PenBoard: sign([8, 4, 0.8], [cx + 18.5, 8.6, cz + dir * 10], rgb(60, 48, 36)),
  };
  // Nest twigs: four little rails around the nest so it reads as a nest.
  node.NestTwig1 = part([6.6, 0.5, 0.8], [cx - 13, 1.15, cz + dir * 17.8 - 3.1], rgb(120, 84, 44));
  node.NestTwig2 = part([6.6, 0.5, 0.8], [cx - 13, 1.15, cz + dir * 17.8 + 3.1], rgb(120, 84, 44));
  node.NestTwig3 = part([0.8, 0.5, 6.6], [cx - 16.1, 1.15, cz + dir * 17.8], rgb(120, 84, 44));
  node.NestTwig4 = part([0.8, 0.5, 6.6], [cx - 9.9, 1.15, cz + dir * 17.8], rgb(120, 84, 44));
  // Twenty-four display pads, four rows of six, where bought brainrots
  // stand. The pen level decides how many are unlocked (6 at level 1,
  // all 24 at level 20); PlotManager paints the locked ones dim.
  const padCols = [-15, -9, -3, 3, 9, 15];
  const padRows = [-16, -7, 2, 11];
  let padIndex = 0;
  for (const dz of padRows) {
    for (const dx of padCols) {
      padIndex += 1;
      node[`Pad${padIndex}`] = part([5.5, 0.7, 5.5], [cx + dx, 0.85, cz + dz], rgb(238, 232, 218));
    }
  }
  return node;
}

function stall(x, z, roofColor) {
  return {
    Counter: part([12, 3, 4], [x, 1.5, z], rgb(150, 108, 66)),
    PostL: part([1, 8, 1], [x - 5.5, 4, z - 1.5], rgb(110, 78, 46)),
    PostR: part([1, 8, 1], [x + 5.5, 4, z - 1.5], rgb(110, 78, 46)),
    Roof: part([14, 1.2, 7], [x, 8.6, z], roofColor),
  };
}

// A conveyor arch: two posts, a beam, and a hanging board the Signs
// module labels with one rung of the rarity ladder.
function arch(x, boardName, boardColor) {
  return {
    PostN: part([1.4, 13, 1.4], [x, 6.5, -8.5], rgb(52, 52, 62)),
    PostS: part([1.4, 13, 1.4], [x, 6.5, 8.5], rgb(52, 52, 62)),
    Beam: part([2, 2, 19], [x, 13.6, 0], rgb(245, 197, 66)),
    [boardName]: sign([15, 4.2, 1], [x, 10.4, 0], boardColor),
  };
}

// 3x5 pixel letters for the sign tower — the in-world BRAINROT TYCOON logo.
const FONT = {
  B: ['##.', '#.#', '##.', '#.#', '##.'],
  R: ['##.', '#.#', '##.', '#.#', '#.#'],
  A: ['.#.', '#.#', '###', '#.#', '#.#'],
  I: ['###', '.#.', '.#.', '.#.', '###'],
  N: ['#.#', '###', '###', '#.#', '#.#'],
  O: ['.#.', '#.#', '#.#', '#.#', '.#.'],
  T: ['###', '.#.', '.#.', '.#.', '.#.'],
  Y: ['#.#', '#.#', '.#.', '.#.', '.#.'],
  C: ['.##', '#..', '#..', '#..', '.##'],
  U: ['#.#', '#.#', '#.#', '#.#', '###'],
};

function letterRow(text, centerX, topY, z, block, color) {
  const parts = {};
  const letterWidth = 3 * block;
  const gap = block * 1.15;
  const totalWidth = text.length * letterWidth + (text.length - 1) * gap;
  let cursorX = centerX - totalWidth / 2;
  let n = 0;
  for (const ch of text) {
    const glyph = FONT[ch];
    if (glyph) {
      for (let row = 0; row < 5; row += 1) {
        for (let col = 0; col < 3; col += 1) {
          if (glyph[row][col] === '#') {
            n += 1;
            parts[`Block${text}${n}`] = part(
              [block, block, block],
              [cursorX + col * block + block / 2, topY - row * block - block / 2, z],
              color,
              { CanCollide: false, Material: 'Neon' },
            );
          }
        }
      }
    }
    cursorX += letterWidth + gap;
  }
  return parts;
}

const workspace = {
  $properties: { FilteringEnabled: true },
  Ground: part([460, 2, 460], [0, -1.2, 0], rgb(80, 204, 90)),
  // Ground colour variation: darker aprons under the base rows, sand
  // under the shop quarter, a dirt path from spawn to the lane.
  ApronN: part([320, 0.08, 54], [0, 0.01, -56], rgb(62, 184, 72), { CanCollide: false }),
  ApronS: part([320, 0.08, 54], [0, 0.01, 56], rgb(62, 184, 72), { CanCollide: false }),
  ShopSand: part([52, 0.08, 76], [-124, 0.02, 10], rgb(214, 188, 138), { CanCollide: false }),
  DirtPath: part([12, 0.08, 38], [-88, 0.02, 12], rgb(166, 128, 84), { CanCollide: false }),
  SpawnLocation: {
    $className: 'SpawnLocation',
    $properties: {
      Anchored: true,
      Color: rgb(240, 240, 240),
      Neutral: true,
      Position: [-88, 0.6, 30],
      Size: [10, 1, 10],
    },
  },
  Lane: {
    $className: 'Folder',
    Belt: part([216, 1, 12], [0, 0.5, 0], rgb(46, 46, 56)),
    // The red carpet the brainrots ride on.
    Carpet: part([216, 0.1, 7], [0, 1.03, 0], rgb(226, 34, 48)),
    RailNorth: part([216, 1.6, 1.2], [0, 1.3, -6.8], rgb(245, 197, 66)),
    RailSouth: part([216, 1.6, 1.2], [0, 1.3, 6.8], rgb(245, 197, 66)),
    // Glowing edge strips (DayNight switches the material at night).
    GlowStripN: part([216, 0.35, 0.6], [0, 1.35, -6.05], rgb(120, 240, 255)),
    GlowStripS: part([216, 0.35, 0.6], [0, 1.35, 6.05], rgb(255, 140, 220)),
    StartMarker: part([2, 1, 12], [-104, 0.6, 0], rgb(88, 204, 110), { Transparency: 0.4 }),
    EndMarker: part([2, 1, 12], [104, 0.6, 0], rgb(232, 76, 76), { Transparency: 0.4 }),
    // The rarity ladder, arch by arch, west to east.
    Arch1: { $className: 'Folder', ...arch(-84, 'ArchSignCommon', rgb(178, 190, 181)) },
    Arch2: { $className: 'Folder', ...arch(-50, 'ArchSignRare', rgb(84, 150, 255)) },
    Arch3: { $className: 'Folder', ...arch(-16, 'ArchSignEpic', rgb(178, 102, 255)) },
    Arch4: { $className: 'Folder', ...arch(18, 'ArchSignLegendary', rgb(255, 196, 46)) },
    Arch5: { $className: 'Folder', ...arch(52, 'ArchSignMythic', rgb(255, 84, 150)) },
    Arch6: { $className: 'Folder', ...arch(86, 'ArchSignDewa', rgb(255, 242, 194)) },
  },
  Shop: {
    $className: 'Folder',
    Platform: part([34, 1, 30], [-124, 0, 0], rgb(196, 164, 120)),
    StallA: { $className: 'Folder', ...stall(-124, -9, rgb(232, 76, 76)) },
    StallB: { $className: 'Folder', ...stall(-124, 3, rgb(76, 132, 232)) },
    // Striped awnings leaning over the counters, neon boards above.
    AwningA: part([9, 0.5, 14], [-119.5, 7.4, -9], rgb(245, 245, 245), { Rotation: [0, 0, -16] }),
    AwningB: part([9, 0.5, 14], [-119.5, 7.4, 3], rgb(245, 245, 245), { Rotation: [0, 0, -16] }),
    ShopGlowA: part([10, 2.2, 0.6], [-120.5, 10.4, -9], rgb(255, 110, 180), { Material: 'Neon' }),
    ShopGlowB: part([10, 2.2, 0.6], [-120.5, 10.4, 3], rgb(110, 220, 255), { Material: 'Neon' }),
    // A neon trim along the platform's lane-facing edge.
    NeonTrim: part([0.5, 0.5, 30], [-106.8, 0.75, 0], rgb(120, 240, 255), { Material: 'Neon', CanCollide: false }),
    SignBoard: sign([26, 7, 1.4], [-124, 13, -14], rgb(120, 72, 20)),
    SignPostL: part([1.6, 10, 1.6], [-136, 5, -14], rgb(110, 78, 46)),
    SignPostR: part([1.6, 10, 1.6], [-112, 5, -14], rgb(110, 78, 46)),
  },
  // The egg hatchery: six glowing eggs on pedestals, one per tier.
  EggStation: {
    $className: 'Folder',
    Platform: part([32, 1, 18], [-124, 0, 26], rgb(214, 188, 138)),
    NeonTrim: part([0.5, 0.5, 18], [-107.8, 0.75, 26], rgb(255, 140, 220), { Material: 'Neon', CanCollide: false }),
    EggStationSign: sign([24, 6, 1.2], [-124, 10, 17.2], rgb(150, 80, 120)),
    SignPostL: part([1.6, 10, 1.6], [-135, 5, 17.2], rgb(110, 78, 46)),
    SignPostR: part([1.6, 10, 1.6], [-113, 5, 17.2], rgb(110, 78, 46)),
  },
  // The lucky block stand, north of the shop row: two display blocks
  // on pedestals (the server LuckyBlocks module builds the blocks and
  // hangs the buy prompts on them) and three opening pads where a
  // bought block waits to be cracked open.
  LuckyBlockStand: {
    $className: 'Folder',
    Platform: part([34, 1, 20], [-124, 0, -25], rgb(120, 96, 170)),
    Pedestal1: part([4.4, 2, 4.4], [-133, 1, -29], rgb(70, 60, 110)),
    Pedestal2: part([4.4, 2, 4.4], [-115, 1, -29], rgb(70, 60, 110)),
    OpeningPad1: part([6, 0.5, 6], [-136, 0.75, -19], rgb(238, 232, 218)),
    OpeningPad2: part([6, 0.5, 6], [-124, 0.75, -19], rgb(238, 232, 218)),
    OpeningPad3: part([6, 0.5, 6], [-112, 0.75, -19], rgb(238, 232, 218)),
    // A striped canopy over the display blocks, fairground style.
    CanopyPostL: part([1, 9, 1], [-139, 4.5, -29], rgb(110, 78, 46)),
    CanopyPostR: part([1, 9, 1], [-109, 4.5, -29], rgb(110, 78, 46)),
    Canopy: part([33, 0.8, 9], [-124, 9.4, -29], rgb(255, 208, 40)),
    CanopyStripe: part([33, 0.85, 3], [-124, 9.42, -29], rgb(226, 34, 48)),
    LuckySign: sign([24, 6, 1.2], [-124, 13.5, -29], rgb(120, 72, 20)),
    SignPostL: part([1.6, 13, 1.6], [-135, 6.5, -29], rgb(110, 78, 46)),
    SignPostR: part([1.6, 13, 1.6], [-113, 6.5, -29], rgb(110, 78, 46)),
    // A neon trim along the platform's lane-facing edge.
    NeonTrim: part([0.5, 0.5, 20], [-106.8, 0.75, -25], rgb(140, 255, 170), { Material: 'Neon', CanCollide: false }),
  },
  // The treadmill station, east of the spawn plaza: run on the belt,
  // win brainrots. The server Treadmill module finds Belt by name.
  Treadmill: {
    $className: 'Folder',
    Platform: part([18, 1, 13], [-64, 0, 30], rgb(110, 120, 140)),
    Belt: part([11, 0.6, 4.5], [-64, 0.8, 30], rgb(30, 30, 36)),
    BeltStripe1: part([0.8, 0.66, 4.5], [-67, 0.8, 30], rgb(70, 70, 84)),
    BeltStripe2: part([0.8, 0.66, 4.5], [-64, 0.8, 30], rgb(70, 70, 84)),
    BeltStripe3: part([0.8, 0.66, 4.5], [-61, 0.8, 30], rgb(70, 70, 84)),
    RailL: part([11, 0.5, 0.5], [-64, 1.7, 27.6], rgb(190, 195, 205)),
    RailR: part([11, 0.5, 0.5], [-64, 1.7, 32.4], rgb(190, 195, 205)),
    ConsolePost: part([0.8, 4.5, 0.8], [-58.2, 2.25, 30], rgb(52, 52, 62)),
    ConsoleScreen: part([0.4, 2.4, 3.4], [-58.2, 5.2, 30], rgb(90, 255, 200)),
    TreadmillSign: sign([15, 4.5, 1], [-64, 9, 23.2], rgb(40, 120, 80)),
    SignPostL: part([1.4, 9, 1.4], [-71, 4.5, 23.2], rgb(70, 70, 80)),
    SignPostR: part([1.4, 9, 1.4], [-57, 4.5, 23.2], rgb(70, 70, 80)),
    UpgradePost: part([1.6, 6, 1.6], [-72.5, 3, 30], rgb(46, 140, 90)),
    UpgradeCap: part([1.7, 1.7, 1.7], [-72.5, 6.6, 30], rgb(255, 205, 55), { Shape: 'Ball' }),
  },
  Shrine: {
    $className: 'Folder',
    Platform: part([24, 1.4, 24], [126, 0.2, 0], rgb(88, 60, 140), { Shape: 'Cylinder' }),
    PillarA: part([2.4, 13, 2.4], [118, 6.5, -8], rgb(210, 190, 255)),
    PillarB: part([2.4, 13, 2.4], [134, 6.5, -8], rgb(210, 190, 255)),
    PillarC: part([2.4, 13, 2.4], [118, 6.5, 8], rgb(210, 190, 255)),
    PillarD: part([2.4, 13, 2.4], [134, 6.5, 8], rgb(210, 190, 255)),
    Roof: part([22, 1.6, 22], [126, 13.6, 0], rgb(120, 84, 190)),
    SignBoard: sign([20, 6, 1.2], [126, 9, -12.5], rgb(88, 60, 140)),
  },
  // The sign tower over the spawn plaza: two pillars, a beam, and the
  // BRAINROT TYCOON block letters glowing between them.
  SignTower: {
    $className: 'Folder',
    PillarL: part([2.4, 27, 2.4], [-117, 13.5, 56], rgb(52, 52, 62)),
    PillarR: part([2.4, 27, 2.4], [-59, 13.5, 56], rgb(52, 52, 62)),
    Beam: part([60, 2.2, 2.2], [-88, 27.5, 56], rgb(245, 197, 66)),
    Base: part([64, 1, 7], [-88, 0.2, 56], rgb(120, 120, 130)),
  },
  // The leaderboard board beside the plaza (Signs fills it live).
  LeaderboardSign: sign([20, 11, 1.2], [-64, 7.5, 46], rgb(60, 50, 30)),
  LeaderboardPostL: part([1.6, 13, 1.6], [-73, 6.5, 46], rgb(110, 78, 46)),
  LeaderboardPostR: part([1.6, 13, 1.6], [-55, 6.5, 46], rgb(110, 78, 46)),
  TsunamiSign: sign([24, 7, 1.4], [40, 7, -14], rgb(30, 90, 160)),
  TsunamiPostL: part([1.6, 10, 1.6], [29, 5, -14], rgb(70, 70, 80)),
  TsunamiPostR: part([1.6, 10, 1.6], [51, 5, -14], rgb(70, 70, 80)),
};

// The tower letters: BRAINROT on top, TYCOON beneath.
Object.assign(workspace.SignTower, letterRow('BRAINROT', -88, 25.5, 56, 1.5, rgb(255, 242, 194)));
Object.assign(workspace.SignTower, letterRow('TYCOON', -88, 15.5, 56, 1.5, rgb(255, 205, 55)));

// The egg pedestals and their glowing eggs, one per egg tier.
const EGG_COLORS = [
  rgb(178, 190, 181), rgb(84, 150, 255), rgb(178, 102, 255),
  rgb(255, 196, 46), rgb(255, 84, 150), rgb(255, 242, 194),
];
EGG_COLORS.forEach((color, i) => {
  const x = -139 + i * 6;
  workspace.EggStation[`Pedestal${i + 1}`] = part([4, 2, 4], [x, 1, 26], rgb(130, 125, 118));
  workspace.EggStation[`Egg${i + 1}`] = part([3.2, 4, 3.2], [x, 4.2, 26], color, {
    Shape: 'Ball',
    ...(i >= 2 ? { Material: 'Neon' } : {}),
  });
});

// Belt stripes so the conveyor reads as moving machinery.
for (let i = 0; i < 14; i += 1) {
  workspace.Lane[`Stripe${i + 1}`] = part([3, 1.1, 12], [-97 + i * 15, 0.55, 0], rgb(70, 70, 84));
}

// The six player bases.
workspace.Bases = { $className: 'Folder' };
BASE_NAMES.forEach((name, i) => {
  workspace.Bases[name] = basePlot(i);
});

// The spawn plaza: checkered tiles, benches and planters around the
// spawn pad, framed by a crisp white border — the green-and-white
// palette the simulator lobbies use.
workspace.Plaza = { $className: 'Folder' };
workspace.Plaza.FrameN = part([44, 0.3, 1.2], [-88, 0.1, 9.6], rgb(250, 250, 250), { CanCollide: false });
workspace.Plaza.FrameS = part([44, 0.3, 1.2], [-88, 0.1, 50.4], rgb(250, 250, 250), { CanCollide: false });
workspace.Plaza.FrameW = part([1.2, 0.3, 42], [-110.1, 0.1, 30], rgb(250, 250, 250), { CanCollide: false });
workspace.Plaza.FrameE = part([1.2, 0.3, 42], [-65.9, 0.1, 30], rgb(250, 250, 250), { CanCollide: false });
for (let ix = 0; ix < 8; ix += 1) {
  for (let iz = 0; iz < 8; iz += 1) {
    const light = (ix + iz) % 2 === 0;
    workspace.Plaza[`Tile${ix}_${iz}`] = part(
      [5, 0.12, 5],
      [-105.5 + ix * 5, 0.06, 12.5 + iz * 5],
      light ? rgb(242, 240, 234) : rgb(138, 150, 178),
      { CanCollide: false },
    );
  }
}
[[-100, 18], [-76, 18], [-100, 42], [-76, 42]].forEach(([x, z], i) => {
  workspace.Plaza[`Bench${i + 1}`] = {
    $className: 'Folder',
    Seat: part([6, 0.6, 2], [x, 1.1, z], rgb(150, 108, 66)),
    Back: part([6, 2, 0.5], [x, 2.2, z + (z < 30 ? -1.1 : 1.1)], rgb(150, 108, 66)),
    LegL: part([0.6, 0.9, 1.6], [x - 2.4, 0.45, z], rgb(110, 78, 46)),
    LegR: part([0.6, 0.9, 1.6], [x + 2.4, 0.45, z], rgb(110, 78, 46)),
  };
});
[[-106, 14], [-70, 14], [-106, 46], [-70, 46]].forEach(([x, z], i) => {
  workspace.Plaza[`Planter${i + 1}`] = {
    $className: 'Folder',
    Box: part([4, 1.6, 4], [x, 0.8, z], rgb(130, 90, 55)),
    Bush: part([3.6, 3.6, 3.6], [x, 3, z], rgb(52, 150, 66), { Shape: 'Ball' }),
  };
});

// Scenery: trees ring the map, lamps line the lane and plaza, fences
// edge the lane, bushes and rocks break up the grass, clouds drift.
workspace.Decor = { $className: 'Folder' };
const treeSpots = [
  [-150, -90], [-60, -105], [30, -100], [120, -95], [165, -40], [160, 60],
  [110, 105], [20, 108], [-70, 102], [-150, 80], [-165, -20], [-40, -108],
  [80, -108], [-120, -100], [150, -105], [-170, 40], [170, -80], [60, 110],
  [-110, 108], [140, 30], [-160, -60], [100, -60],
];
// A full tree line right around the map's edge — the simulator-lobby
// look: the playable square reads as a platform floating in green.
for (let e = -196; e <= 196; e += 28) {
  treeSpots.push([e, -196], [e + 14, 196]);
  if (Math.abs(e) < 180) {
    treeSpots.push([-196, e + 14], [196, e]);
  }
}
treeSpots.forEach(([x, z], i) => {
  const leaf = i % 5 === 4 ? rgb(232, 150, 60) : i % 2 === 0 ? rgb(52, 150, 66) : rgb(66, 170, 80);
  workspace.Decor[`Tree${i + 1}`] = {
    $className: 'Folder',
    ...tree(x, z, rgb(110, 78, 46), leaf),
  };
});
[[-60, -12], [0, -12], [60, -12], [-60, 12], [0, 12], [60, 12],
 [-100, -12], [100, -12], [-100, 12], [100, 12], [-88, 16], [-64, 20],
].forEach(([x, z], i) => {
  workspace.Decor[`Lamp${i + 1}`] = { $className: 'Folder', ...lamp(x, z) };
});
// Fences along both grass edges of the lane, with gaps to walk through.
for (const side of [-1, 1]) {
  for (let s = 0; s < 10; s += 1) {
    const x = -144 + s * 32;
    const z = side * 13.5;
    workspace.Decor[`Fence${side < 0 ? 'N' : 'S'}${s + 1}`] = {
      $className: 'Folder',
      Rail: part([30, 1, 0.7], [x, 1.7, z], rgb(150, 108, 66)),
      PostL: part([0.8, 2.4, 0.8], [x - 14, 1.2, z], rgb(110, 78, 46)),
      PostR: part([0.8, 2.4, 0.8], [x + 14, 1.2, z], rgb(110, 78, 46)),
    };
  }
}
const bushSpots = [
  [-140, 20], [-40, -19], [30, 19], [90, -19], [140, 20], [-30, -20],
  [120, -20], [-120, 19], [55, 20], [-55, -19], [155, -18], [-155, 18],
  [10, -19], [-95, -19],
];
bushSpots.forEach(([x, z], i) => {
  const s = 3 + (i % 3) * 0.7;
  workspace.Decor[`Bush${i + 1}`] = part([s, s, s], [x, s / 2, z], rgb(44, 128, 58), { Shape: 'Ball' });
});
const rockSpots = [
  [-135, -24], [45, 24], [105, 22], [-45, -24], [150, -24], [-105, 24],
  [75, -24], [15, 24],
];
rockSpots.forEach(([x, z], i) => {
  const s = 2.4 + (i % 3);
  workspace.Decor[`Rock${i + 1}`] = part([s, s * 0.55, s * 0.8], [x, s * 0.24, z], rgb(128, 128, 134), { Shape: 'Ball' });
});
[[-80, 60], [0, 75], [90, 55], [40, 90], [-140, 40]].forEach(([x, z], i) => {
  workspace.Decor[`Cloud${i + 1}`] = part([26, 5, 14], [x, 64 + (i % 3) * 5, z], rgb(255, 255, 255), {
    CanCollide: false,
    Shape: 'Ball',
    Transparency: 0.25,
  });
});

const project = {
  name: 'brainrot-tycoon',
  tree: {
    $className: 'DataModel',
    Players: {
      $properties: { CharacterAutoLoads: true },
    },
    ReplicatedStorage: {
      Shared: { $path: 'src/shared' },
    },
    ServerScriptService: {
      Server: { $path: 'src/server' },
    },
    StarterPlayer: {
      StarterPlayerScripts: {
        Client: { $path: 'src/client' },
      },
    },
    Workspace: workspace,
    Lighting: {
      $properties: {
        Ambient: rgb(152, 178, 208),
        Brightness: 2.9,
        GlobalShadows: true,
        Outlines: false,
        Technology: 'Voxel',
      },
    },
    SoundService: {
      $properties: { RespectFilteringEnabled: true },
    },
  },
};

const outPath = join(dirname(fileURLToPath(import.meta.url)), '..', 'default.project.json');
writeFileSync(outPath, `${JSON.stringify(project, null, 2)}\n`);
console.log(`wrote ${outPath}`);
