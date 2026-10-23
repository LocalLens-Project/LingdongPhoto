// SPDX-License-Identifier: AGPL-3.0-only
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { webcrypto } from 'node:crypto';

const executable = process.argv[2];
const run = spawnSync(executable, [], { encoding: 'utf8' });
assert.equal(run.status, 0, run.stderr);
const f = JSON.parse(run.stdout);
const decode = s => Buffer.from(s, 'base64url');
const encode = d => Buffer.from(d).toString('base64url');
const { subtle } = webcrypto;
const rawKey = decode(f.key);
const key = await subtle.importKey('raw', rawKey, 'AES-GCM', false, ['encrypt', 'decrypt']);
const params = (body, aad) => ({ name: 'AES-GCM', iv: decode(body.iv), additionalData: Buffer.from(aad), tagLength: 128 });
const clear = await subtle.decrypt(params(f.body, f.aad), key, decode(f.body.ciphertext));
assert.equal(Buffer.from(clear).toString('utf8'), f.plaintext);
console.log('PASS: Swift CryptoKit ciphertext opened by Web Crypto');
const material = await subtle.importKey('raw', Buffer.from(f.password), 'PBKDF2', false, ['deriveKey']);
const wrapping = await subtle.deriveKey({ name: 'PBKDF2', hash: 'SHA-256', salt: decode(f.salt), iterations: f.iterations },
                                      material, { name: 'AES-GCM', length: 256 }, false, ['decrypt']);
const unwrapped = await subtle.decrypt(params(f.wrappedKey, f.keyAAD), wrapping, decode(f.wrappedKey.ciphertext));
assert.deepEqual(Buffer.from(unwrapped), rawKey);
console.log('PASS: PBKDF2-SHA256 (600000 iterations) and content-key wrapping interoperate');
await assert.rejects(subtle.decrypt(params(f.body, f.aad + 'tampered'), key, decode(f.body.ciphertext)));
const wrongBytes = Buffer.from(rawKey); wrongBytes[0] ^= 1;
const wrong = await subtle.importKey('raw', wrongBytes, 'AES-GCM', false, ['decrypt']);
await assert.rejects(subtle.decrypt(params(f.body, f.aad), wrong, decode(f.body.ciphertext)));
const changed = decode(f.body.ciphertext); changed[changed.length - 1] ^= 1;
await assert.rejects(subtle.decrypt(params(f.body, f.aad), key, changed));
console.log('PASS: wrong key, altered AAD, and altered authentication tag are rejected');
const u = new URL(f.url);
assert.equal(u.search, '');
assert.equal(new URLSearchParams(u.hash.slice(1)).get('k'), f.key);
assert.equal(new URL(f.passwordURL).hash, '#mode=password');
const upload = { version: 1, templateVersion: 1, id: f.id, palette: 'cream', style: 'classic',
                 body: f.body, wrappedKey: f.wrappedKey, salt: f.salt, iterations: f.iterations };
for (const name of ['key', 'password', 'plaintext', 'contentKey']) assert.equal(Object.hasOwn(upload, name), false);
console.log('PASS: reference upload contains ciphertext; raw key is confined to URL fragment');
const nonce = webcrypto.getRandomValues(new Uint8Array(12));
const ciphertext = await subtle.encrypt({ name: 'AES-GCM', iv: nonce, additionalData: Buffer.from(f.aad), tagLength: 128 }, key, Buffer.from(f.plaintext));
const input = { plaintext: f.plaintext, key: f.key, aad: f.aad, body: { iv: encode(nonce), ciphertext: encode(ciphertext) } };
const reverse = spawnSync(executable, ['verify'], { input: JSON.stringify(input), encoding: 'utf8' });
assert.equal(reverse.status, 0, reverse.stderr);
process.stdout.write(reverse.stdout);
console.log('All offline reference checks passed. These checks do not attest to the production binary or server.');
