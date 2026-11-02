# Deployment Guide — RADIANT Website

## Prerequisites

- Linux server (Debian/Ubuntu)
- Apache 2.4+ with `mod_proxy`, `mod_proxy_http`, `mod_ssl`, `mod_rewrite`, `mod_headers`
- Deno runtime installed (`curl -fsSL https://deno.land/install.sh | sh`)
- Certbot for Let's Encrypt TLS certificates

## 1. Install Deno

```bash
curl -fsSL https://deno.land/install.sh | sh
sudo ln -s ~/.deno/bin/deno /usr/bin/deno
```

## 2. Deploy the application

```bash
sudo mkdir -p /opt/radiant/data
sudo git clone https://github.com/g4dpz/radiant-website.git /opt/radiant/repo
sudo ln -s /opt/radiant/repo/website /opt/radiant/website
sudo chown -R www-data:www-data /opt/radiant
```

## 3. Install the systemd service

```bash
sudo cp /opt/radiant/repo/deploy/radiant.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable radiant
sudo systemctl start radiant
```

Check status:
```bash
sudo systemctl status radiant
sudo journalctl -u radiant -f
```

## 4. Configure Apache

Enable required modules:
```bash
sudo a2enmod proxy proxy_http ssl rewrite headers
```

Install the site config:
```bash
sudo cp /opt/radiant/repo/deploy/apache-radiant.conf /etc/apache2/sites-available/radiant.conf
sudo a2ensite radiant
```

## 5. Set up TLS with Let's Encrypt

```bash
sudo certbot certonly --webroot -w /var/www/html -d radiant.amsat-uk.org
```

Or if Apache is already running:
```bash
sudo certbot --apache -d radiant.amsat-uk.org
```

## 6. Restart Apache

```bash
sudo systemctl restart apache2
```

## 7. Verify

```bash
curl -I https://radiant.amsat-uk.org
```

## Updating

```bash
cd /opt/radiant/repo
sudo git pull
sudo systemctl restart radiant
```

## Migrating an existing server from cislunar_proposal

Earlier deployments cloned `g4dpz/cislunar_proposal` to `/opt/radiant/repo`.
The site now lives in its own repo, `g4dpz/radiant-website`, with `website/`
and `docs/` as siblings, so `/opt/radiant/website -> /opt/radiant/repo/website`
and `radiant.service` (`WorkingDirectory=/opt/radiant/website`) stay unchanged.
Only the clone URL changes. The SQLite database lives in `/opt/radiant/data`
and is not touched.

```bash
sudo systemctl stop radiant
# Keep the old checkout until the new site is verified
sudo mv /opt/radiant/repo /opt/radiant/repo.cislunar_proposal.bak
sudo git clone https://github.com/g4dpz/radiant-website.git /opt/radiant/repo
# Re-point the symlink (already correct path, recreate to be safe)
sudo ln -sfn /opt/radiant/repo/website /opt/radiant/website
# Carry over local config, if any (never committed)
[ -f /opt/radiant/repo.cislunar_proposal.bak/website/.env ] && \
  sudo cp /opt/radiant/repo.cislunar_proposal.bak/website/.env /opt/radiant/repo/website/.env
sudo chown -R www-data:www-data /opt/radiant
sudo cp /opt/radiant/repo/deploy/radiant.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start radiant
curl -I https://radiant.amsat-uk.org
```

Once verified, remove `/opt/radiant/repo.cislunar_proposal.bak`.
Alternatively, in place: `git -C /opt/radiant/repo remote set-url origin
https://github.com/g4dpz/radiant-website.git` does not work because the
histories are unrelated; use the clone steps above.

## Updating docs

The site renders documents from `docs/` (phase requirements, two architecture
docs, spec requirements). Refresh them from a `cislunar_proposal` checkout with
`scripts/sync-docs.sh [path]`, then commit.

## Default Admin Login

- Email: `admin@radiant.radio`
- Password: `admin123!`

**Change this immediately after first login.**

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8000` | HTTP port for the Deno server |
| `DB_PATH` | `./data/radiant.db` | Path to SQLite database file |
| `DENO_DIR` | system default | Deno cache directory |
