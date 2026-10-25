import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {
  externalizeSharedTextures,
  sharedTextureResourceLoader,
  sharedTextureSummary,
  writeSharedTextures,
} from '../asset-forge/gate/shared_textures.mjs';

const align4 = (data, fill = 0) => Buffer.concat([data, Buffer.alloc((4 - data.length % 4) % 4, fill)]);

function makeGlb(json, bin) {
  const jsonData = align4(Buffer.from(JSON.stringify(json)), 0x20);
  const binData = align4(bin);
  const out = Buffer.alloc(28 + jsonData.length + binData.length);
  out.writeUInt32LE(0x46546c67, 0);
  out.writeUInt32LE(2, 4);
  out.writeUInt32LE(out.length, 8);
  out.writeUInt32LE(jsonData.length, 12);
  out.writeUInt32LE(0x4e4f534a, 16);
  jsonData.copy(out, 20);
  const offset = 20 + jsonData.length;
  out.writeUInt32LE(binData.length, offset);
  out.writeUInt32LE(0x004e4942, offset + 4);
  binData.copy(out, offset + 8);
  return out;
}

function readGlb(binary) {
  const jsonLength = binary.readUInt32LE(12);
  const json = JSON.parse(binary.subarray(20, 20 + jsonLength).toString('utf8'));
  const offset = 20 + jsonLength;
  const length = binary.readUInt32LE(offset);
  return { json, bin: binary.subarray(offset + 8, offset + 8 + length) };
}

test('byte-identical images share URIs while non-image buffer data stays exact', async () => {
  const geometry = Buffer.from([1, 2, 3, 4]);
  const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);
  const views = [
    { buffer: 0, byteOffset: 0, byteLength: geometry.length },
    { buffer: 0, byteOffset: 4, byteLength: jpeg.length },
    { buffer: 0, byteOffset: 8, byteLength: jpeg.length },
  ];
  const input = makeGlb({
    asset: { version: '2.0' },
    buffers: [{ byteLength: 12 }],
    bufferViews: views,
    accessors: [{ bufferView: 0, componentType: 5121, count: 4, type: 'SCALAR' }],
    images: [
      { bufferView: 1, mimeType: 'image/jpeg' },
      { bufferView: 2, mimeType: 'image/jpeg' },
    ],
  }, Buffer.concat([geometry, jpeg, jpeg]));

  const registry = new Map();
  const output = externalizeSharedTextures(input, 'frostline', registry);
  const { json, bin } = readGlb(output);
  assert.equal(registry.size, 1);
  assert.equal(json.images[0].uri, json.images[1].uri);
  assert.equal(json.images[0].bufferView, undefined);
  assert.equal(json.bufferViews.length, 1);
  assert.equal(json.accessors[0].bufferView, 0);
  assert.deepEqual(bin, geometry);

  const shared = [...registry.values()][0];
  assert.equal(shared.references, 2);
  assert.deepEqual([...shared.worlds], ['frostline']);
  const loaded = await sharedTextureResourceLoader(registry)(json.images[0].uri);
  assert.deepEqual(Buffer.from(loaded), jpeg);
  const summary = sharedTextureSummary(registry);
  assert.equal(summary.count, 1);
  assert.equal(summary.references, 2);
  assert.equal(summary.bytes, jpeg.length);

  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'shared-textures-'));
  try {
    const stale = `${'0'.repeat(64)}.jpg`;
    fs.writeFileSync(path.join(temp, stale), 'stale');
    writeSharedTextures(registry, temp);
    assert.deepEqual(fs.readFileSync(path.join(temp, shared.fileName)), jpeg);
    assert.equal(fs.existsSync(path.join(temp, stale)), false);
  } finally {
    fs.rmSync(temp, { recursive: true, force: true });
  }
});
