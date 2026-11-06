// release.test.mjs: tests for tools/release.mjs (node --test tests/release.test.mjs, part of npm test).
//
// Builds the release zip of SquareMinimapButtons into a temporary directory and reads it back with a
// small zip reader of its own (end of central directory, central directory headers, local file
// headers, inflate, CRC-32 and sizes), independent of the writer in tools/release.mjs. The CRC-32
// here comes from zlib.crc32, the version from an own read of the TOC.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import zlib from 'node:zlib';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import { release, main } from '../tools/release.mjs';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ADDON = 'SquareMinimapButtons';
const addonDir = path.join(repoRoot, ADDON);

function tempDir(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'smb-release-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return dir;
}

function tocVersion(dir) {
  const text = fs.readFileSync(path.join(dir, `${path.basename(dir)}.toc`), 'utf8');
  const match = /^## Version: (\S+)\s*$/m.exec(text);
  assert.ok(match, 'the TOC has a version');
  return match[1];
}

// Files of a folder as on disk: relative paths with "/" -> absolute paths.
function diskFiles(dir, prefix = '', out = new Map()) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const abs = path.join(dir, entry.name);
    if (entry.isDirectory()) diskFiles(abs, `${prefix}${entry.name}/`, out);
    else out.set(`${prefix}${entry.name}`, abs);
  }
  return out;
}

// ---------------------------------------------------------------------------------------------
// Zip reader
// ---------------------------------------------------------------------------------------------

function readZip(buffer) {
  let eocd = -1;
  for (let i = buffer.length - 22; i >= Math.max(0, buffer.length - 22 - 0xffff); i--) {
    if (buffer.readUInt32LE(i) === 0x06054b50) {
      eocd = i;
      break;
    }
  }
  assert.ok(eocd >= 0, 'end of central directory record found');
  const count = buffer.readUInt16LE(eocd + 10);
  assert.equal(buffer.readUInt16LE(eocd + 8), count, 'entries on this disk = total entries');
  const cdSize = buffer.readUInt32LE(eocd + 12);
  const cdOffset = buffer.readUInt32LE(eocd + 16);
  assert.equal(cdOffset + cdSize, eocd, 'central directory ends at the end record');

  const entries = [];
  let p = cdOffset;
  for (let n = 0; n < count; n++) {
    assert.equal(buffer.readUInt32LE(p), 0x02014b50, `central directory header ${n}`);
    const flags = buffer.readUInt16LE(p + 8);
    const method = buffer.readUInt16LE(p + 10);
    const time = buffer.readUInt16LE(p + 12);
    const date = buffer.readUInt16LE(p + 14);
    const crc = buffer.readUInt32LE(p + 16);
    const compressedSize = buffer.readUInt32LE(p + 20);
    const size = buffer.readUInt32LE(p + 24);
    const nameLength = buffer.readUInt16LE(p + 28);
    const extraLength = buffer.readUInt16LE(p + 30);
    const commentLength = buffer.readUInt16LE(p + 32);
    const localOffset = buffer.readUInt32LE(p + 42);
    const name = buffer.subarray(p + 46, p + 46 + nameLength).toString('utf8');
    p += 46 + nameLength + extraLength + commentLength;

    // local file header must agree with the central directory
    const l = localOffset;
    assert.equal(buffer.readUInt32LE(l), 0x04034b50, `local header of ${name}`);
    assert.equal(buffer.readUInt16LE(l + 6), flags, `flags of ${name}`);
    assert.equal(buffer.readUInt16LE(l + 8), method, `method of ${name}`);
    assert.equal(buffer.readUInt16LE(l + 10), time, `time of ${name}`);
    assert.equal(buffer.readUInt16LE(l + 12), date, `date of ${name}`);
    assert.equal(buffer.readUInt32LE(l + 14), crc, `local CRC of ${name}`);
    assert.equal(buffer.readUInt32LE(l + 18), compressedSize, `local compressed size of ${name}`);
    assert.equal(buffer.readUInt32LE(l + 22), size, `local size of ${name}`);
    const localNameLength = buffer.readUInt16LE(l + 26);
    const localExtraLength = buffer.readUInt16LE(l + 28);
    assert.equal(buffer.subarray(l + 30, l + 30 + localNameLength).toString('utf8'), name, `local name of ${name}`);
    const start = l + 30 + localNameLength + localExtraLength;
    const raw = buffer.subarray(start, start + compressedSize);

    let data;
    if (method === 8) data = zlib.inflateRawSync(raw);
    else if (method === 0) data = Buffer.from(raw);
    else assert.fail(`unknown method ${method} for ${name}`);
    assert.equal(data.length, size, `size of ${name}`);
    assert.equal(zlib.crc32(data) >>> 0, crc, `CRC-32 of ${name}`);

    entries.push({ name, flags, method, time, date, crc, size, data });
  }
  return entries;
}

// ---------------------------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------------------------

test('release zip of SquareMinimapButtons: one root folder, every addon file, nothing else', (t) => {
  const out = tempDir(t);
  const version = tocVersion(addonDir);
  const result = release(addonDir, out);

  assert.equal(path.basename(result.zipPath), `${ADDON}-${version}.zip`, 'file name carries the TOC version');
  assert.equal(result.version, version);
  const buffer = fs.readFileSync(result.zipPath);
  assert.equal(result.size, buffer.length);

  const entries = readZip(buffer);
  assert.equal(result.entries, entries.length);

  for (const entry of entries) {
    assert.ok(entry.name.startsWith(`${ADDON}/`), `${entry.name} starts with ${ADDON}/`);
    assert.ok(!/(^|\/)(tests|tools|node_modules|\.git)(\/|$)/.test(entry.name), `${entry.name} is no development file`);
    assert.ok(!/\.zip$/i.test(entry.name), `${entry.name} is no zip`);
    assert.ok(!/(^|\/)\./.test(entry.name), `${entry.name} is no dot file`);
    assert.ok(entry.flags & 0x0800, `${entry.name} has the UTF-8 flag`);
    assert.ok(entry.date >> 9 >= 0 && ((entry.date >> 5) & 0x0f) >= 1, `${entry.name} has a DOS date`);
  }
  const roots = new Set(entries.map((e) => e.name.split('/')[0]));
  assert.deepEqual([...roots], [ADDON], 'exactly one root folder');

  const files = new Map(entries.filter((e) => !e.name.endsWith('/')).map((e) => [e.name.slice(ADDON.length + 1), e]));
  for (const required of [
    `${ADDON}.toc`, 'Core.lua', 'SquareMinimapButtons.lua', 'Options.lua', 'LICENSE.txt', 'README.md',
    'CHANGELOG.md', 'Locales/enUS.lua', 'Locales/deDE.lua', 'Libs/embeds.xml', 'Libs/Ace3/LICENSE.txt',
    'Libs/Ace3/LibStub/LibStub.lua',
  ]) {
    assert.ok(files.has(required), `${required} is in the zip`);
  }

  const disk = diskFiles(addonDir);
  assert.deepEqual([...files.keys()].sort(), [...disk.keys()].sort(), 'same files as on disk');
  const ace = [...disk.keys()].filter((f) => f.startsWith('Libs/Ace3/'));
  assert.ok(ace.length > 20, 'Ace3 has its files on disk');
  assert.equal([...files.keys()].filter((f) => f.startsWith('Libs/Ace3/')).length, ace.length, 'every Ace3 file');

  for (const [rel, abs] of disk) {
    const content = fs.readFileSync(abs);
    assert.equal(files.get(rel).size, content.length, `size of ${rel}`);
    assert.ok(files.get(rel).data.equals(content), `content of ${rel}`);
  }
});

test('unzip -tq accepts the zip and lists one root folder', (t) => {
  const probe = spawnSync('unzip', ['-v'], { encoding: 'utf8' });
  if (probe.error) {
    t.skip('unzip is not in the PATH');
    return;
  }
  const out = tempDir(t);
  const { zipPath } = release(addonDir, out);
  const check = spawnSync('unzip', ['-tq', zipPath], { encoding: 'utf8' });
  assert.equal(check.status, 0, `unzip -tq: ${check.stdout}${check.stderr}`);
  const list = spawnSync('unzip', ['-Z1', zipPath], { encoding: 'utf8' });
  assert.equal(list.status, 0, list.stderr);
  const roots = new Set(list.stdout.split('\n').filter(Boolean).map((line) => line.split('/')[0]));
  assert.deepEqual([...roots], [ADDON]);
});

test('development files, dot files and zips in the addon folder are left out', (t) => {
  const work = tempDir(t);
  const copy = path.join(work, ADDON);
  fs.cpSync(addonDir, copy, { recursive: true });
  const planted = {
    'tests/x': 'test file',
    'tools/build.mjs': 'tool',
    'node_modules/lib/index.js': 'module',
    'Libs/tests/x.lua': 'nested test',
    '.git/config': 'git',
    '.hidden': 'dot file',
    'Locales/.DS_Store': 'dot file',
    'old-1.0.0.zip': 'zip',
  };
  for (const [rel, text] of Object.entries(planted)) {
    fs.mkdirSync(path.dirname(path.join(copy, rel)), { recursive: true });
    fs.writeFileSync(path.join(copy, rel), text);
  }

  const out = path.join(work, 'out');
  const { zipPath } = release(copy, out);
  const names = readZip(fs.readFileSync(zipPath)).map((e) => e.name);
  for (const rel of Object.keys(planted)) {
    assert.ok(!names.includes(`${ADDON}/${rel}`), `${rel} is left out`);
  }
  for (const folder of ['tests/', 'tools/', 'node_modules/', 'Libs/tests/', '.git/']) {
    assert.ok(!names.includes(`${ADDON}/${folder}`), `folder ${folder} is left out`);
  }
  const fileCount = names.filter((n) => !n.endsWith('/')).length;
  assert.equal(fileCount, diskFiles(addonDir).size, 'only the files of the real addon folder');
});

test('a TOC without a version is an error', (t) => {
  const work = tempDir(t);
  const dir = path.join(work, 'NoVersion');
  fs.mkdirSync(dir);
  fs.writeFileSync(path.join(dir, 'NoVersion.toc'), '## Interface: 16001\n## Title: No Version\n\nNoVersion.lua\n');
  fs.writeFileSync(path.join(dir, 'NoVersion.lua'), '-- empty\n');
  assert.throws(() => release(dir, path.join(work, 'out')), /Version/);

  const errors = [];
  const code = main([dir, '--out', path.join(work, 'out')], () => {}, (line) => errors.push(line));
  assert.equal(code, 1);
  assert.match(errors.join('\n'), /no "## Version:" line/);
  assert.ok(!fs.existsSync(path.join(work, 'out')), 'no zip written');
});

test('the command line writes the zip into --out', (t) => {
  const out = tempDir(t);
  const lines = [];
  const code = main([addonDir, '--out', out], (line) => lines.push(line), (line) => lines.push(line));
  assert.equal(code, 0, lines.join('\n'));
  const zip = path.join(out, `${ADDON}-${tocVersion(addonDir)}.zip`);
  assert.ok(fs.existsSync(zip));
  assert.match(lines.join('\n'), /\d+ entries, \d+ bytes/);
});
