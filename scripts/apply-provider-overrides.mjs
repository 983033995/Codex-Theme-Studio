#!/usr/bin/env node

import { constants } from "node:fs";
import { access, readFile, rename, stat, unlink, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const root = resolve(scriptDirectory, "..");
const cssOverridePath = join(root, "provider-overrides", "fortune-coder-sidebar-hover.css");
const jsOverridePath = join(root, "provider-overrides", "fortune-coder-safe-layer.js");
const heroCutoutPath = join(root, "provider-overrides", "assets", "fortune-hero-cutout.png");
const heroParchmentPath = join(root, "provider-overrides", "assets", "fortune-hero-parchment.png");
const projectBagCollapsedPath = join(
  root,
  "provider-overrides",
  "assets",
  "fortune-project-bag-collapsed.png"
);
const projectBagExpandedPath = join(
  root,
  "provider-overrides",
  "assets",
  "fortune-project-bag-expanded.png"
);
const cssMarkers = {
  begin: "/* CODEX THEME STUDIO: fortune-coder-sidebar-hover BEGIN */",
  end: "/* CODEX THEME STUDIO: fortune-coder-sidebar-hover END */"
};
const jsMarkers = {
  begin: "/* CODEX THEME STUDIO: fortune-coder-safe-layer BEGIN */",
  end: "/* CODEX THEME STUDIO: fortune-coder-safe-layer END */"
};

function argumentValue(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

async function exists(path) {
  try {
    await access(path, constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

async function imageDataURL(path) {
  const image = await readFile(path);
  return `data:image/png;base64,${image.toString("base64")}`;
}

async function assetReplacements() {
  return new Map([
    ["__FORTUNE_HERO_CUTOUT_DATA_URL__", await imageDataURL(heroCutoutPath)],
    ["__FORTUNE_HERO_PARCHMENT_DATA_URL__", await imageDataURL(heroParchmentPath)],
    ["__FORTUNE_PROJECT_BAG_COLLAPSED_DATA_URL__", await imageDataURL(projectBagCollapsedPath)],
    ["__FORTUNE_PROJECT_BAG_EXPANDED_DATA_URL__", await imageDataURL(projectBagExpandedPath)]
  ]);
}

function replaceAssets(source, replacements) {
  let output = source;
  for (const [placeholder, value] of replacements) {
    if (!output.includes(placeholder)) {
      throw new Error(`Override is missing required asset placeholder: ${placeholder}`);
    }
    output = output.replaceAll(placeholder, value);
  }
  return output;
}

async function loadOverride(replacements) {
  const source = (await readFile(cssOverridePath, "utf8")).trim();
  const requiredSelectors = [
    "[data-app-action-sidebar-thread-row]",
    "[data-app-action-sidebar-thread-active=\"true\"]",
    "[data-app-action-sidebar-project-row]",
    "--dream-fortune-safe-right",
    "data-dream-fortune-content-open",
    "dream-fortune-home-dashboard",
    "data-dream-fortune-project-bag",
    "dream-fortune-project-bag-icon",
    "[role=\"listitem\"]"
  ];
  for (const selector of requiredSelectors) {
    if (!source.includes(selector)) {
      throw new Error(`Override is missing required selector: ${selector}`);
    }
  }
  return replaceAssets(source, new Map([
    ["__FORTUNE_HERO_PARCHMENT_DATA_URL__", replacements.get("__FORTUNE_HERO_PARCHMENT_DATA_URL__")]
  ]));
}

async function loadJavaScriptOverride(replacements) {
  const source = (await readFile(jsOverridePath, "utf8")).trim();
  const requiredFragments = [
    "file-tree-container, diffs-container",
    "--thread-floating-content-top-inset",
    "--dream-fortune-safe-right",
    "dreamFortuneContentOpen",
    "dream-fortune-home-dashboard",
    "syncProjectBagIcons",
    "hydrateDashboardIcons",
    "aria-pressed",
    "rect.right >= shellRect.right - 12",
    "ResizeObserver",
    "MutationObserver"
  ];
  for (const fragment of requiredFragments) {
    if (!source.includes(fragment)) {
      throw new Error(`JavaScript override is missing required fragment: ${fragment}`);
    }
  }
  return replaceAssets(source, new Map([
    ["__FORTUNE_HERO_CUTOUT_DATA_URL__", replacements.get("__FORTUNE_HERO_CUTOUT_DATA_URL__")],
    [
      "__FORTUNE_PROJECT_BAG_COLLAPSED_DATA_URL__",
      replacements.get("__FORTUNE_PROJECT_BAG_COLLAPSED_DATA_URL__")
    ],
    [
      "__FORTUNE_PROJECT_BAG_EXPANDED_DATA_URL__",
      replacements.get("__FORTUNE_PROJECT_BAG_EXPANDED_DATA_URL__")
    ]
  ]));
}

async function applyToFile(target, override, markers) {
  const source = await readFile(target, "utf8");
  const blockPattern = new RegExp(
    `\\n*${escapeRegExp(markers.begin)}[\\s\\S]*?${escapeRegExp(markers.end)}\\n*`,
    "g"
  );
  const base = source.replace(blockPattern, "\n").trimEnd();
  const output = `${base}\n\n${markers.begin}\n${override}\n${markers.end}\n`;
  const metadata = await stat(target);
  const temporary = `${target}.theme-studio-${process.pid}.tmp`;
  try {
    await writeFile(temporary, output, { encoding: "utf8", mode: metadata.mode });
    await rename(temporary, target);
  } catch (error) {
    await unlink(temporary).catch(() => {});
    throw error;
  }
  process.stdout.write(`Updated ${target}\n`);
}

const replacements = await assetReplacements();
const cssOverride = await loadOverride(replacements);
const jsOverride = await loadJavaScriptOverride(replacements);
if (process.argv.includes("--self-test")) {
  process.stdout.write("PASS: provider CSS and JavaScript override sources are valid\n");
  process.exit(0);
}

const providerRoot = resolve(
  argumentValue("--provider-root")
    || process.env.CODEX_THEME_STUDIO_ENGINE
    || process.env.CODEX_DREAM_SKIN_ENGINE
    || join(homedir(), ".codex", "codex-dream-skin-studio")
);
const cssTargets = [
  join(providerRoot, "assets", "dream-skin.css"),
  join(
    providerRoot,
    "dist",
    "Codex Dream Skin.app",
    "Contents",
    "Resources",
    "engine",
    "assets",
    "dream-skin.css"
  )
];
const jsTargets = [
  join(providerRoot, "assets", "renderer-inject.js"),
  join(
    providerRoot,
    "dist",
    "Codex Dream Skin.app",
    "Contents",
    "Resources",
    "engine",
    "assets",
    "renderer-inject.js"
  )
];

let cssApplied = 0;
for (const target of cssTargets) {
  if (!(await exists(target))) continue;
  await applyToFile(target, cssOverride, cssMarkers);
  cssApplied += 1;
}

let jsApplied = 0;
for (const target of jsTargets) {
  if (!(await exists(target))) continue;
  await applyToFile(target, jsOverride, jsMarkers);
  jsApplied += 1;
}

if (cssApplied === 0 || jsApplied === 0) {
  throw new Error(`No complete compatible provider payload found under ${providerRoot}`);
}
