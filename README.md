# EzHistory

A native macOS menu-bar app that indexes **all your Chrome profiles** and lets you search history, bookmarks, downloads, logins, and autofill data from a single Spotlight-style window.

<p align="center">
  <a href="https://github.com/stakksoftware/ezhistory/releases/latest/download/EzHistory-v1.0.0-macOS-universal.zip">
    <img src="https://img.shields.io/badge/Download_EzHistory-v1.0.0-blue?style=for-the-badge&logo=apple&logoColor=white" alt="Download EzHistory" height="48">
  </a>
</p>

<p align="center">
  <b>macOS 13+ &nbsp;·&nbsp; Apple Silicon & Intel &nbsp;·&nbsp; No Xcode needed &nbsp;·&nbsp; 3.5 MB</b><br>
  Download the zip → unzip → drag <code>EzHistory.app</code> to Applications.<br>
  <b>First launch:</b> Right-click the app → <b>Open</b> → click <b>Open</b> in the dialog.<br>
  Press <code>⌘⇧H</code> to search.
</p>

---

Or install from your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/stakksoftware/ezhistory/main/install.sh | bash
```

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

## Build from Source

If you prefer to build manually instead of using the one-liner:

```bash
git clone https://github.com/stakksoftware/ezhistory.git
cd ezhistory
./build-app.sh
cp -r .build/release/EzHistory.app /Applications/
open /Applications/EzHistory.app
```

## Uninstall

```bash
rm -rf /Applications/EzHistory.app
rm -rf ~/Library/Application\ Support/ezhistory
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
