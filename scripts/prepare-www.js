const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const out = path.join(root, 'www');

const files = [
  'index.html',
  'admin.html',
  'repartidor.html',
  'app-config.js',
  'sw.js',
  'manifest.json',
  'manifest-cliente.json',
  'manifest-repartidor.json',
  'icon-192.png',
  'icon-512.png',
  'icon-maskable-512.png',
  'icon-180.png',
  'favicon.ico'
];

fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });

const missing = [];
for (const name of files) {
  const src = path.join(root, name);
  if (!fs.existsSync(src)) {
    missing.push(name);
    continue;
  }
  fs.copyFileSync(src, path.join(out, name));
}

for (const dir of ['assets', 'img', 'images']) {
  const src = path.join(root, dir);
  if (fs.existsSync(src)) {
    fs.cpSync(src, path.join(out, dir), { recursive: true });
  }
}

if (missing.length) {
  console.error('Faltan archivos: ' + missing.join(', '));
  process.exit(1);
}

console.log('www generado con ' + files.length + ' archivos');
