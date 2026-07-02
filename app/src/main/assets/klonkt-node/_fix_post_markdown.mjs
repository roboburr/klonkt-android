// Converteert seed-posts die als markdown zijn opgeslagen naar HTML (de app
// rendert post-content als HTML). Slaat echte WYSIWYG-posts (die al HTML-block-
// tags hebben) over. Draaien vanuit de instance-map: node _fix_post_markdown.mjs
import 'dotenv/config';
import MarkdownService from './src/services/MarkdownService.js';
import db from './src/config/database.js';

const posts = db.prepare('SELECT id, title, content FROM posts').all();
let n = 0;
for (const p of posts) {
  const c = p.content || '';
  // Heeft het al HTML-blokstructuur? Dan is 't WYSIWYG-content -> overslaan.
  if (/<(p|ul|ol|h[1-6]|blockquote|div|br|figure)\b/i.test(c)) continue;
  const html = MarkdownService.render(c);
  db.prepare('UPDATE posts SET content = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(html, p.id);
  n++;
}
console.log(`Naar HTML geconverteerd: ${n} post(s).`);
db.close();
