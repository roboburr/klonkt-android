// Klonkt demo-seed — vult een VERSE instance met een demo-artiest + posts.
// Idempotent: als er al een site is, doet 'ie niks.
// Draaien vanuit de demo-instance-map: node _klonkt_demo_seed.mjs
import 'dotenv/config';
import { randomUUID } from 'node:crypto';
import bcrypt from 'bcryptjs';
import db, { initializeDatabase } from './src/config/database.js';

initializeDatabase();

if (db.prepare('SELECT COUNT(*) AS n FROM sites').get().n > 0) {
  console.log('Er bestaat al een site — seed overgeslagen.');
  process.exit(0);
}

const userId = randomUUID();
const siteId = randomUUID();
const t = (d) => new Date(d).toISOString();

db.prepare(`INSERT INTO users (id, username, email, password_hash, role, bio, theme, palette)
  VALUES (?,?,?,?,?,?,?,?)`).run(
  userId, 'demo', 'demo@klonkt.com', bcrypt.hashSync('klonkt-demo-2026', 10), 'admin',
  'Demo-artiest op Klonkt.', 'dark', 'midnight');

db.prepare(`INSERT INTO sites
  (id, slug, title, description, tagline, owner_id, language, author, palette, accent,
   is_public, enable_audio_player, profile_enabled, profile_name, profile_bio, default_description)
  VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`).run(
  siteId, 'demo', 'Luna Vermeer',
  'Een Klonkt-demo — zo ziet je eigen, zelf-gehoste muzieksite eruit.',
  'Singer-songwriter · Utrecht', userId, 'nl', 'Luna Vermeer', 'midnight', '#e8b04b',
  1, 1, 1, 'Luna Vermeer', 'Singer-songwriter uit Utrecht. Dit is een live Klonkt-demo.',
  'De Klonkt-demosite van Luna Vermeer.');

db.prepare(`INSERT OR IGNORE INTO site_members (site_id, user_id, role) VALUES (?,?,?)`)
  .run(siteId, userId, 'owner');

const posts = [
  {
    slug: 'welkom',
    title: 'Welkom op mijn Klonkt',
    type: 'post',
    tags: 'welkom,klonkt',
    excerpt: 'Mijn eigen plek op internet — blog, muziek en updates, allemaal van mij.',
    when: '2026-05-20T10:00:00Z',
    content: `Hoi! Dit is mijn eigen muzieksite, gemaakt met **Klonkt**.

Geen algoritme, geen advertenties, geen platform dat ertussen zit — gewoon **mijn blog, mijn muziek en mijn publiek**, op mijn eigen domein.

> Dit is een demo zodat je kunt zien hoe een Klonkt-site eruitziet. Klik gerust rond.

Wat je hier vindt:

- Korte updates en langere verhalen
- Mijn nieuwe releases
- Foto's uit de studio

Veel luisterplezier. 🎶`,
  },
  {
    slug: 'nieuwe-single-golven',
    title: 'Nieuwe single: "Golven"',
    type: 'post',
    tags: 'release,single',
    excerpt: 'M’n nieuwe single staat online. Een rustig nummer over loslaten.',
    when: '2026-06-05T14:30:00Z',
    content: `Vandaag verschijnt mijn nieuwe single **"Golven"** — een rustig, ingetogen nummer over loslaten en opnieuw beginnen.

Opgenomen in één take, laat op de avond. Ik wilde dat het klónk zoals het voelde: kaal en eerlijk.

Beluister 'm hieronder:

https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC

Laat je weten wat je ervan vindt? Reacties zijn altijd welkom.`,
  },
  {
    slug: 'in-de-studio',
    title: 'In de studio',
    type: 'post',
    tags: 'studio,behind-the-scenes',
    excerpt: 'Een kijkje achter de schermen tijdens het opnemen van de nieuwe EP.',
    when: '2026-06-12T19:15:00Z',
    content: `Deze week begonnen met de opnames voor de nieuwe EP. Vijf nummers, één microfoon, veel koffie.

Het mooiste aan zelf je site beheren: ik kan dit soort dingen meteen delen, precies zoals ik wil — zonder dat een platform bepaalt wie het ziet.

Meer binnenkort. ✨`,
  },
];

const insPost = db.prepare(`INSERT INTO posts
  (id, site_id, slug, author_id, title, content, excerpt, status, type, tags, published_at, created_at, updated_at)
  VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`);
const insFts = db.prepare(`INSERT INTO posts_fts (content, title, author, post_id) VALUES (?,?,?,?)`);

for (const p of posts) {
  const id = randomUUID();
  const ts = t(p.when);
  insPost.run(id, siteId, p.slug, userId, p.title, p.content, p.excerpt, 'published', p.type, p.tags, ts, ts, ts);
  try { insFts.run(p.content, p.title, 'Luna Vermeer', id); } catch (e) { /* fts optioneel */ }
}

console.log(`Seed klaar: site "Luna Vermeer" + admin (demo / klonkt-demo-2026) + ${posts.length} posts.`);
db.close();
