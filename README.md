# omarchy-multi-output

Bar widget that plays the same audio on two or more outputs at once, such as
two AirPods.

Plugin id: `omarchy-multi-output`. Repository:
`https://github.com/mads0laden/omarchy-multi-output.git`.

## Install

The repository is private. Clone it with an account that can read
`mads0laden/omarchy-multi-output`:

```bash
omarchy plugin add https://github.com/mads0laden/omarchy-multi-output.git --enable
```

## Remove

```bash
omarchy plugin remove omarchy-multi-output
```

## Update

```bash
omarchy plugin update omarchy-multi-output
```

## License

MIT — see [LICENSE](LICENSE).

## External dependencies

- **Omarchy** with Quattro shell.
- **`python3`** — the combine helper under `bin/combine`.
- **`pactl`** — PipeWire Pulse compatibility, used to load and tear down
  `module-combine-sink`.

No `sudo` or `pkexec` is required. Install does not overwrite user config except
through Omarchy's normal plugin enable path.

## Panel

- **Hero** — the sharing toggle. On sends audio to every ticked output; off
  restores the previous default sink.
- **Outputs** — one row per playback device. Tick at least two, then turn
  sharing on. Right-click the bar icon to start or stop sharing without opening
  the panel.
- **Bar** — a speaker icon, filled while sharing, with a count of active
  outputs next to it.

Connect both devices first (for Bluetooth, they must already be paired and
connected), then tick them here.

## How it works

The helper loads PipeWire `module-combine-sink` as `omarchy_multi_output`, sets
it as the default sink, and moves current streams onto it. Turning sharing off
unloads the module and restores the previous default.

Selected outputs are stored in
`~/.local/state/omarchy/omarchy-multi-output/state.json`.
