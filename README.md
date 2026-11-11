# Monitr

A minimal, keyboard-first monitor settings manager for Omarchy / Hyprland.

Monitr lists all connected monitors and lets you change their resolution,
refresh rate, position, rotation, and scale — all from one clean window,
applied instantly via `hyprctl`.

## Keyboard shortcuts

| Key      | Action                        |
|----------|-------------------------------|
| `R`      | Refresh monitor list          |
| `Ctrl+Z` | Reset last change             |
| `?`      | Show / hide keyboard shortcuts|
| `Q`      | Quit                          |

## Building

```sh
bin/build   # compiles into build/monitr
bin/test    # runs the test suite offscreen
bin/install # builds the Arch package and installs it
```

Requires `qmake6`, Qt 6 (base, declarative, quickcontrols2, wayland), and
Hyprland with `hyprctl` on `$PATH`.

## License

MIT — see [LICENSE](LICENSE).
