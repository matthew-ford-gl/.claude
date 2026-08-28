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
  const result = spawnSync('bash', ['--noprofile', '--norc', '-s'], {
    input: fs.readFileSync(script, 'utf8').replace(/\r/g, ''),
    stdio: ['pipe', 'inherit', 'inherit'],
    timeout: 15000,
  });
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
