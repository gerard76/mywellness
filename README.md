# Mywellness Strength Tracker

A local Rails app to track your progress on the Technogym machine circuit. It syncs workout data from your mywellness account and visualises your 1-rep max (Rm1) progression per machine over time.

## Features

- Dashboard with interactive Chart.js progress chart, filterable by muscle group
- Automatic sync from mywellness.com — generates a fresh export and imports it
- Manual JSON upload (from a mywellness data export)
- Named machine mappings with muscle group labels
- Tracks best Rm1 per machine per day

## Setup

Requires Ruby 3.x and Bundler.

```bash
git clone https://github.com/yourname/mywellness.git
cd mywellness
bin/setup
bin/rails server
```

Then open http://localhost:3000

## Configuration

Go to **Settings** and enter your mywellness credentials:
- **Username** — your mywellness email
- **Password** — your mywellness password
- **Club slug** — the gym identifier in the mywellness URL (e.g. `vouershof`)

Click **↓ Sync from mywellness** on the dashboard to fetch your latest workout data.

## Data

All data is stored locally in SQLite (`storage/development.sqlite3`). Nothing is sent anywhere except directly to `v1.mywellness.com` when syncing.

The database is excluded from git — your workout data stays on your machine.