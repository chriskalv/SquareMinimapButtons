# Square Minimap Buttons

Port of the *Square Minimap Buttons* module of [ProjectAzilroka](https://github.com/Azilroka/ProjectAzilroka) by Azilroka to **WoW Forever** (Interface 16001), with Azilroka's permission. It collects the minimap buttons of other addons into a bar next to the minimap, skins them square, and moves Blizzard's mail, tracking, calendar and queue buttons into the bar.

The addon itself is the folder [`SquareMinimapButtons/`](SquareMinimapButtons/); its [README](SquareMinimapButtons/README.md) describes every option, the differences from ProjectAzilroka, the known limits and the client checklist. The [CHANGELOG](SquareMinimapButtons/CHANGELOG.md) lists the changes per version.

## Install

1. Download `SquareMinimapButtons-<version>-forever.zip` from the [Releases](https://github.com/chriskalv/SquareMinimapButtons/releases) page (until the first release, copy the folder `SquareMinimapButtons` of this repository instead).
2. Extract it into the `Interface\AddOns` folder of your WoW installation, so that `Interface\AddOns\SquareMinimapButtons\SquareMinimapButtons.toc` exists.
3. Restart the game and enable **Square Minimap Buttons** in the addon list. `/smb` opens the options (also `/squareminimap` and `/squareminimapbuttons`).

ProjectAzilroka and this addon must not run at the same time; the addon stays inactive while ProjectAzilroka's Square Minimap Buttons module is enabled and says so in the chat.

## Development

The Lua tests run without the game client, in [fengari](https://github.com/fengari-lua/fengari) (Lua in JavaScript) with stubs of the WoW API. With Node.js 22 in the repository root:

```
npm install
npm test
npm run release:smb
```

`npm test` runs the Lua tests with `tools/addon_test.mjs` (TOC and XML files resolved, every Lua file checked as Lua 5.1, then the tests in `tests/SquareMinimapButtons/`) and the tests of the release script in `tests/release.test.mjs`. `npm run release:smb` writes `dist/SquareMinimapButtons-<version>-forever.zip` and `dist/release.json` with `tools/release.mjs`: the version from the TOC, the addon folder as the only root of the zip, no development files; the release.json follows the format of the BigWigs packager (name, version, file name of the zip, flavor `forever` and the interface number from the TOC line `## Interface-Forever:`, or from `## Interface:` when that line is missing; without either the script stops with an error). Upload both files together as the assets of the GitHub release: since 2026-11-07 the owner wants the release asset to keep the name `…-<version>-forever.zip` and the matching release.json next to it, so that addon managers keep detecting updates reliably.

Until 2026-11-07 the addon lived in the repository ZippyAddOns next to ZippyMedia; the history of its files was carried over.

## License

See [`SquareMinimapButtons/LICENSE.txt`](SquareMinimapButtons/LICENSE.txt): the ProjectAzilroka license for the parts taken from the original (used with Azilroka's permission) and the licenses of the embedded libraries (Ace3, BSD).
