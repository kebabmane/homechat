# Operations Guide

This guide covers running HomeChat in offline environments, backups, and upgrades.

## Backups

- Database (SQLite):
  - Hot copy (Rails handles write lock safely):
    - `cp db/development.sqlite3 backups/homechat-$(date +%F).sqlite3`
- Active Storage (if enabled later):
  - Copy the storage directory:
    - `rsync -a --delete storage/ backups/storage/`
- Verify by opening the copied DB: `sqlite3 backups/homechat-*.sqlite3 '.tables'`.

## Restore

- Stop the app, then replace files:
  - `cp backups/homechat-YYYY-MM-DD.sqlite3 db/development.sqlite3`
  - `rsync -a backups/storage/ storage/`
- Start the app: `bin/dev` or your process manager.

## Upgrades (Offline)

1. Build image or bundle gems on a connected machine.
2. Transfer the image (or vendor/bundle) to the offline host.
3. Run migrations:
   - `bin/rails db:migrate`
4. Restart app.

## Environment Tips

- First user to sign up becomes admin.
- Lock down signups in Admin → Server Settings.
- Use DB‑backed ActionCable (Solid Cable) in production for zero external deps.

## PWA & Offline Caching

- Enable/disable PWA in Admin → Server Settings.
- Theme and background colors and short name can be customized.
- Icons are served locally from `/icon.png` and `/icon.svg`.

## Logs & Health

- Rails logs: `log/*.log` (rotate with your process manager).
- Health endpoint: `/up` (200 OK when app boots).

