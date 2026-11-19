// generate-project.mjs — emits default.project.json for BRAINROT TYCOON.
//
// The world is laid out by code so the six base plots, the conveyor lane, the
// shop row and the decorations stay regular: loops place them, this file is
// the source of truth, and `node tools/generate-project.mjs` rewrites
// default.project.json next to the repo root. Rojo then builds game.rbxl
// from that JSON plus the Luau sources under src/.
//
// Layout (studs, X east / Z south):
//   - the conveyor lane runs along Z = 0 from X -105 (shop end) to X +105.
//   - six base plots, three north (Z -56) and three south (Z +56).
//   - the rebirth shrine sits at the east end, the shop at the west end.
//   - players spawn on the grass west of the lane, facing the shop.

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const rgb = (r, g, b) => [r / 255, g / 255, b / 255];

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

// A sign board: a plain part here; the server Signs module finds every part
// named SignBoard (and the two root signs) at runtime and hangs a SurfaceGui
// text label on it, because Rojo's project JSON cannot express UDim2 sizes.
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
  const node = {
    $className: 'Folder',
    Floor: part([42, 1, 42], [cx, 0, cz], color),
    // Low walls on the four edges so a plot reads as its own yard.
    WallN: part([42, 2.4, 1.4], [cx, 1.2, cz - 21], color),
    WallS: part([42, 2.4, 1.4], [cx, 1.2, cz + 21], color),
    WallW: part([1.4, 2.4, 42], [cx - 21, 1.2, cz], color),
    WallE: part([1.4, 2.4, 42], [cx + 21, 1.2, cz], color),
    // The pad the owner respawns on, by the plot's entrance.
    HomePad: part([7, 0.7, 7], [cx, 0.85, cz + (cz < 0 ? 15 : -15)], rgb(245, 245, 245)),
    // Step here to lock the base against thieves for a minute.
    LockPad: part([5, 0.7, 5], [cx + 14, 0.85, cz + (cz < 0 ? 15 : -15)], rgb(30, 30, 36)),
    SignPost: part([2, 9, 2], [cx - 17, 4.5, cz + (cz < 0 ? 19 : -19)], rgb(60, 48, 36)),
    SignBoard: sign([16, 6, 1], [cx - 17, 11, cz + (cz < 0 ? 19 : -19)], color),
  };
  // Six display pads, two rows of three, where bought brainrots stand.
  const padOffsets = [[-12, -9], [0, -9], [12, -9], [-12, 5], [0, 5], [12, 5]];
  padOffsets.forEach(([dx, dz], i) => {
    node[`Pad${i + 1}`] = part([7.5, 0.7, 7.5], [cx + dx, 0.85, cz + dz], rgb(238, 232, 218));
  });
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

const workspace = {
  $properties: { FilteringEnabled: true },
  Ground: part([460, 2, 460], [0, -1.2, 0], rgb(96, 190, 92)),
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
    RailNorth: part([216, 1.6, 1.2], [0, 1.3, -6.8], rgb(245, 197, 66)),
    RailSouth: part([216, 1.6, 1.2], [0, 1.3, 6.8], rgb(245, 197, 66)),
    StartMarker: part([2, 1, 12], [-104, 0.6, 0], rgb(88, 204, 110), { Transparency: 0.4 }),
    EndMarker: part([2, 1, 12], [104, 0.6, 0], rgb(232, 76, 76), { Transparency: 0.4 }),
  },
  Shop: {
    $className: 'Folder',
    Platform: part([34, 1, 30], [-124, 0, 0], rgb(196, 164, 120)),
    StallA: { $className: 'Folder', ...stall(-124, -9, rgb(232, 76, 76)) },
    StallB: { $className: 'Folder', ...stall(-124, 3, rgb(76, 132, 232)) },
    SignBoard: sign([26, 7, 1.4], [-124, 13, -14], rgb(120, 72, 20)),
    SignPostL: part([1.6, 10, 1.6], [-136, 5, -14], rgb(110, 78, 46)),
    SignPostR: part([1.6, 10, 1.6], [-112, 5, -14], rgb(110, 78, 46)),
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
  WelcomeSign: sign([30, 9, 1.6], [-88, 8, 44], rgb(36, 120, 60)),
  WelcomePostL: part([1.8, 12, 1.8], [-102, 6, 44], rgb(110, 78, 46)),
  WelcomePostR: part([1.8, 12, 1.8], [-74, 6, 44], rgb(110, 78, 46)),
  TsunamiSign: sign([24, 7, 1.4], [40, 7, -14], rgb(30, 90, 160)),
  TsunamiPostL: part([1.6, 10, 1.6], [29, 5, -14], rgb(70, 70, 80)),
  TsunamiPostR: part([1.6, 10, 1.6], [51, 5, -14], rgb(70, 70, 80)),
};

// Belt stripes so the conveyor reads as moving machinery.
for (let i = 0; i < 14; i += 1) {
  workspace.Lane[`Stripe${i + 1}`] = part([3, 1.1, 12], [-97 + i * 15, 0.55, 0], rgb(70, 70, 84));
}

// The six player bases.
workspace.Bases = { $className: 'Folder' };
BASE_NAMES.forEach((name, i) => {
  workspace.Bases[name] = basePlot(i);
});

// Scenery: trees ring the map, lamps line the lane, clouds drift as flat balls.
workspace.Decor = { $className: 'Folder' };
const treeSpots = [
  [-150, -90], [-60, -105], [30, -100], [120, -95], [165, -40], [160, 60],
  [110, 105], [20, 108], [-70, 102], [-150, 80], [-165, -20], [-40, -108],
  [80, -108], [-120, -100],
];
treeSpots.forEach(([x, z], i) => {
  workspace.Decor[`Tree${i + 1}`] = {
    $className: 'Folder',
    ...tree(x, z, rgb(110, 78, 46), rgb(52, 150, 66)),
  };
});
[[-60, -12], [0, -12], [60, -12], [-60, 12], [0, 12], [60, 12]].forEach(([x, z], i) => {
  workspace.Decor[`Lamp${i + 1}`] = { $className: 'Folder', ...lamp(x, z) };
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
        Ambient: rgb(120, 120, 130),
        Brightness: 2.4,
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
