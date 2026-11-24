# Home screen for KOReader

**English** | [Українська](README.uk.md)

A PocketBook-style start screen for [KOReader](https://github.com/koreader/koreader). It shows the books you are
actually reading, not a file list.

<p align="center"><img src="screenshots/home.png" alt="Home screen" width="420"></p>

## Features

- **9 recent books** from the reading history:
  - top block: one large cover, plus one medium and two small covers on the right;
  - a tight row of five small covers below.
- **Bottom bar:** Library (file manager), History, Collections, Statistics (the calendar view of the *Reading
  statistics* plugin) and Settings.
- **Reading progress:** a thin bar at the bottom of each cover.
- **Status line:** clock and battery level.
- **Shows up automatically** at startup and/or after closing a book. Both can be turned off.
- **Gesture action** "Open home screen", which works in the file manager and inside a book.
- **Localized UI:** English, Russian and Ukrainian, following the language selected in KOReader. Other languages
  fall back to English.

## Installation

1. Download this repository (*Code → Download ZIP*) or clone it.
2. Copy the `homescreen.koplugin` folder into KOReader's `plugins` folder. If the downloaded folder has a different
   name (for example `homescreen.koplugin-main`), rename it to `homescreen.koplugin`.

   | Device     | Path                                  |
   |------------|---------------------------------------|
   | Kobo       | `.adds/koreader/plugins/`             |
   | Kindle     | `koreader/plugins/`                   |
   | PocketBook | `applications/koreader/plugins/`      |
   | Android    | `koreader/plugins/` (internal storage)|

3. Restart KOReader.

## Usage

- **Tap** a cover to open the book.
- **Long-press** a cover for more options: Open, Book information, Show in Library, Reload cover.
- **Tap or swipe down at the top of the screen** (top 1/8, even over a cover) to open the KOReader menu, as in the file manager and the reader.
- **Back** or **Library** closes the home screen and returns to the file manager.

### Settings

To change the settings, open the file manager menu, go to the main (☰) tab and choose **Home screen**:

| Option                         | Default |
|--------------------------------|---------|
| Show at startup                | on      |
| Show after closing a book      | on      |
| Show clock and battery         | on      |
| Show reading progress          | on      |
| Fill tiles with covers (crop)  | on (when off, the whole cover fits inside the tile) |
| Clear cover cache              | —       |

### Gesture

To open the home screen with a gesture, go to ⚙ → *Taps and gestures* → *Gesture manager*, pick a gesture and
assign the **Open home screen** action from the *General* section.

## Covers

When a book is shown for the first time, its title is displayed until its cover has been extracted. Covers are
extracted one by one in the background. If the *Cover browser* plugin already has a thumbnail for the book, that
thumbnail is shown right away.

Extracted covers are cached in `<KOReader data folder>/cache/homescreen/`, so later launches don't need to open the
books. Custom covers set in KOReader are respected. Use **Reload cover** (long-press) or **Clear cover cache** if a
cover looks outdated.

## Known limitations

- The screen is designed for touch devices. On devices without a touch screen it can only be closed with the Back
  button.
- If KOReader is set to *Start with: last file*, the home screen appears only after you close that book.

## Contributing

Bug reports, ideas and translations are welcome. To add a language, add a table to
[`homescreen_l10n.lua`](homescreen_l10n.lua) and a matching check in `currentLang()`.

## License

[AGPL-3.0](LICENSE), the same license as KOReader.
