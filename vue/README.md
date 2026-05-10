# Boat Sim

Vue/Vite app for GC Racing setup math and notes for the MTI 482 with twin Mercury 1100s.

The app should stay honest about what it knows:

- Prop slip, fuel, time, and distance are explicit formulas.
- Weather and water notes are rough guidance.
- Future spacer and wind advice should be treated as estimates unless backed by logged sessions.
- Session logs should preserve raw inputs so CSV exports can be checked later.

## Local Development

Install dependencies:

```sh
npm install
```

Run the dev server:

```sh
npm run dev
```

Build locally:

```sh
npm run build
```

Preview a production build:

```sh
npm run preview
```

## GitHub Pages

`vite.config.js` reads `VITE_BASE_PATH` and defaults to `/`, so local development is unchanged.

For a GitHub Pages project site named `boatSim`, build with:

```sh
npm run build:pages
```

That script sets:

```sh
VITE_BASE_PATH=/boatSim/
```

If the repository or Pages path changes, update `build:pages` in `package.json` to match the deployed base path.

## Planned Features

- Outdrive spacer calculator/view
- Wind direction and course heading calculations
- Session logs based on real runs
- CSV export for logged sessions
