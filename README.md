# RADIANT Website

Standalone home of the RADIANT (Radio Amateur DTN Infrastructure for Networked Transmission) project website at <https://radiant.amsat-uk.org>.
Deno + Oak + Handlebars + SQLite. Extracted from `g4dpz/cislunar_proposal`.

## Layout

```
website/   Deno application (main.ts, routes/, views/, content/, public/, tests/)
docs/      Documents the site renders at runtime (read as ../docs from website/)
deploy/    systemd unit, Apache config, setup/package/deploy scripts
scripts/   sync-docs.sh: refresh docs/ from a cislunar_proposal checkout
```

`website/` and `docs/` must stay siblings: the routes read `../docs/<phase>/requirements.md` and `../docs/<architecture doc>`.

## Develop

```bash
cd website
cp .env.example .env   # optional SMTP settings; never commit .env
deno task dev          # http://localhost:8000
deno task build        # deno check main.ts
deno task test
```

## Docs

`docs/` contains only what the site reads: the five phase `requirements.md` files, `LTP-KISS-ARCHITECTURE.md`, `DTN-CALLSIGN-EID-CONFIGURATION.md`, and spec requirements under `docs/specs/`.
Refresh them with:

```bash
scripts/sync-docs.sh ../cislunar_proposal   # or set CISLUNAR_PROPOSAL
```

The list of copied files is the `DOCS` array at the top of that script.

## Deploy

See [deploy/README.md](deploy/README.md), including migration from the old `cislunar_proposal` deployment. `bash deploy/package.sh` builds `dist/radiant-website-<timestamp>.zip`.

## Amateur radio note

Site content is public and unencrypted, in line with amateur service rules.
