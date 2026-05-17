# EzHistory

A native macOS menu-bar app that indexes **all your Chrome profiles** and lets you search history, bookmarks, downloads, logins, and autofill data from a single Spotlight-style window.

## The Problem

When you have dozens of Chrome profiles, finding which profile you visited a site in, signed up for a service with, or downloaded a file from becomes impossible. EzHistory solves this by indexing every profile and showing you exactly which profiles touched any URL.

## Features

- **Unified search** across all Chrome profiles (history, bookmarks, downloads, logins, autofill)
- **Profile attribution** — see exactly which profiles visited a URL, with visit counts and dates
- **Spotlight-style UI** — global hotkey `⌘⇧H` brings up a floating search panel
- **One-click open** — click any result to open it in the correct Chrome profile
- **Filter by type** — filter results by history, bookmarks, downloads, logins, or autofill
- **Filter by profile** — narrow results to specific profiles
- **Time filters** — today, 7 days, 30 days, 1 year, all time
- **Context menus** — copy URL, open in profile, reveal downloads in Finder
- **Incremental indexing** — only re-indexes changed data
- **FSEvents watching** — near-real-time updates when Chrome data changes
- **Launch at login** — optional via Settings
- **Favicon caching** — fetches and caches site icons

## Requirements

- macOS 13 (Ventura) or later
- Google Chrome installed
- Swift 5.9+ / Xcode 15+

## Build & Run

```bash
cd ezhistory

# Debug build + run
swift build && .build/debug/EzHistory

# Release build + app bundle
./build-app.sh
open .build/release/EzHistory.app

# Install to Applications
cp -r .build/release/EzHistory.app /Applications/
```

## How It Works

1. **Scans** `~/Library/Application Support/Google/Chrome/` for all `Profile *` and `Default` directories
2. **Copies** each profile's SQLite databases to a temp directory (Chrome holds write locks on originals)
3. **Reads** History, Bookmarks (JSON), Login Data, and Web Data from each profile
4. **Indexes** everything into a unified SQLite database with FTS5 full-text search at `~/Library/Application Support/ezhistory/index.db`
5. **Searches** use FTS5 `MATCH` queries for sub-50ms response times across millions of rows
6. **Opens URLs** in the originating Chrome profile using `--profile-directory` flag

## Data Sources

| Source | File | Data Indexed |
|--------|------|-------------|
| History | `History` (SQLite) | URLs, titles, visit counts, last visit time |
| Bookmarks | `Bookmarks` (JSON) | URLs, titles, folder paths |
| Downloads | `History` (SQLite) | Source URLs, filenames, file paths, sizes |
| Logins | `Login Data` (SQLite) | Site URLs, usernames (passwords stay encrypted) |
| Autofill | `Web Data` (SQLite) | Emails, addresses, phone numbers |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⇧H` | Toggle search window (customizable) |
| `↑` / `↓` | Navigate results |
| `Return` | Open selected result in its Chrome profile |
| `Escape` | Close search window |
| `⌘,` | Open Settings |
