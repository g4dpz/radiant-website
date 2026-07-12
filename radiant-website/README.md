# RADIANT Website & Documentation

Project website, grant applications, EMF materials, and documentation for the RADIANT project.

**Live site:** https://radiant.amsat-uk.org

**Code repository:** https://github.com/g4dpz/cislunar_proposal

## Structure

```
website/         — Deno/Oak website (radiant.amsat-uk.org)
docs/            — Grant applications, architecture docs, EMF materials
deploy/          — Website deployment scripts (Apache, systemd)
```

## Deployment

```bash
bash deploy/package.sh
# Upload and extract on server
sudo bash deploy/deploy.sh
```
