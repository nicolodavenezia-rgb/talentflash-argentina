import { spawnSync } from 'node:child_process';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const testsDirectory = join(projectRoot, 'supabase', 'tests', 'database');
const databaseContainer =
  process.env.SUPABASE_DB_CONTAINER ?? 'supabase_db_talentflash_argentina';

function runDocker(argumentsList, input) {
  const result = spawnSync('docker', argumentsList, {
    cwd: projectRoot,
    encoding: 'utf8',
    input,
    maxBuffer: 16 * 1024 * 1024,
  });

  if (result.error) {
    throw result.error;
  }

  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  process.stdout.write(output);

  if (result.status !== 0) {
    throw new Error(`docker terminó con código ${result.status}`);
  }

  return output;
}

runDocker([
  'exec',
  databaseContainer,
  'psql',
  '-X',
  '-U',
  'postgres',
  '-d',
  'postgres',
  '-v',
  'ON_ERROR_STOP=1',
  '-c',
  'create extension if not exists pgtap with schema extensions',
]);

const testFiles = readdirSync(testsDirectory)
  .filter((fileName) => fileName.endsWith('.sql'))
  .sort();

let failed = false;

for (const fileName of testFiles) {
  process.stdout.write(`\n[db:test] ${fileName}\n`);
  const sql = readFileSync(join(testsDirectory, fileName), 'utf8');
  const output = runDocker(
    [
      'exec',
      '-e',
      'PGOPTIONS=--search_path=extensions,public',
      '-i',
      databaseContainer,
      'psql',
      '-X',
      '-U',
      'postgres',
      '-d',
      'postgres',
      '-v',
      'ON_ERROR_STOP=1',
      '-At',
    ],
    sql,
  );

  if (/^not ok\b/m.test(output)) {
    failed = true;
  }
}

if (failed) {
  throw new Error('La suite pgTAP reportó al menos una aserción fallida.');
}

process.stdout.write(`\n[db:test] ${testFiles.length} archivos aprobados.\n`);
