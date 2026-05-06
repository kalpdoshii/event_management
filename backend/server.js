import express from 'express';
import cors from 'cors';
import initSqlJs from 'sql.js';
import { existsSync } from 'node:fs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const app = express();
const port = process.env.PORT || 3000;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const dataDir = path.join(__dirname, 'data');
const dbPath = path.join(dataDir, 'checkins.sqlite');

let SQL;
let db;
let dbReady;

async function saveDatabase() {
  if (!db) return;
  const data = db.export();
  await writeFile(dbPath, Buffer.from(data));
}

async function initializeDatabase() {
  await mkdir(dataDir, { recursive: true });

  SQL = await initSqlJs({
    locateFile: (file) =>
      path.join(__dirname, 'node_modules', 'sql.js', 'dist', file),
  });

  if (existsSync(dbPath)) {
    const fileBuffer = await readFile(dbPath);
    db = new SQL.Database(new Uint8Array(fileBuffer));
  } else {
    db = new SQL.Database();
  }

  db.run(`
    CREATE TABLE IF NOT EXISTS checkins (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      participantId TEXT NOT NULL,
      eventId TEXT NOT NULL,
      checkInTime TEXT NOT NULL,
      queuedAt TEXT NOT NULL,
      syncedAt TEXT NOT NULL
    )
  `);

  const row = db.exec('SELECT COUNT(*) AS count FROM checkins');
  const count = row[0]?.values?.[0]?.[0] ?? 0;

  if (!existsSync(dbPath)) {
    await saveDatabase();
  }

  return count;
}

async function getCheckins() {
  const result = db.exec(
    'SELECT participantId, eventId, checkInTime, queuedAt, syncedAt FROM checkins ORDER BY id DESC',
  );

  if (!result.length) {
    return [];
  }

  const columns = result[0].columns;
  return result[0].values.map((row) =>
    Object.fromEntries(row.map((value, index) => [columns[index], value])),
  );
}

app.use(cors());
app.use(express.json());

app.get('/api/health', async (req, res) => {
  await dbReady;
  const row = db.exec('SELECT COUNT(*) AS count FROM checkins');
  const count = row[0]?.values?.[0]?.[0] ?? 0;
  res.json({ ok: true, checkinCount: count, database: 'sqlite' });
});

app.post('/api/checkins', async (req, res) => {
  await dbReady;
  const { participantId, eventId, checkInTime, queuedAt } = req.body ?? {};
  const normalizedParticipantId = typeof participantId === 'string' ? participantId.trim() : '';
  const normalizedEventId = typeof eventId === 'string' ? eventId.trim() : '';

  if (!normalizedParticipantId || !normalizedEventId) {
    return res.status(400).json({ error: 'participantId and eventId are required' });
  }

  const syncedAt = new Date().toISOString();
  const record = {
    participantId: normalizedParticipantId,
    eventId: normalizedEventId,
    checkInTime: checkInTime ?? new Date().toISOString(),
    queuedAt: queuedAt ?? new Date().toISOString(),
    syncedAt,
  };

  try {
    const statement = db.prepare(
      `INSERT INTO checkins (participantId, eventId, checkInTime, queuedAt, syncedAt)
       VALUES (?, ?, ?, ?, ?)`,
    );
    statement.run([
      record.participantId,
      record.eventId,
      record.checkInTime,
      record.queuedAt,
      record.syncedAt,
    ]);
    statement.free();
    await saveDatabase();
    res.status(201).json({ ok: true, record });
  } catch (error) {
    console.error('Failed to store check-in:', error);
    res.status(500).json({ error: 'Failed to store check-in' });
  }
});

app.get('/api/checkins', async (req, res) => {
  await dbReady;
  res.json({ items: await getCheckins() });
});

dbReady = initializeDatabase();

dbReady
  .then((count) => {
    app.listen(port, () => {
      console.log(
        `Event Management API listening on port ${port} with ${count} stored check-ins`,
      );
    });
  })
  .catch((error) => {
    console.error('Failed to initialize SQLite database:', error);
    process.exitCode = 1;
  });