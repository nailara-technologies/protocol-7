# Static Assets Directory

This directory contains static web assets served by httpd/httpsd.

## Structure

```
/var/httpd/static/
├── gfx/
│   └── logos/          # Logos and branding images
├── css/                # Stylesheets
├── js/                 # JavaScript files
└── fonts/              # Web fonts
```

## Web Path Mapping

- Repository: `/var/httpd/static/*`
- Web URL: `/static/*`

Example:
- File: `/var/httpd/static/gfx/logos/nailara_logo.trans-dark.png`
- URL: `http://example.com/static/gfx/logos/nailara_logo.trans-dark.png`

## Asset Sources

Static assets are **copied** from repository data/ during setup to avoid serving directly from data/:

- `data/gfx/logos/` → `var/httpd/static/gfx/logos/`

This maintains separation:
- **data/** - Source storage (in repository)
- **var/httpd/** - Runtime web content (populated from data/)

## Setup

Run the setup script to populate static assets:

```bash
./scripts/setup-httpd-static-assets.sh
```

## httpd Configuration

The httpd/httpsd zenka must be configured to serve `/static/*` paths from this directory.

In `cfg/zenki/httpd/zenka.v7`:
```
httpd.static_dir = /var/httpd/static
```

Or handle in `httpd.http_get` to check for `/static/` prefix and serve directly.

## Notes

- Do NOT commit large binary assets to git
- Assets are regenerated from data/ during deployment
- Use .gitignore to exclude generated assets if needed
- Keep source files in data/, serve from var/httpd/static/
