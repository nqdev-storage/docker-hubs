'use strict';

function uuidV4Fallback() {
  const { randomBytes } = require('node:crypto');
  const buf = randomBytes(16);
  // RFC 4122: version 4
  buf[6] = (buf[6] & 0x0f) | 0x40;
  // RFC 4122: variant
  buf[8] = (buf[8] & 0x3f) | 0x80;
  const h = buf.toString('hex');
  return (
    h.slice(0, 8) +
    '-' +
    h.slice(8, 12) +
    '-' +
    h.slice(12, 16) +
    '-' +
    h.slice(16, 20) +
    '-' +
    h.slice(20, 32)
  );
}

// Ensure globalThis.crypto exists
if (typeof globalThis.crypto === 'undefined') {
  Object.defineProperty(globalThis, 'crypto', {
    value: {},
    configurable: true,
    writable: true,
  });
}

// Fallback if randomUUID missing
if (typeof globalThis.crypto.randomUUID !== 'function') {
  globalThis.crypto.randomUUID = uuidV4Fallback;
}

// Defensive: also patch node:crypto.webcrypto if present
try {
  const nodeCrypto = require('node:crypto');
  if (nodeCrypto.webcrypto && typeof nodeCrypto.webcrypto.randomUUID !== 'function') {
    nodeCrypto.webcrypto.randomUUID = uuidV4Fallback;
  }
} catch (_) {
  // ignore
}
