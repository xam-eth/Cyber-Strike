/**
 * Share byte-identical glTF textures across the staged mission worlds.
 *
 * Godot imports every embedded image as a separate texture, even when three
 * GLBs contain the same JPEG. External content-addressed URIs give the engine
 * one resource path per image instead. Geometry, materials, texels and image
 * compression are unchanged; only duplicate binary storage is removed.
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const GLB_MAGIC = 0x46546c67;
const JSON_CHUNK = 0x4e4f534a;
const BIN_CHUNK = 0x004e4942;
const EXTENSIONS = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

function align4(buffer, fill = 0) {
  const padding = (4 - (buffer.length % 4)) % 4;
  return padding ? Buffer.concat([buffer, Buffer.alloc(padding, fill)]) : buffer;
}

function parseGlb(input) {
  const binary = Buffer.from(input);
  if (binary.length < 28 || binary.readUInt32LE(0) !== GLB_MAGIC || binary.readUInt32LE(4) !== 2) {
    throw new Error('expected a glTF 2 binary GLB');
  }
  if (binary.readUInt32LE(8) !== binary.length) throw new Error('GLB length header does not match its bytes');
  const jsonLength = binary.readUInt32LE(12);
  if (binary.readUInt32LE(16) !== JSON_CHUNK) throw new Error('GLB has no leading JSON chunk');
  const jsonEnd = 20 + jsonLength;
  if (jsonEnd + 8 > binary.length || binary.readUInt32LE(jsonEnd + 4) !== BIN_CHUNK) {
    throw new Error('GLB has no binary chunk');
  }
  const binLength = binary.readUInt32LE(jsonEnd);
  const binStart = jsonEnd + 8;
  if (binStart + binLength !== binary.length) throw new Error('unexpected trailing GLB data');
  return {
    json: JSON.parse(binary.subarray(20, jsonEnd).toString('utf8')),
    bin: binary.subarray(binStart, binStart + binLength),
  };
}

function visitBufferViews(value, visit) {
  if (Array.isArray(value)) {
    for (const entry of value) visitBufferViews(entry, visit);
    return;
  }
  if (!value || typeof value !== 'object') return;
  for (const [key, entry] of Object.entries(value)) {
    if (key === 'bufferView' && Number.isInteger(entry)) visit(entry);
    else visitBufferViews(entry, visit);
  }
}

function writeGlb(json, bin) {
  const jsonChunk = align4(Buffer.from(JSON.stringify(json), 'utf8'), 0x20);
  const binChunk = align4(bin);
  const output = Buffer.alloc(28 + jsonChunk.length + binChunk.length);
  output.writeUInt32LE(GLB_MAGIC, 0);
  output.writeUInt32LE(2, 4);
  output.writeUInt32LE(output.length, 8);
  output.writeUInt32LE(jsonChunk.length, 12);
  output.writeUInt32LE(JSON_CHUNK, 16);
  jsonChunk.copy(output, 20);
  const binHeader = 20 + jsonChunk.length;
  output.writeUInt32LE(binChunk.length, binHeader);
  output.writeUInt32LE(BIN_CHUNK, binHeader + 4);
  binChunk.copy(output, binHeader + 8);
  return output;
}

/**
 * @param {Uint8Array} input embedded GLB produced by the existing stage pipeline
 * @param {string} worldId manifest id, used only for provenance/reporting
 * @param {Map<string, object>} registry shared across all mission worlds
 * @returns {Buffer} GLB whose images reference ../textures/<sha256>.<ext>
 */
export function externalizeSharedTextures(input, worldId, registry) {
  const { json, bin } = parseGlb(input);
  if (json.buffers?.length !== 1 || json.buffers[0].uri) {
    throw new Error(`${worldId}: expected one embedded binary buffer`);
  }

  for (const image of json.images ?? []) {
    if (!Number.isInteger(image.bufferView)) {
      throw new Error(`${worldId}: image is already external; refusing a second lossy/staging pass`);
    }
    const extension = EXTENSIONS[image.mimeType];
    if (!extension) throw new Error(`${worldId}: unsupported image MIME ${image.mimeType}`);
    const view = json.bufferViews[image.bufferView];
    const start = view.byteOffset ?? 0;
    const data = bin.subarray(start, start + view.byteLength);
    const hash = crypto.createHash('sha256').update(data).digest('hex');
    const fileName = `${hash}.${extension}`;
    if (!registry.has(fileName)) {
      registry.set(fileName, { fileName, data: Buffer.from(data), worlds: new Set(), references: 0 });
    }
    const shared = registry.get(fileName);
    shared.worlds.add(worldId);
    shared.references += 1;
    delete image.bufferView;
    image.uri = `../textures/${fileName}`;
  }

  // Rebuild the binary buffer without the now-unreferenced image views. Walk
  // the complete JSON so accessor and extension bufferView references are both
  // remapped; no geometry or animation payload is rewritten.
  const used = new Set();
  visitBufferViews(json, (index) => used.add(index));
  const ordered = [...used].sort((a, b) => a - b);
  const remap = new Map();
  const views = [];
  let nextBin = Buffer.alloc(0);
  for (const oldIndex of ordered) {
    const old = json.bufferViews[oldIndex];
    if (!old) throw new Error(`${worldId}: missing bufferView ${oldIndex}`);
    const start = old.byteOffset ?? 0;
    nextBin = align4(nextBin);
    const next = { ...old, byteOffset: nextBin.length };
    nextBin = Buffer.concat([nextBin, bin.subarray(start, start + old.byteLength)]);
    remap.set(oldIndex, views.length);
    views.push(next);
  }
  const remapTree = (value) => {
    if (Array.isArray(value)) {
      for (const entry of value) remapTree(entry);
      return;
    }
    if (!value || typeof value !== 'object') return;
    for (const [key, entry] of Object.entries(value)) {
      if (key === 'bufferView' && Number.isInteger(entry)) value[key] = remap.get(entry);
      else remapTree(entry);
    }
  };
  remapTree(json);
  json.bufferViews = views;
  json.buffers[0].byteLength = nextBin.length;
  return writeGlb(json, nextBin);
}

/** Let Khronos validate external images before any of them is written. */
export function sharedTextureResourceLoader(registry) {
  return async (uri) => {
    const fileName = path.basename(decodeURIComponent(uri));
    const entry = registry.get(fileName);
    if (!entry) throw new Error(`unknown shared texture URI: ${uri}`);
    return new Uint8Array(entry.data);
  };
}

export function sharedTextureSummary(registry) {
  const textures = [...registry.values()];
  return {
    policy: 'byte-identical images use content-addressed URIs shared by every mission GLB; pixels and JPEG encoding are not changed',
    count: textures.length,
    references: textures.reduce((sum, entry) => sum + entry.references, 0),
    bytes: textures.reduce((sum, entry) => sum + entry.data.length, 0),
    files: textures.map((entry) => ({
      path: `res://assets/forge/textures/${entry.fileName}`,
      bytes: entry.data.length,
      references: entry.references,
      worlds: [...entry.worlds].sort(),
    })).sort((a, b) => a.path.localeCompare(b.path)),
  };
}

/** Write only this tool's content-addressed products and prune its stale ones. */
export function writeSharedTextures(registry, textureDir) {
  fs.mkdirSync(textureDir, { recursive: true });
  for (const entry of registry.values()) fs.writeFileSync(path.join(textureDir, entry.fileName), entry.data);
  for (const file of fs.readdirSync(textureDir)) {
    if (/^[a-f0-9]{64}\.(?:jpg|png|webp)$/.test(file) && !registry.has(file)) fs.rmSync(path.join(textureDir, file));
  }
  return sharedTextureSummary(registry);
}
