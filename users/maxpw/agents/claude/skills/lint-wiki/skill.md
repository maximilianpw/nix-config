---
name: lint-wiki
description: Lint the 200-WIKI knowledge base in the Obsidian vault. Checks for broken links, orphan articles, frontmatter consistency, and suggests missing articles. Use when the user says "lint wiki", "check wiki health", or "wiki health check".
---

# Lint Wiki

Run a health check on the LLM knowledge base at `~/Documents/obsidian vault/200-WIKI/`.

## Steps

### 1. Broken Links
Find all unresolved wikilinks originating from wiki articles:
```bash
obsidian unresolved verbose format=json
```
Filter to only links originating from `200-WIKI/` files. For each broken link, determine if it's a typo (fix it) or a missing article (suggest creating it).

### 2. Orphan Articles
Find wiki articles with zero incoming backlinks:
```bash
for f in $(obsidian files folder="200-WIKI/topics"); do
  count=$(obsidian backlinks path="$f" total)
  if [ "$count" = "0" ]; then echo "ORPHAN: $f"; fi
done
```
For each orphan, find the most related existing article and add a link to it.

### 3. Frontmatter Consistency
Every wiki article must have these frontmatter fields: `type`, `status`, `topic`, `date`, `tags`. Check all articles:
```bash
for f in $(obsidian files folder="200-WIKI/topics"); do
  props=$(obsidian properties path="$f" format=yaml)
  # Check for missing type, status, topic, date
done
```
Fix any missing fields using `obsidian property:set`.

### 4. Suggested New Articles
Look for terms that appear frequently across articles (in wikilinks or prose) but don't have their own page. Suggest 3-5 new articles that would strengthen the wiki.

### 5. Article Count
Count total articles and per-topic:
```bash
obsidian files folder="200-WIKI/topics" total
obsidian files folder="200-WIKI/topics/effect-ts" total
obsidian files folder="200-WIKI/topics/ev-charging" total
obsidian files folder="200-WIKI/topics/software-architecture" total
```

## Output Format

Present results as a structured report:

```
## Wiki Lint Report — {date}

**{N} articles** across {M} topics

### Broken Links
- {status} each one

### Orphan Articles
- {status} each one

### Frontmatter Issues
- {list or "All clean"}

### Suggested New Articles
- {3-5 suggestions with rationale}

### Stats
- effect-ts: {n} articles
- ev-charging: {n} articles
- software-architecture: {n} articles
```

Fix broken links and orphans automatically. Only report frontmatter issues and suggestions — don't create suggested articles without user confirmation.
