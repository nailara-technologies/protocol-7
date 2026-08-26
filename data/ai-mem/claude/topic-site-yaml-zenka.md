---
name: site-yaml zenka + job workflow
description: planned network utility zenka for structured site scraping + job application automation pipeline
type: project
originSessionId: 34ca9c97-628c-46af-82f3-d04a171ae8f0
---
## site-yaml zenka

Utility zenka that fetches URLs and returns clean structured YAML — no HTML.
Uses internal list of regex/template patterns per domain/content-type to extract
categorized content blocks only.

**Why:** Generic scraping primitive needed for recurring task types: job offers,
podcast/video discovery, music mix discovery. LLM sub-tasks need clean structured
input, not raw HTML.

**How to apply:** Design as on-demand zenka (start.on-demand=1). Commands:
- `site-yaml.fetch url=<url>` — fetch + extract using matching template
- `site-yaml.list-templates` — show known domain patterns
- `site-yaml.add-template` — register new regex extraction template

Output: YAML with categorized content blocks. Schema per template type.

**Known use cases:**
- stepstone.de — job offer extraction (title, company, location, salary, description, url)
- house-mixes.com / similar — psytrance/music mix discovery (title, artist, date, tags, url)
- YouTube/podcast channels — new episode discovery (title, pub_date, duration, url, description)

## site-auth zenka (second, later)

Manages site authorizations/sessions for scrapers that require login.
site-yaml delegates auth to site-auth when needed.

## job search automation workflow

Full pipeline built on site-yaml + task tree + LLM subtasks:

1. **fetch** — site-yaml fetches stepstone.de (or similar) job listings as YAML
2. **dedup** — filter against exclusion list (already-seen job IDs / URLs)
3. **categorize** — LLM subtask assigns category + value score per offer
4. **track** — store in jobtracker (existing HTML/JS tool that generates CSV/PDF reports)
5. **apply** — semi-automate application sending (user approval gate before send)
6. **monitor** — watch email replies (Gmail zenka integration), update tracker status
7. **report** — at agreed date, jobtracker generates report (CSV/PDF), system sends it,
   user gets completion summary

**jobtracker:** existing HTML/JS tool, already generates correct formats (CSV, PDF)
for job center submission.

**How to apply:** When implementing job workflow tasks, the pipeline is:
site-yaml → dedup task → LLM categorize subtask → jobtracker → email monitor → report.
Keep generic: site-yaml and the task tree structure should be reusable for any
content-discovery workflow (podcasts, music, news).

#,,..,,,.,.,,,.,,,...,..,,.,,,,.,,...,.,,,..,,..,,...,..,,...,,,.,,,,,,,,,...,
#2DXGKKMIUH7QH2MTUXWIFPOAVQPYC2MKCFUCB2BLNA7TFUAPSOJXOLRXD4HGZVQUEPNMQENXAUOUE
#\\\|GLQAXNHIPAFKFGOENQ6N573YOGC4U7IM7RRMEEHINDNMBLIARMU \ / AMOS7 \ YOURUM ::
#\[7]GJP2BEEUTJBOV3YNQBO2QN6YGKW7MLOGJWV2NWGFHO2LVA5GVWDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
