# Viewer — design

Date: 2026-11-05

## Goal

A free iPhone + iPad app that opens almost any file, and above all shows HTML **with JavaScript
running** — which the Files app's preview (Quick Look) does not do. Published on the App Store.

Success: share or browse to an HTML file, a website folder or a zip of one, and it runs as it would
in Safari, CSS/JS/images included; every other common file type opens in a sensible viewer.

## Platform

- iOS/iPadOS 17.0+, SwiftUI, one universal app. Bundle ID `com.adriansmith.viewer`.
- Home-screen name **Viewer**; App Store name chosen at submission (bare "Viewer" is likely taken),
  e.g. "Viewer – HTML & File Viewer".
- Icon: `assets/icon-options/Document Search Icon.png` (1254 px, opaque) scaled to 1024.
- Dependencies: ZIPFoundation (Swift package, MIT) for zips; bundled highlight.js (BSD-3) and
  marked (MIT) for code colouring and Markdown. Licences listed in an in-app Acknowledgements screen.

## Getting files in

1. **Browse**: system document picker for files *or folders* (iCloud Drive, On My iPhone, USB,
   other providers).
2. **Share into Viewer**: `CFBundleDocumentTypes` for `public.item` (plus `public.folder`) with
   `LSSupportsOpeningDocumentsInPlace = YES`, so Viewer shows in the share sheet / "Open in" for
   any file from Files, Mail, Messages, AirDrop. Copies that arrive in `Documents/Inbox` are moved
   to `Application Support/Imported/`.
3. **Recents & favourites** (home screen): last 50 opened items, kept as security-scoped bookmarks
   so they reopen in place; pin/unpin; swipe to remove; missing files shown greyed with "Not found".

No "share out" of the original file (not requested). Exception: HTML can be saved/printed as PDF
(power tools, below), which uses the share sheet for the PDF only.

## Choosing a viewer (`FileKind`)

Decided from the URL's type (UTType) first, then extension, then content sniffing of the first 4 KB:

| Kind | Types | Viewer |
|---|---|---|
| html | .html .htm .xhtml .svg | WebViewer (WKWebView, JS on) |
| folder | directories | FolderBrowser (opens `index.html` if present via a banner) |
| zip | .zip | extracted to `Caches/Extracted/<hash>/` → FolderBrowser |
| markdown | .md .markdown | Markdown rendered (marked) in WKWebView, code blocks coloured |
| json | .json, `application/json` | native collapsible tree; > 10 MB → code view |
| csv | .csv .tsv | native scrollable grid with header row; > 50 000 rows → first 50 000 + notice |
| code | ~190 languages by extension (js, css, swift, py, c, xml, yaml, sh, …) | CodeViewer (highlight.js); > 2 MB → plain text |
| text | .txt and anything that decodes as UTF-8/UTF-16 | plain text, monospaced, wrap toggle |
| quicklook | PDF, images, Office, iWork, RTF, audio/video, USDZ | QLPreviewController |
| unknown | the rest | file info (name, size, type, dates) |

## HTML viewer

- `loadFileURL(_:allowingReadAccessTo:)` with read access to the opened root (the folder, the
  extracted zip, or the file's own directory when sandboxing allows it). A single HTML file shared
  on its own may not be able to see its sibling files; then a banner says "Images or styles
  missing? Open the whole folder or a zip."
- Navigation policy: `file:` links inside the root load in Viewer; top-level `http(s)`/`mailto`/
  `tel` navigations open in Safari/the system (Viewer is not a browser → age rating 4+). Web
  subresources (CDN scripts, fonts, images) are allowed.
- Power tools (toolbar menu): **View Source** (CodeViewer of the file), **Find in Page**
  (`UIFindInteraction`), **Console** (injected script forwards `console.*`, `window.onerror` and
  unhandled rejections to a sheet with level colours and a clear button), **Desktop/Mobile** toggle
  (content mode + user agent, reloads), **Save as PDF** (`createPDF` → share sheet),
  **Print** (`UIPrintInteractionController`), **Reload**.
- JS `alert/confirm/prompt` shown as native alerts. Full screen on scroll is not needed.

## Privacy & App Store

- No accounts, analytics, ads or tracking; no network use by Viewer itself (only what an opened
  page loads). Privacy label: Data Not Collected. `ITSAppUsesNonExemptEncryption = NO`.
- Free, category Productivity, age rating 4+.
- Support + privacy pages: GitHub Pages from the `gh-pages` branch of github.com/aksmith-git/Viewer
  → `https://aksmith-git.github.io/Viewer/` (support) and `/privacy.html`.
- Screenshots generated from the simulator (6.9" iPhone, 13" iPad); description and keywords written
  for the listing. App Store Connect record created by Adrian (guided), upload via `xcodebuild`.

## Testing

- XCTest unit tests: `FileKind` classification (extension, UTType, sniffing, size fallbacks),
  `RecentsStore` (add, dedupe, cap 50, pin, missing file), zip extraction (nested folders, unsafe
  `../` paths rejected), HTML navigation policy (inside root / outside root / http / mailto).
- Simulator run on iPhone and iPad with a sample set (site folder with JS, zip, md, json, csv,
  code, pdf, docx, image, video, unknown binary) — screenshots of each.
- Device run on Adrian's iPhone 12 mini and iPad Pro.

## Out of scope (v1)

Editing files, sharing the original file out, opening web URLs, a Mac-specific version (it still
runs on Apple Silicon Macs as an iPad app), cloud sync of recents.
