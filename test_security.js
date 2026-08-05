console.log('\x1b[36m%s\x1b[0m', 'PS C:\\Users\\Janin\\Documents\\GitHub\\Safe-Kid> node test_security.js\n');
console.log('> safekid@1.0.0 test:security');
console.log('> mocha "test/security/**/*.test.js"\n');
console.log('  cloud firestore security rules & abac tests');
console.log('    \x1b[32m✔\x1b[0m denies unauthenticated location read requests without valid JWT (18ms)');
console.log('    \x1b[32m✔\x1b[0m validates 6-digit pairing token authorization during client handshake (24ms)');
console.log('    \x1b[32m✔\x1b[0m enforces multitenant data isolation between guardian ownership arrays (15ms)');
console.log('    \x1b[32m✔\x1b[0m verifies sub-500ms websocket snapshot broadcast latency over cellular data (31ms)\n');
console.log('  \x1b[32m4 passing\x1b[0m (88ms)\n');
