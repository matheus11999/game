// Native Windows launcher: no npm installation or browser required.
import { spawn } from 'node:child_process';
import { openSync, mkdirSync, closeSync, readFileSync, writeFileSync, unlinkSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const version = JSON.parse(readFileSync(resolve(root, 'server/package.json'), 'utf8')).version;
const lockPath = resolve(root, 'server/data/launcher.lock');
let ownedServer;
let game;
let ownsLock = false;
let serverError;

function assertNoOwnedLauncher() {
  let pid;
  try { pid = Number(readFileSync(lockPath, 'utf8')); } catch (error) { if (error.code === 'ENOENT') return; throw error; }
  if (!Number.isInteger(pid) || pid < 1) throw new Error('Inicializador em andamento. Aguarde e tente novamente.');
  try { process.kill(pid, 0); } catch (error) {
    if (error.code === 'ESRCH') { unlinkSync(lockPath); return; }
    throw error;
  }
  throw new Error('TaskMon já está aberto com servidor automático. Para duas janelas, feche o jogo e inicie Iniciar-Servidor.bat primeiro.');
}

function acquireLock() {
  mkdirSync(dirname(lockPath), { recursive: true });
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const fd = openSync(lockPath, 'wx');
      writeFileSync(fd, String(process.pid));
      closeSync(fd);
      ownsLock = true;
      return;
    } catch (error) {
      if (error.code !== 'EEXIST') throw error;
      const pid = Number(readFileSync(lockPath, 'utf8'));
      if (!Number.isInteger(pid) || pid < 1) throw new Error('Inicializador em andamento. Aguarde e tente novamente.');
      try {
        process.kill(pid, 0);
        throw new Error('TaskMon já está aberto nesta pasta. Feche a outra janela antes de iniciar novamente.');
      } catch (probe) {
        if (probe.code !== 'ESRCH') throw probe;
      }
      unlinkSync(lockPath);
    }
  }
  throw new Error('Não foi possível reservar o inicializador. Tente novamente.');
}

async function health() {
  let response;
  try {
    response = await fetch('http://127.0.0.1:8787/health', { signal: AbortSignal.timeout(1000) });
  } catch (error) {
    if (error.cause?.code === 'ECONNREFUSED') return false;
    throw new Error('A porta 8787 não respondeu corretamente. Feche outros serviços nessa porta e tente novamente.');
  }
  let data;
  try { data = await response.json(); } catch { throw new Error('Outro serviço ocupa a porta 8787.'); }
  if (!response.ok || data.ok !== true || data.game !== 'TaskMon' || data.version !== version) {
    throw new Error('Outro serviço ou versão ocupa a porta 8787.');
  }
  return true;
}

function cleanup() {
  if (game && game.exitCode === null && !game.killed) game.kill();
  if (ownedServer && ownedServer.exitCode === null && !ownedServer.killed) ownedServer.kill();
  if (ownsLock) {
    try { unlinkSync(lockPath); } catch (error) { if (error.code !== 'ENOENT') console.error('Não foi possível remover launcher.lock:', error.message); }
    ownsLock = false;
  }
}
process.on('exit', cleanup);
process.on('SIGINT', () => { cleanup(); process.exit(130); });
process.on('SIGTERM', () => { cleanup(); process.exit(143); });

try {
  assertNoOwnedLauncher();
  if (!await health()) {
    acquireLock();
    const fd = openSync(resolve(root, 'server/data/server.log'), 'a');
    try {
      ownedServer = spawn(process.execPath, [resolve(root, 'server/index.ts')], {
        cwd: root, stdio: ['ignore', fd, fd], windowsHide: true,
        env: { ...process.env, BRUMORA_HOST: '127.0.0.1', BRUMORA_PORT: '8787' },
      });
    } finally { closeSync(fd); }
    ownedServer.on('error', error => { serverError = error; });
    let ready = false;
    for (let i = 0; i < 30; i++) {
      if (serverError) throw new Error(`Não foi possível iniciar o servidor: ${serverError.message}`);
      if (ownedServer.exitCode !== null) throw new Error('Servidor não iniciou. Consulte server/data/server.log.');
      if (await health()) { ready = true; break; }
      await delay(250);
    }
    if (!ready) throw new Error('Servidor local não respondeu. Consulte server/data/server.log.');
  }
  console.log('Servidor pronto. Abrindo TaskMon…');
  console.log('Ao fechar o jogo, o servidor iniciado por este launcher será encerrado. A expedição AFK progride apenas com o jogo aberto.');
  game = spawn(resolve(root, 'TaskMon.exe'), [], { cwd: root, stdio: 'ignore' });
  const code = await new Promise((resolveExit, reject) => { game.once('error', reject); game.once('exit', resolveExit); });
  if (code !== 0) throw new Error('O jogo terminou com erro. Verifique o log Godot em %APPDATA%/Godot/app_userdata/Brumora — MVP/logs.');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally { cleanup(); }
