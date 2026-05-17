# EzHistory

A native macOS menu-bar app that indexes **all your browser profiles** — Chrome, Edge, Brave, Arc, Vivaldi, Opera, Chromium, Firefox, and Safari — and lets you search history, bookmarks, downloads, logins, and autofill data from a single Spotlight-style window.

<p align="center">
  <a href="https://github.com/stakksoftware/ezhistory/releases/latest/download/EzHistory-v1.1.0-macOS-universal.zip">
    <img src="https://img.shields.io/badge/Download_EzHistory-v1.1.0-blue?style=for-the-badge&logo=apple&logoColor=white" alt="Download EzHistory" height="48">
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

This installs the app **and** the `ezhistory` CLI command.

## Updating

**In-app:** A banner appears at the top of the search window when a new version is available. Click "Update Now" to update automatically.

**Menu bar:** Click the menu bar icon → "Update to vX.X.X" when an update is available.

**CLI:**

```bash
ezhistory update
```

## The Problem

When you have dozens of browser profiles across multiple browsers, finding which profile you visited a site in, signed up for a service with, or downloaded a file from becomes impossible. EzHistory solves this by indexing every profile across every browser and showing you exactly which profiles touched any URL.

## Supported Browsers

| Browser | Format | Auto-detected |
|---------|--------|:---:|
| Google Chrome | Chromium | ✅ |
| Microsoft Edge | Chromium | ✅ |
| Brave | Chromium | ✅ |
| Arc | Chromium | ✅ |
| Vivaldi | Chromium | ✅ |
| Opera | Chromium | ✅ |
| Chromium | Chromium | ✅ |
| Firefox | Mozilla | ✅ |
| Safari | Apple | ⚙️ (requires Full Disk Access) |

Safari indexing requires **Full Disk Access** — enable it in Settings > Browsers > Safari toggle, then grant access in System Settings > Privacy & Security > Full Disk Access.

## Features

- **Multi-browser search** across Chrome, Edge, Brave, Arc, Vivaldi, Opera, Chromium, Firefox, and Safari
- **Unified search** across all profiles (history, bookmarks, downloads, logins, autofill)
- **Profile attribution** — see exactly which browser/profile visited a URL, with visit counts and dates
- **Browser filtering** — filter results by specific browsers
- **Spotlight-style UI** — global hotkey `⌘⇧H` brings up a floating search panel
- **One-click open** — click any result to open it in the correct browser and profile
- **Filter by type** — filter results by history, bookmarks, downloads, logins, or autofill
- **Filter by profile** — narrow results to specific profiles
- **Time filters** — today, 7 days, 30 days, 1 year, all time
- **Auto-update** — in-app banner + `ezhistory update` CLI command
- **Context menus** — copy URL, open in profile, reveal downloads in Finder
- **Incremental indexing** — only re-indexes changed data
- **FSEvents watching** — near-real-time updates when browser data changes
- **Launch at login** — optional via Settings
- **Favicon caching** — fetches and caches site icons

## CLI Usage

```bash
ezhistory          # Open EzHistory
ezhistory update   # Update to latest version
ezhistory version  # Show installed version
ezhistory help     # Show help
```

## Build from Source

If you prefer to build manually:

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
sudo rm -f /usr/local/bin/ezhistory
```

## How It Works

1. **Scans** for all installed browsers and their profiles:
   - Chromium-based: `~/Library/Application Support/<browser>/` — looks for `Profile *` and `Default` directories
   - Firefox: `~/Library/Application Support/Firefox/Profiles/` — parses `profiles.ini` for profile names
   - Safari: `~/Library/Safari/` — requires Full Disk Access
2. **Copies** each browser's SQLite databases to a temp directory (browsers hold write locks on originals)
3. **Reads** History, Bookmarks, Login Data, and Autofill data from each profile
4. **Indexes** everything into a unified SQLite database with FTS5 full-text search at `~/Library/Application Support/ezhistory/index.db`
5. **Searches** use FTS5 `MATCH` queries for sub-50ms response times across millions of rows
6. **Opens URLs** in the originating browser and profile

## Data Sources

### Chromium Browsers (Chrome, Edge, Brave, Arc, Vivaldi, Opera, Chromium)

| Source | File | Data Indexed |
|--------|------|-------------|
| History | `History` (SQLite) | URLs, titles, visit counts, last visit time |
| Bookmarks | `Bookmarks` (JSON) | URLs, titles, folder paths |
| Downloads | `History` (SQLite) | Source URLs, filenames, file paths, sizes |
| Logins | `Login Data` (SQLite) | Site URLs, usernames (passwords stay encrypted) |
| Autofill | `Web Data` (SQLite) | Emails, addresses, phone numbers |

### Firefox

| Source | File | Data Indexed |
|--------|------|-------------|
| History | `places.sqlite` | URLs, titles, visit counts |
| Bookmarks | `places.sqlite` | URLs, titles |
| Logins | `logins.json` | Site URLs, encrypted usernames |
| Autofill | `formhistory.sqlite` | Form field names and values |

### Safari

| Source | File | Data Indexed |
|--------|------|-------------|
| History | `History.db` (SQLite) | URLs, titles, visit counts |
| Bookmarks | `Bookmarks.plist` | URLs, titles |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⇧H` | Toggle search window (customizable) |
| `↑` / `↓` | Navigate results |
| `Return` | Open selected result in its browser profile |
| `Escape` | Close search window |
| `⌘,` | Open Settings |
