const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const repoRoot = path.join(__dirname, '..');
const envPath = path.join(repoRoot, 'frontend', '.env');

const WHITELIST = new Set([
  'HOST',
  'SERVER_PORT',
  'PROTOCOL',
  'DISCORD_CLIENT_ID',
]);

function parseEnv(content) {
  const map = new Map();
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const idx = line.indexOf('=');
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    let val = line.slice(idx + 1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    map.set(key, val);
  }
  return map;
}

function main() {
  let defines = [];
  if (fs.existsSync(envPath)) {
    try {
      const content = fs.readFileSync(envPath, 'utf8');
      const env = parseEnv(content);
      for (const [k, v] of env) {
        if (!WHITELIST.has(k)) continue;
        if (v == null || v === '') continue;
        defines.push(`--dart-define=${k}=${v}`);
      }
    } catch (e) {
      console.error('Failed to read .env:', e);
    }
  } else {
    console.warn('No frontend/.env found, running flutter build without defines.');
  }

  const args = ['build', 'web', '--no-wasm-dry-run', '--release', ...defines];

  function findFlutterBinary() {
    const isWin = process.platform === 'win32';
    const probeCmd = isWin ? 'where' : 'which';
    const candidates = isWin ? ['flutter.bat', 'flutter'] : ['flutter'];
    for (const cand of candidates) {
      try {
        const r = spawnSync(probeCmd, [cand], { encoding: 'utf8' });
        if (r.status === 0 && r.stdout) {
          const first = r.stdout.split(/\r?\n/)[0].trim();
          if (first) return first;
        }
      } catch (e) {
        // ignore and try next
      }
    }
    // try FLUTTER_ROOT if present
    if (process.env.FLUTTER_ROOT) {
      const exe = path.join(process.env.FLUTTER_ROOT, 'bin', isWin ? 'flutter.bat' : 'flutter');
      if (fs.existsSync(exe)) return exe;
    }
    return null;
  }

  const flutterBin = findFlutterBinary();
  if (!flutterBin) {
    console.error('Flutter executable not found in PATH. Please install Flutter and add it to your PATH.');
    console.error('On Windows, ensure the Flutter SDK `bin` folder is on PATH (e.g. C:\\src\\flutter\\bin).');
    console.error('You can test by running `where flutter` in PowerShell.');
    process.exit(1);
  }

  console.log('Running:', flutterBin, args.join(' '));
  let res;
  if (process.platform === 'win32') {
    res = spawnSync('cmd', ['/c', flutterBin, ...args], {
      cwd: path.join(repoRoot, 'frontend'),
      stdio: 'inherit',
    });
  } else {
    res = spawnSync(flutterBin, args, {
      cwd: path.join(repoRoot, 'frontend'),
      stdio: 'inherit',
    });
  }
  if (res.error) {
    console.error('Failed to run flutter:', res.error);
    process.exit(1);
  }
  process.exit(res.status || 0);
}

main();
