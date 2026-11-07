// release.test.mjs: tests for tools/release.mjs (node --test tests/release.test.mjs, part of npm test).
//
// Builds the release zip of SquareMinimapButtons into a temporary directory and reads it back with a
// small zip reader of its own (end of central directory, central directory headers, local file
// headers, inflate, CRC-32 and sizes), independent of the writer in tools/release.mjs. The CRC-32
// here comes from zlib.crc32, the version and the interface from an own read of the TOC. The
// release.json next to the zip is compared as text against the expected string, so that the key
// order and the types (interface a number, nolib a boolean) count as well.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import zlib from 'node:zlib';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import { release, main, dosDateTime } from '../tools/release.mjs';

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

// "## Interface-Forever:" of the TOC (the real TOC has it).
function tocInterfaceForever(dir) {
  const text = fs.readFileSync(path.join(dir, `${path.basename(dir)}.toc`), 'utf8');
  const match = /^## Interface-Forever: (\d+)\s*$/m.exec(text);
  assert.ok(match, 'the TOC has an Interface-Forever line');
  return match[1];
}

// The release.json expected for one zip, written out by hand as text.
function expectedReleaseJson(name, version, interfaceNumber) {
  return (
    `{"releases":[{"name":"${name}","version":"${version}","filename":"${name}-${version}-forever.zip",` +
    `"nolib":false,"metadata":[{"flavor":"forever","interface":${interfaceNumber}}]}]}\n`
  );
}

// A copy of the addon folder whose TOC header lines are replaced by `header` (the file list stays).
function addonWithHeader(t, header) {
  const work = tempDir(t);
  const copy = path.join(work, ADDON);
  fs.cpSync(addonDir, copy, { recursive: true });
  const tocPath = path.join(copy, `${ADDON}.toc`);
  const body = fs.readFileSync(tocPath, 'utf8').split('\n').filter((line) => !line.startsWith('## ')).join('\n');
  fs.writeFileSync(tocPath, `${header}${body}`);
  return { work, copy };
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

// Expected zip order: the root folder, then per folder its entries sorted by UTF-16 code unit,
// each subfolder (name ending in "/") directly before its contents.
function expectedOrder(dir, prefix) {
  const out = [];
  const names = fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
  for (const entry of names) {
    if (entry.isDirectory()) {
      out.push(`${prefix}${entry.name}/`);
      out.push(...expectedOrder(path.join(dir, entry.name), `${prefix}${entry.name}/`));
    } else {
      out.push(`${prefix}${entry.name}`);
    }
  }
  return out;
}

// DOS date and time (local time) -> Date
function fromDos(date, time) {
  return new Date(1980 + (date >> 9), ((date >> 5) & 0x0f) - 1, date & 0x1f, time >> 11, (time >> 5) & 0x3f, (time & 0x1f) * 2);
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

  assert.equal(path.basename(result.zipPath), `${ADDON}-${version}-forever.zip`, 'file name carries the TOC version and -forever');
  assert.equal(path.dirname(result.zipPath), out, 'zip in the output folder');
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
    const isFolder = entry.name.endsWith('/');
    assert.equal(entry.method, !isFolder && entry.size > 0 ? 8 : 0, `${entry.name}: deflate for files with content, stored otherwise`);
    const abs = path.join(repoRoot, entry.name);
    const mtime = fs.statSync(abs).mtime;
    const stamp = fromDos(entry.date, entry.time);
    assert.ok(Math.abs(stamp - mtime) < 2000, `${entry.name}: DOS date ${stamp.toISOString()} matches mtime ${mtime.toISOString()}`);
  }
  assert.deepEqual(entries.map((e) => e.name), [`${ADDON}/`, ...expectedOrder(addonDir, `${ADDON}/`)], 'entries in sorted order, folders before their contents');
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

test('release.json next to the zip: packager format, exact text and key order', (t) => {
  const out = tempDir(t);
  const version = tocVersion(addonDir);
  const interfaceNumber = tocInterfaceForever(addonDir);
  assert.equal(interfaceNumber, '16001', 'the real TOC targets WoW Forever 16001');
  const result = release(addonDir, out);

  assert.equal(result.releaseJsonPath, path.join(out, 'release.json'), 'release.json in the output folder');
  assert.ok(fs.existsSync(result.releaseJsonPath), 'release.json is written');
  const text = fs.readFileSync(result.releaseJsonPath, 'utf8');
  assert.equal(text, expectedReleaseJson(ADDON, version, interfaceNumber), 'exact text, compact, final line break');

  const parsed = JSON.parse(text);
  assert.deepEqual(Object.keys(parsed), ['releases']);
  assert.equal(parsed.releases.length, 1, 'one release');
  const [entry] = parsed.releases;
  assert.deepEqual(Object.keys(entry), ['name', 'version', 'filename', 'nolib', 'metadata'], 'key order');
  assert.equal(entry.name, ADDON, 'name is the folder name');
  assert.equal(entry.version, version, 'version is the TOC version');
  assert.equal(entry.filename, path.basename(result.zipPath), 'filename is the name of the zip');
  assert.equal(entry.nolib, false);
  assert.equal(entry.metadata.length, 1, 'one metadata entry');
  assert.deepEqual(Object.keys(entry.metadata[0]), ['flavor', 'interface']);
  assert.equal(entry.metadata[0].flavor, 'forever');
  assert.equal(typeof entry.metadata[0].interface, 'number', 'interface is a number');
  assert.equal(entry.metadata[0].interface, 16001);
  assert.deepEqual(result.releaseJson, parsed, 'release() returns the written object');
});

test('release.json takes the interface from "## Interface-Forever:" before "## Interface:"', (t) => {
  const both = addonWithHeader(t, '## Interface: 11507\n## Interface-Forever: 16002\n## Title: Both\n## Version: 2.3.4\n');
  const bothResult = release(both.copy, path.join(both.work, 'out'));
  assert.equal(path.basename(bothResult.zipPath), `${ADDON}-2.3.4-forever.zip`);
  assert.equal(fs.readFileSync(bothResult.releaseJsonPath, 'utf8'), expectedReleaseJson(ADDON, '2.3.4', 16002), 'Interface-Forever wins');

  const foreverFirst = addonWithHeader(t, '## Interface-Forever: 16003\n## Interface: 11507\n## Version: 2.3.4\n');
  const foreverFirstResult = release(foreverFirst.copy, path.join(foreverFirst.work, 'out'));
  assert.equal(foreverFirstResult.releaseJson.releases[0].metadata[0].interface, 16003, 'also when it comes first');

  const plain = addonWithHeader(t, '## Interface: 11508\n## Title: Plain\n## Version: 2.3.5\n');
  const plainResult = release(plain.copy, path.join(plain.work, 'out'));
  assert.equal(fs.readFileSync(plainResult.releaseJsonPath, 'utf8'), expectedReleaseJson(ADDON, '2.3.5', 11508), 'without Interface-Forever: Interface');
});

test('a TOC without an interface line, or with an interface that is no number, is an error', (t) => {
  const none = addonWithHeader(t, '## Title: No Interface\n## Version: 1.0.0\n');
  const out = path.join(none.work, 'out');
  assert.throws(() => release(none.copy, out), /no "## Interface-Forever:" or "## Interface:" line/);
  const errors = [];
  const code = main([none.copy, '--out', out], () => {}, (line) => errors.push(line));
  assert.equal(code, 1);
  assert.match(errors.join('\n'), /Interface/);
  assert.ok(!fs.existsSync(out), 'nothing written');

  const text = addonWithHeader(t, '## Interface-Forever: 1.15.7\n## Interface: 11507\n## Version: 1.0.0\n');
  assert.throws(() => release(text.copy, path.join(text.work, 'out')), /"## Interface-Forever:" .* is not a number/);
  const list = addonWithHeader(t, '## Interface: 11507, 16001\n## Version: 1.0.0\n');
  assert.throws(() => release(list.copy, path.join(list.work, 'out')), /"## Interface:" .* is not a number/);
});

test('an empty interface or version line does not take its value from the next line', (t) => {
  const emptyForever = addonWithHeader(t, '## Interface-Forever:\n## Interface: 16001\n## Version: 1.0.0\n');
  assert.throws(() => release(emptyForever.copy, path.join(emptyForever.work, 'out')), /"## Interface-Forever:" .* is not a number: ""/);
  const emptyLast = addonWithHeader(t, '## Version: 1.0.0\n## Interface:\n16001\n');
  assert.throws(() => release(emptyLast.copy, path.join(emptyLast.work, 'out')), /"## Interface:" .* is not a number: ""/);
  const emptyVersion = addonWithHeader(t, '## Interface: 16001\n## Version:\nCore\n');
  assert.throws(() => release(emptyVersion.copy, path.join(emptyVersion.work, 'out')), /no "## Version:" line/);
  const crlf = addonWithHeader(t, '## Interface-Forever: 16004 \r\n## Version: 1.2.3\r\n');
  const { releaseJsonPath } = release(crlf.copy, path.join(crlf.work, 'out'));
  assert.equal(fs.readFileSync(releaseJsonPath, 'utf8'), expectedReleaseJson(ADDON, '1.2.3', 16004), 'CRLF and trailing blanks');
});

test('an existing release.json in the output folder is overwritten', (t) => {
  const out = tempDir(t);
  fs.writeFileSync(path.join(out, 'release.json'), '{"releases":[{"name":"Old"}]}\n');
  const { releaseJsonPath } = release(addonDir, out);
  assert.equal(fs.readFileSync(releaseJsonPath, 'utf8'), expectedReleaseJson(ADDON, tocVersion(addonDir), tocInterfaceForever(addonDir)));
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
    'release.json': '{"releases":[]}\n',
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

test('DOS date and time: before 1980 becomes 1980-01-01 00:00, later dates are kept', () => {
  assert.deepEqual(dosDateTime(new Date(1975, 5, 15, 13, 45, 30)), { time: 0, date: (1 << 5) | 1 });
  const { date, time } = dosDateTime(new Date(2026, 10, 6, 14, 37, 58));
  assert.deepEqual(fromDos(date, time), new Date(2026, 10, 6, 14, 37, 58));
  const odd = dosDateTime(new Date(1980, 0, 1, 0, 0, 1));
  assert.deepEqual(fromDos(odd.date, odd.time), new Date(1980, 0, 1, 0, 0, 0), 'seconds in steps of two');
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

test('the command line writes the zip and the release.json into --out and prints two lines', (t) => {
  const out = tempDir(t);
  const lines = [];
  const errors = [];
  const code = main([addonDir, '--out', out], (line) => lines.push(line), (line) => errors.push(line));
  assert.equal(code, 0, errors.join('\n'));
  assert.deepEqual(errors, []);
  const version = tocVersion(addonDir);
  const zip = path.join(out, `${ADDON}-${version}-forever.zip`);
  const json = path.join(out, 'release.json');
  assert.ok(fs.existsSync(zip), 'zip written');
  assert.ok(fs.existsSync(json), 'release.json written');
  assert.deepEqual(fs.readdirSync(out).sort(), [`${ADDON}-${version}-forever.zip`, 'release.json'], 'nothing else in --out');
  assert.equal(lines.length, 2, lines.join('\n'));
  const shown = (file) => path.relative(process.cwd(), file) || file;
  assert.match(lines[0], /\d+ entries, \d+ bytes$/);
  assert.ok(lines[0].startsWith(`${shown(zip)}: `), lines[0]);
  assert.equal(lines[1], shown(json));
});
