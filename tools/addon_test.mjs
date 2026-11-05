#!/usr/bin/env node
// addon_test.mjs: test runner for the Lua tests of an addon folder in this repository.
//
// Usage
//   node tools/addon_test.mjs <AddonFolder>       e.g. node tools/addon_test.mjs SquareMinimapButtons
//   npm test
//
// Needs the devDependencies from package.json (npm install): fengari (Lua 5.3 in JavaScript) and
// luaparse (Lua parser).
//
// Steps
//   1. Reads <AddonFolder>/<AddonFolder>.toc (metadata "## Key: Value" and the file list) and resolves
//      every XML file in it the way the client does: <Script file="..."/> loads a Lua file,
//      <Include file="..."/> loads another XML file; paths are relative to the XML file and use
//      backslashes. XML comments are ignored. The result is the list of Lua files in load order.
//   2. Syntax check with luaparse (luaVersion '5.1', like the WoW client) of every Lua file in the
//      addon folder (load list plus any other .lua file found there) and of every tests/<Addon>/*.lua.
//   3. Every tests/<Addon>/test_*.lua runs in its own fengari state: tests/<Addon>/stubs.lua (WoW API
//      stubs), tests/<Addon>/_harness.lua (describe/it/assert_*), then __before_addon_load() if the
//      stubs define it, then the library and addon files in TOC order, each called like the client
//      does with the varargs (addonName, addonTable), and last the test file.
//      Globals for the stubs and tests: ADDON_NAME, ADDON_TOC (metadata table), ADDON_FILES (list of
//      load-order paths relative to the repository root) and LoadAddon(), which loads all files of
//      the load list again with a fresh addon table (the stubs use it to reload the addon with
//      another simulated client) and returns that table.
//   4. Counts passed/failed through __summary(); exit code 1 on any failure or syntax error.
//
// Note: fengari is Lua 5.3, the client uses Lua 5.1. The stubs set unpack = table.unpack and
// loadstring = load. Addon code must not use features of 5.2 or later (goto, //, bit operators,
// utf8); the luaparse check with luaVersion '5.1' rejects them.

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function loadDependencies() {
  try {
    return { fengari: require('fengari'), luaparse: require('luaparse') };
  } catch (e) {
    console.error('fengari or luaparse is missing: run "npm install" in the repository root.');
    console.error(e.message);
    process.exit(2);
  }
}

const rel = (p) => path.relative(repoRoot, p).split(path.sep).join('/');

// Client paths use backslashes; resolve them against a directory.
function clientPath(baseDir, file) {
  return path.join(baseDir, ...file.trim().split(/[\\/]+/));
}

export function readToc(addonDir) {
  const name = path.basename(addonDir);
  const tocPath = path.join(addonDir, `${name}.toc`);
  const text = fs.readFileSync(tocPath, 'utf8');
  const metadata = {};
  const files = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) continue;
    const meta = /^##\s*([^:]+?)\s*:\s*(.*)$/.exec(line);
    if (meta) {
      metadata[meta[1]] = meta[2];
      continue;
    }
    if (line.startsWith('#')) continue;
    files.push(line);
  }
  return { tocPath, metadata, files };
}

function resolveXml(xmlPath, out, errors, stack) {
  if (stack.includes(xmlPath)) {
    errors.push(`${rel(xmlPath)}: include cycle`);
    return;
  }
  if (!fs.existsSync(xmlPath)) {
    errors.push(`${rel(stack[stack.length - 1] || xmlPath)}: missing file ${rel(xmlPath)}`);
    return;
  }
  const text = fs.readFileSync(xmlPath, 'utf8').replace(/<!--[\s\S]*?-->/g, '');
  const dir = path.dirname(xmlPath);
  const re = /<\s*(Script|Include)\b([^>]*)>/g;
  let m;
  while ((m = re.exec(text)) !== null) {
    const fileAttr = /\bfile\s*=\s*"([^"]*)"/.exec(m[2]);
    if (!fileAttr) {
      if (m[1] === 'Include') errors.push(`${rel(xmlPath)}: <Include> without file`);
      continue; // inline <Script> blocks are not used by these addons
    }
    const target = clientPath(dir, fileAttr[1]);
    if (m[1] === 'Include') {
      resolveXml(target, out, errors, [...stack, xmlPath]);
    } else if (!fs.existsSync(target)) {
      errors.push(`${rel(xmlPath)}: missing file ${rel(target)}`);
    } else {
      out.push(target);
    }
  }
}

export function resolveLoadOrder(addonDir) {
  const toc = readToc(addonDir);
  const files = [];
  const errors = [];
  for (const entry of toc.files) {
    const target = clientPath(addonDir, entry);
    if (/\.xml$/i.test(entry)) {
      resolveXml(target, files, errors, []);
    } else if (/\.lua$/i.test(entry)) {
      if (fs.existsSync(target)) files.push(target);
      else errors.push(`${rel(toc.tocPath)}: missing file ${rel(target)}`);
    } else {
      errors.push(`${rel(toc.tocPath)}: unsupported file type ${entry}`);
    }
  }
  return { metadata: toc.metadata, files, errors };
}

function walkLua(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walkLua(p, out);
    else if (entry.name.endsWith('.lua')) out.push(p);
  }
  return out;
}

function syntaxCheck(luaparse, files) {
  const errors = [];
  for (const file of files) {
    try {
      luaparse.parse(fs.readFileSync(file, 'utf8'), { luaVersion: '5.1', comments: false });
    } catch (e) {
      errors.push(`${rel(file)}: ${e.message}`);
    }
  }
  return errors;
}

function pushValue(fengari, L, v) {
  const { lua, to_luastring } = fengari;
  if (v === null || v === undefined) lua.lua_pushnil(L);
  else if (typeof v === 'boolean') lua.lua_pushboolean(L, v);
  else if (typeof v === 'number') lua.lua_pushnumber(L, v);
  else if (typeof v === 'string') lua.lua_pushstring(L, to_luastring(v));
  else if (Array.isArray(v)) {
    lua.lua_createtable(L, v.length, 0);
    v.forEach((x, i) => {
      pushValue(fengari, L, x);
      lua.lua_rawseti(L, -2, i + 1);
    });
  } else {
    lua.lua_newtable(L);
    for (const [k, x] of Object.entries(v)) {
      lua.lua_pushstring(L, to_luastring(k));
      pushValue(fengari, L, x);
      lua.lua_rawset(L, -3);
    }
  }
}

function setGlobal(fengari, L, name, value) {
  pushValue(fengari, L, value);
  fengari.lua.lua_setglobal(L, fengari.to_luastring(name));
}

function runFile(fengari, L, file) {
  const { lua, lauxlib, to_luastring, to_jsstring } = fengari;
  if (lauxlib.luaL_loadbuffer(L, fs.readFileSync(file), null, to_luastring('@' + rel(file))) !== lua.LUA_OK) {
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  }
  if (lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) {
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  }
}

// LoadAddon(): loads every file of the load list with (addonName, addonTable), returns addonTable.
function makeLoadAddon(fengari, addonName, files, sources) {
  const { lua, lauxlib, to_luastring, to_jsstring } = fengari;
  return (L) => {
    lua.lua_newtable(L);
    const ns = lua.lua_gettop(L);
    for (const file of files) {
      if (lauxlib.luaL_loadbuffer(L, sources.get(file), null, to_luastring('@' + rel(file))) !== lua.LUA_OK) {
        const msg = to_jsstring(lua.lua_tostring(L, -1));
        lua.lua_settop(L, ns);
        return lauxlib.luaL_error(L, to_luastring(`LoadAddon: ${msg}`));
      }
      lua.lua_pushstring(L, to_luastring(addonName));
      lua.lua_pushvalue(L, ns);
      if (lua.lua_pcall(L, 2, 0, 0) !== lua.LUA_OK) {
        const msg = to_jsstring(lua.lua_tostring(L, -1));
        lua.lua_settop(L, ns);
        return lauxlib.luaL_error(L, to_luastring(`LoadAddon: ${msg}`));
      }
    }
    lua.lua_settop(L, ns);
    return 1;
  };
}

export function main(argv) {
  if (argv.length !== 1) {
    console.error('Usage: node tools/addon_test.mjs <AddonFolder>');
    return 2;
  }
  const { fengari, luaparse } = loadDependencies();
  const { lua, lauxlib, lualib, to_luastring } = fengari;

  const addonName = path.basename(path.resolve(repoRoot, argv[0]));
  const addonDir = path.join(repoRoot, addonName);
  const testDir = path.join(repoRoot, 'tests', addonName);
  if (!fs.existsSync(addonDir)) {
    console.error(`Addon folder not found: ${addonName}`);
    return 2;
  }

  // 1. TOC and XML
  const order = resolveLoadOrder(addonDir);
  console.log(`Load order (${addonName}.toc): ${order.files.length} Lua files, ${order.errors.length} errors`);
  for (const e of order.errors) console.log('  ERROR ' + e);

  // 2. Syntax
  const luaFiles = [...new Set([...order.files, ...walkLua(addonDir)])];
  const testFiles = fs.existsSync(testDir) ? walkLua(testDir).sort() : [];
  const syntaxErrors = syntaxCheck(luaparse, [...luaFiles, ...testFiles]);
  console.log(`Syntax check (luaparse, Lua 5.1): ${luaFiles.length + testFiles.length} files checked, ${syntaxErrors.length} errors`);
  for (const e of syntaxErrors) console.log('  ERROR ' + e);

  const notLoaded = luaFiles.filter((f) => !order.files.includes(f));
  for (const f of notLoaded) console.log(`  note: ${rel(f)} is not in the load order`);

  // 3. Tests
  const sources = new Map(order.files.map((f) => [f, fs.readFileSync(f)]));
  const tests = testFiles
    .filter((f) => path.dirname(f) === testDir && /^test_.*\.lua$/.test(path.basename(f)))
    .sort();
  let passed = 0;
  let failed = 0;
  if (tests.length === 0) {
    console.log('\nNo test files found.');
    failed += 1;
  }
  for (const t of tests) {
    console.log(`\n${path.basename(t)}`);
    const L = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(L);
    setGlobal(fengari, L, 'ADDON_NAME', addonName);
    setGlobal(fengari, L, 'ADDON_TOC', order.metadata);
    setGlobal(fengari, L, 'ADDON_FILES', order.files.map(rel));
    lua.lua_pushjsfunction(L, makeLoadAddon(fengari, addonName, order.files, sources));
    lua.lua_setglobal(L, to_luastring('LoadAddon'));
    try {
      runFile(fengari, L, path.join(testDir, 'stubs.lua'));
      runFile(fengari, L, path.join(testDir, '_harness.lua'));
      if (lua.lua_getglobal(L, to_luastring('__before_addon_load')) === lua.LUA_TFUNCTION) {
        if (lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) throw new Error(fengari.to_jsstring(lua.lua_tostring(L, -1)));
      } else {
        lua.lua_pop(L, 1);
      }
      // the library and addon files in TOC order, sharing one addon table like the client
      lua.lua_getglobal(L, to_luastring('LoadAddon'));
      if (lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) throw new Error(fengari.to_jsstring(lua.lua_tostring(L, -1)));
      runFile(fengari, L, t);
      lua.lua_getglobal(L, to_luastring('__summary'));
      if (lua.lua_pcall(L, 0, 2, 0) !== lua.LUA_OK) throw new Error('__summary failed');
      const p = lua.lua_tointeger(L, -2);
      const f = lua.lua_tointeger(L, -1);
      passed += p;
      failed += f;
      console.log(`  -> ${p} passed, ${f} failed`);
    } catch (e) {
      failed += 1;
      console.log(`  ERROR while loading: ${e.message}`);
    }
  }

  const errors = syntaxErrors.length + order.errors.length;
  console.log(`\nTotal: ${passed} passed, ${failed} failed, syntax and load order errors: ${errors}`);
  return failed === 0 && errors === 0 ? 0 : 1;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === fs.realpathSync(process.argv[1])) {
  try {
    process.exitCode = main(process.argv.slice(2));
  } catch (e) {
    console.error(`Error: ${e.message}`);
    process.exitCode = 1;
  }
}
