# omarchy-multi-output

Bar widget that plays the same audio on two or more outputs at once, such as
two AirPods.

Plugin id: `omarchy-multi-output`. Repository:
`https://github.com/mads0laden/omarchy-multi-output.git`.

This plugin does not use the network. It talks to the local PipeWire/Pulse
daemon with `/usr/bin/pactl` and stores the selected sink names on disk.

## Install

The repository is private. Clone it with an account that can read
`mads0laden/omarchy-multi-output`:

```bash
omarchy plugin add https://github.com/mads0laden/omarchy-multi-output.git --enable
```

## Remove

Turn sharing off in the panel first so the combine-sink is unloaded, then:

```bash
omarchy plugin remove omarchy-multi-output
```

That deletes the plugin checkout. It does not delete plugin state. The selected
output names remain at:

`~/.local/state/omarchy/omarchy-multi-output/state.json`

If sharing was still on when the plugin was removed, PipeWire may keep the
`omarchy_multi_output` combine-sink until you log out, reboot, or unload that
module yourself. The plugin does not install packages, credentials, units,
udev rules, or sudoers entries.

## Update

```bash
omarchy plugin update omarchy-multi-output
```

## License

MIT — see [LICENSE](LICENSE).

## External dependencies

- **Omarchy** with Quattro shell.
- **`/usr/bin/python3`** — the combine helper, invoked with `-I -S`.
- **`/usr/bin/pactl`** — PipeWire Pulse compatibility, used to load and tear
  down `module-combine-sink`.

No `sudo` or `pkexec` is required. Loading the plugin does not edit Hyprland
config, `shell.json`, or any file outside the plugin-owned state directory
except through Omarchy's normal plugin enable path.

## Panel

- **Hero** — the sharing toggle. On sends audio to every ticked output; off
  restores the previous default sink.
- **Outputs** — one row per playback device. Tick at least two, then turn
  sharing on. Right-click the bar icon to start or stop sharing without opening
  the panel.
- **Bar** — a speaker icon, filled while sharing, with a count of selected
  outputs next to it.

Connect both devices first (for Bluetooth, they must already be paired and
connected), then tick them here.

## How it works

The helper loads PipeWire `module-combine-sink` as `omarchy_multi_output`, sets
it as the default sink, and moves current streams onto it. Turning sharing off
unloads the module and restores the previous default.

Selected output names are stored in
`~/.local/state/omarchy/omarchy-multi-output/state.json` inside a plugin-owned
0700 directory. Device names and descriptions from PipeWire are treated as
untrusted input: they are length-capped and stripped of markup before they
reach the bar.
