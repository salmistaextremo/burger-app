const fs = require('fs');
const path = require('path');

const manifest = path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'AndroidManifest.xml');
if (!fs.existsSync(manifest)) {
  console.error('No existe AndroidManifest.xml');
  process.exit(1);
}

let xml = fs.readFileSync(manifest, 'utf8');
const permissions = [
  'android.permission.ACCESS_FINE_LOCATION',
  'android.permission.ACCESS_COARSE_LOCATION'
];

for (const permission of permissions) {
  if (!xml.includes('android:name="' + permission + '"')) {
    xml = xml.replace(
      '<application',
      '    <uses-permission android:name="' + permission + '" />\n    <application'
    );
  }
}

fs.writeFileSync(manifest, xml);
console.log('Permisos de ubicación agregados al manifest');
