# adhd - aarav, don't hesitate. doYourWork.

A simple Chrome extension that interrupts my visits to selected social media sites and opens a reflection note in Obsidian.

## reason
aarav was using social media too much and wanted to log his urges.
aarav also has exams so yeah he made this.
aarav also knows how to workaround this so kinda useless lmaoooo.
next station: blocking `chrome://extensions` so that i can't turn it off. LMAOOO

## Blocked sites

- X / Twitter (`x.com`, `twitter.com`)
- LinkedIn (`linkedin.com`)
- Instagram (`instagram.com`)

## Install

1. Clone or download this repository.
2. Open `chrome://extensions` in Chrome.
3. Turn on **Developer mode**.
4. Select **Load unpacked** and choose this project folder.

## Obsidian setup

The extension uses Obsidian's `obsidian://` URI to create a note in the `Obsidian.md` vault, inside the `adhd` folder. Make sure Obsidian is installed and that your vault has that name, or update the vault name and folder in `script.js`.

To change the blocked domains, edit the `blockedDomains` list in `background.js`.
