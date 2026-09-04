#!/usr/bin/env node

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const configDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
const action = process.argv[1];

if (action === 'alert') {
  const script = process.env.AI_ALERT_SCRIPT || path.join(os.homedir(), '.agents', 'hooks', 'scripts', 'send-ai-alert.sh');
  if (!fs.existsSync(script)) process.exit(0);
  const tempScript = path.join(os.tmpdir(), `claude-alert-${process.pid}.sh`);
  fs.writeFileSync(tempScript, fs.readFileSync(script, 'utf8').replace(/\r/g, ''));
  const input = fs.readFileSync(0);

  const runBash = (bashPath) => spawnSync('bash', ['--noprofile', '--norc', bashPath], {
    input,
    stdio: ['pipe', 'pipe', 'pipe'],
    timeout: 15000,
  });

  let result;
  if (process.platform === 'win32') {
    // Git Bash mounts drives at /c/..., not the WSL /mnt/c/... convention — try that first.
    const gitBashPath = tempScript.replace(/^([A-Za-z]):/, (_, drive) => `/${drive.toLowerCase()}`).replace(/\\/g, '/');
    result = runBash(gitBashPath);
    const pathLookupFailed = result.error || /no such file or directory/i.test(String(result.stderr || ''));
    if (pathLookupFailed) {
      const wslPath = tempScript.replace(/^([A-Za-z]):/, (_, drive) => `/mnt/${drive.toLowerCase()}`).replace(/\\/g, '/');
      result = runBash(wslPath);
    }
  } else {
    result = runBash(tempScript);
  }

  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  fs.unlinkSync(tempScript);
  process.exit(result.status || 0);
}

if (action === 'python') {
  const script = path.join(configDir, process.argv[2]);
  const input = fs.readFileSync(0);
  const candidates = process.platform === 'win32'
    ? [['py', ['-3']], ['python', []], ['python3', []]]
    : [['python3', []], ['python', []]];

  for (const [command, args] of candidates) {
    const result = spawnSync(command, [...args, script], { input, encoding: 'utf8' });
    if (!result.error || result.error.code !== 'ENOENT') {
      if (result.stdout) process.stdout.write(result.stdout);
      if (result.stderr) process.stderr.write(result.stderr);
      process.exit(result.status || 0);
    }
  }
  process.stderr.write('No Python 3 executable found on PATH.\n');
  process.exit(1);
}

if (action === 'node') {
  require(path.join(configDir, 'hooks', process.argv[2]));
  return;
}

process.stderr.write(`Unknown portable runner action: ${action || '(missing)'}\n`);
process.exit(1);
