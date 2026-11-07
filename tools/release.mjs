#!/usr/bin/env node
// release.mjs: builds the release zip and the release.json of an addon folder in this repository.
//
// Usage
//   node tools/release.mjs <AddonFolder> [--out <directory>]    e.g. node tools/release.mjs SquareMinimapButtons
//   npm run release:smb
//
// Writes <out>/<Addon>-<Version>-forever.zip and <out>/release.json (default out: dist/ in the
// repository root). <Version> is the "## Version:" line of <AddonFolder>/<Addon>.toc; without it the
// script stops with an error. The zip has exactly one root folder, <Addon>/, which holds every file of
// the addon folder (sorted, paths with "/"). Left out at any depth: names starting with a dot, *.zip
// files and the folders tests/, tools/ and node_modules/, plus a release.json at the root of the addon
// folder (development files and build output live outside the addon folders; the rule is a safety net). Prints the path of the zip, the number of entries and its size,
// then the path of the release.json; exit code 1 on any error.
//
// release.json: addon managers for WoW Forever detect updates through the release.json that the
// BigWigs packager attaches to GitHub releases, and they match the asset by its name. Upload the zip
// and the release.json together as the assets of the GitHub release. The file is compact JSON with a
// final line break, with exactly these keys in this order:
//   {"releases":[{"name":"<Addon>","version":"<Version>","filename":"<Addon>-<Version>-forever.zip",
//     "nolib":false,"metadata":[{"flavor":"forever","interface":<Interface>}]}]}
// <Interface> is the number of the TOC line "## Interface-Forever:", or of "## Interface:" when that
// line is missing; a missing line or a value that is not a number is an error, as is a missing
// version. An existing release.json in the output folder is overwritten: it belongs to exactly one zip.
//
// Format: ZIP as described in PKWARE's APPNOTE.TXT (.ZIP File Format Specification), written by this
// script with Node's built-in modules only, no external zip program:
//   - a local file header (signature 0x04034b50) before the data of each entry, a central directory
//     header (0x02014b50) per entry and the end of central directory record (0x06054b50);
//   - an entry per folder (name ending in "/", stored, size 0) and per file;
//   - files compressed with method 8 (raw deflate, zlib.deflateRawSync at level 9); empty files and
//     folders are stored (method 0);
//   - CRC-32 (polynomial 0xEDB88320) computed here with a lookup table;
//   - last modification date and time in MS-DOS format from the file's mtime (local time; years
//     before 1980 become 1980-01-01 00:00, the earliest DOS date);
//   - general purpose bit 11 set (names are UTF-8), no data descriptors, no extra fields;
//   - version made by 3 (UNIX) with the permissions in the external attributes, so unzip on UNIX
//     restores 0644 for files and 0755 for folders;
//   - no ZIP64: more than 65535 entries or a size or offset of 4 GiB or more is an error.

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

export const EXCLUDED_FOLDERS = new Set(['tests', 'tools', 'node_modules']);

const MAX_UINT16 = 0xffff;
const MAX_UINT32 = 0xffffffff;
const FLAG_UTF8 = 0x0800;
const VERSION_MADE_BY = (3 << 8) | 20; // UNIX, specification 2.0
const VERSION_NEEDED = 20; // 2.0: deflate and folders

// ---------------------------------------------------------------------------------------------
// CRC-32
// ---------------------------------------------------------------------------------------------

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

export function crc32(buffer) {
  let crc = 0xffffffff;
  for (let i = 0; i < buffer.length; i++) crc = CRC_TABLE[(crc ^ buffer[i]) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

// ---------------------------------------------------------------------------------------------
// TOC and files
// ---------------------------------------------------------------------------------------------

// Returns { tocPath, text } of <addonDir>/<Addon>.toc, without a byte order mark.
function readToc(addonDir) {
  const tocPath = path.join(addonDir, `${path.basename(addonDir)}.toc`);
  if (!fs.existsSync(tocPath)) throw new Error(`no TOC file: ${tocPath}`);
  return { tocPath, text: fs.readFileSync(tocPath, 'utf8').replace(/^\uFEFF/, '') };
}

export function readVersion(addonDir) {
  const { tocPath, text } = readToc(addonDir);
  const match = /^##[ \t]*Version[ \t]*:[ \t]*(.*?)[ \t]*\r?$/m.exec(text);
  if (!match || match[1] === '') throw new Error(`no "## Version:" line in ${tocPath}`);
  const version = match[1];
  if (!/^[A-Za-z0-9][A-Za-z0-9._+-]*$/.test(version)) {
    throw new Error(`version "${version}" in ${tocPath} is not usable in a file name`);
  }
  return version;
}

// Interface number for the release.json: "## Interface-Forever:" first, then "## Interface:".
export function readInterface(addonDir) {
  const { tocPath, text } = readToc(addonDir);
  for (const key of ['Interface-Forever', 'Interface']) {
    const match = new RegExp(`^##[ \\t]*${key}[ \\t]*:[ \\t]*(.*?)[ \\t]*\\r?$`, 'm').exec(text);
    if (!match) continue;
    if (!/^\d+$/.test(match[1])) throw new Error(`"## ${key}:" in ${tocPath} is not a number: "${match[1]}"`);
    return Number(match[1]);
  }
  throw new Error(`no "## Interface-Forever:" or "## Interface:" line in ${tocPath}`);
}

// The release.json of the BigWigs packager for one zip, as an object in key order.
export function releaseInfo(addon, version, zipName, interfaceNumber) {
  return {
    releases: [
      {
        name: addon,
        version,
        filename: zipName,
        nolib: false,
        metadata: [{ flavor: 'forever', interface: interfaceNumber }],
      },
    ],
  };
}

export function isExcluded(name, isDirectory) {
  if (name.startsWith('.')) return true;
  if (isDirectory) return EXCLUDED_FOLDERS.has(name);
  return name.toLowerCase().endsWith('.zip');
}

const byCodeUnit = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

// Returns [{ rel, abs, isDirectory }] in zip order: each folder before its contents, names sorted.
// rel is relative to the addon folder and uses "/"; folders end in "/".
export function collectFiles(addonDir) {
  const out = [];
  const walk = (dir, prefix) => {
    const entries = fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => byCodeUnit(a.name, b.name));
    for (const entry of entries) {
      const abs = path.join(dir, entry.name);
      if (entry.isSymbolicLink()) throw new Error(`symbolic links are not supported: ${abs}`);
      const isDirectory = entry.isDirectory();
      if (!isDirectory && !entry.isFile()) throw new Error(`not a file or folder: ${abs}`);
      if (isExcluded(entry.name, isDirectory)) continue;
      // a release.json from an earlier run with --out inside the addon folder is build output
      if (prefix === '' && !isDirectory && entry.name === 'release.json') continue;
      if (isDirectory) {
        out.push({ rel: `${prefix}${entry.name}/`, abs, isDirectory: true });
        walk(abs, `${prefix}${entry.name}/`);
      } else {
        out.push({ rel: `${prefix}${entry.name}`, abs, isDirectory: false });
      }
    }
  };
  walk(addonDir, '');
  return out;
}

// ---------------------------------------------------------------------------------------------
// ZIP writer
// ---------------------------------------------------------------------------------------------

export function dosDateTime(date) {
  if (date.getFullYear() < 1980) return { time: 0, date: (0 << 9) | (1 << 5) | 1 };
  const year = Math.min(date.getFullYear(), 2107);
  return {
    time: (date.getHours() << 11) | (date.getMinutes() << 5) | Math.floor(date.getSeconds() / 2),
    date: ((year - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate(),
  };
}

function checkLimit(value, max, what) {
  if (value > max) throw new Error(`${what} too large for a zip without ZIP64 (${value})`);
}

// entries: [{ name, data (Buffer, absent for folders), isDirectory, mtime (Date) }]
export function buildZip(entries) {
  checkLimit(entries.length, MAX_UINT16, 'number of entries');
  const parts = [];
  const central = [];
  let offset = 0;

  for (const entry of entries) {
    const name = Buffer.from(entry.name, 'utf8');
    checkLimit(name.length, MAX_UINT16, `name of ${entry.name}`);
    const data = entry.isDirectory ? Buffer.alloc(0) : entry.data;
    checkLimit(data.length, MAX_UINT32, `size of ${entry.name}`);
    const method = data.length === 0 ? 0 : 8;
    const compressed = method === 8 ? zlib.deflateRawSync(data, { level: 9 }) : data;
    checkLimit(compressed.length, MAX_UINT32, `compressed size of ${entry.name}`);
    const crc = crc32(data);
    const { time, date } = dosDateTime(entry.mtime);
    checkLimit(offset, MAX_UINT32, `offset of ${entry.name}`);

    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(VERSION_NEEDED, 4);
    local.writeUInt16LE(FLAG_UTF8, 6);
    local.writeUInt16LE(method, 8);
    local.writeUInt16LE(time, 10);
    local.writeUInt16LE(date, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(compressed.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(name.length, 26);
    local.writeUInt16LE(0, 28); // extra field length
    parts.push(local, name, compressed);

    const mode = entry.isDirectory ? 0o040755 : 0o100644;
    const header = Buffer.alloc(46);
    header.writeUInt32LE(0x02014b50, 0);
    header.writeUInt16LE(VERSION_MADE_BY, 4);
    header.writeUInt16LE(VERSION_NEEDED, 6);
    header.writeUInt16LE(FLAG_UTF8, 8);
    header.writeUInt16LE(method, 10);
    header.writeUInt16LE(time, 12);
    header.writeUInt16LE(date, 14);
    header.writeUInt32LE(crc, 16);
    header.writeUInt32LE(compressed.length, 20);
    header.writeUInt32LE(data.length, 24);
    header.writeUInt16LE(name.length, 28);
    header.writeUInt16LE(0, 30); // extra field length
    header.writeUInt16LE(0, 32); // comment length
    header.writeUInt16LE(0, 34); // disk number start
    header.writeUInt16LE(0, 36); // internal attributes
    header.writeUInt32LE(((mode << 16) | (entry.isDirectory ? 0x10 : 0)) >>> 0, 38); // external attributes
    header.writeUInt32LE(offset, 42);
    central.push(header, name);

    offset += local.length + name.length + compressed.length;
  }

  const centralSize = central.reduce((sum, b) => sum + b.length, 0);
  checkLimit(offset, MAX_UINT32, 'offset of the central directory');
  checkLimit(centralSize, MAX_UINT32, 'size of the central directory');

  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(0, 4); // number of this disk
  end.writeUInt16LE(0, 6); // disk with the central directory
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(centralSize, 12);
  end.writeUInt32LE(offset, 16);
  end.writeUInt16LE(0, 20); // comment length

  return Buffer.concat([...parts, ...central, end]);
}

// ---------------------------------------------------------------------------------------------
// Release
// ---------------------------------------------------------------------------------------------

// Returns { zipPath, entries (number), size (bytes), version, names, releaseJsonPath, releaseJson }.
export function release(addonDir, outDir = path.join(repoRoot, 'dist')) {
  const dir = path.resolve(addonDir);
  if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) throw new Error(`not a folder: ${dir}`);
  const addon = path.basename(dir);
  const version = readVersion(dir);
  const interfaceNumber = readInterface(dir);

  const entries = [{ name: `${addon}/`, isDirectory: true, mtime: fs.statSync(dir).mtime }];
  for (const file of collectFiles(dir)) {
    const stat = fs.statSync(file.abs);
    entries.push({
      name: `${addon}/${file.rel}`,
      isDirectory: file.isDirectory,
      data: file.isDirectory ? undefined : fs.readFileSync(file.abs),
      mtime: stat.mtime,
    });
  }

  const zip = buildZip(entries);
  fs.mkdirSync(outDir, { recursive: true });
  const zipName = `${addon}-${version}-forever.zip`;
  const zipPath = path.join(outDir, zipName);
  fs.writeFileSync(zipPath, zip);
  const releaseJson = releaseInfo(addon, version, zipName, interfaceNumber);
  const releaseJsonPath = path.join(outDir, 'release.json');
  fs.writeFileSync(releaseJsonPath, `${JSON.stringify(releaseJson)}\n`);
  return {
    zipPath,
    entries: entries.length,
    size: zip.length,
    version,
    names: entries.map((e) => e.name),
    releaseJsonPath,
    releaseJson,
  };
}

function parseArgs(argv) {
  let addon;
  let out;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--out') {
      out = argv[++i];
      if (!out) throw new Error('--out needs a directory');
    } else if (arg.startsWith('--')) {
      throw new Error(`unknown option ${arg}`);
    } else if (addon === undefined) {
      addon = arg;
    } else {
      throw new Error(`unexpected argument ${arg}`);
    }
  }
  if (!addon) throw new Error('usage: node tools/release.mjs <AddonFolder> [--out <directory>]');
  return { addon, out };
}

// The addon folder is resolved against the current directory, then against the repository root.
export function main(argv, log = console.log, logError = console.error) {
  try {
    const { addon, out } = parseArgs(argv);
    let addonDir = path.resolve(addon);
    if (!fs.existsSync(addonDir)) addonDir = path.resolve(repoRoot, addon);
    const outDir = out ? path.resolve(out) : path.join(repoRoot, 'dist');
    const result = release(addonDir, outDir);
    const shown = (file) => path.relative(process.cwd(), file) || file;
    log(`${shown(result.zipPath)}: ${result.entries} entries, ${result.size} bytes`);
    log(shown(result.releaseJsonPath));
    return 0;
  } catch (e) {
    logError(`release: ${e.message}`);
    return 1;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
