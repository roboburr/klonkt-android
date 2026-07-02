// Maakt (idempotent) een "kijk gerust rond"-post op de primaire site, die het
// read-only gast-account vermeldt. Draaien vanuit de instance-map: node _demo_info_post.mjs
import 'dotenv/config';
import { randomUUID } from 'node:crypto';
import db, { initializeDatabase } from './src/config/database.js';

initializeDatabase();

const site = db.prepare('SELECT * FROM sites ORDER BY created_at ASC LIMIT 1').get();
if (!site) { console.log('Geen site — overgeslagen.'); process.exit(0); }

const slug = 'kijk-gerust-rond';
if (db.prepare('SELECT 1 FROM posts WHERE site_id = ? AND slug = ?').get(site.id, slug)) {
  console.log('Info-post bestaat al — overgeslagen.');
  process.exit(0);
}

const author =
  db.prepare('SELECT id FROM users WHERE id = ?').get(site.owner_id) ||
  db.prepare('SELECT id FROM users ORDER BY created_at ASC LIMIT 1').get();

const id = randomUUID();
const now = new Date().toISOString();
const title = 'Even rondkijken? Log in als gast';
const excerpt = 'Dit is een live demo — log in met het gast-account om alles te bekijken.';
const content = [
  'Dit is een **live demo** van Klonkt. Kijk gerust rond!',
  '',
  'Wil je zien hoe het er ingelogd uitziet? Log in met het gast-account:',
  '',
  '- **Gebruiker:** kijker',
  '- **Wachtwoord:** kijken2026',
  '',
  'Dit account is **alleen-lezen**: je kunt alles bekijken, maar niets wijzigen.',
].join('\n');

db.prepare(`
  INSERT INTO posts (id, site_id, slug, author_id, title, content, excerpt, status, type, tags, published_at, created_at, updated_at)
  VALUES (?, ?, ?, ?, ?, ?, ?, 'published', 'post', 'demo', ?, ?, ?)
`).run(id, site.id, slug, author.id, title, content, excerpt, now, now, now);

try {
  db.prepare('INSERT INTO posts_fts (content, title, author, post_id) VALUES (?, ?, ?, ?)')
    .run(content, title, site.title, id);
} catch { /* fts optioneel */ }

console.log(`Info-post aangemaakt op site "${site.slug}".`);
db.close();
