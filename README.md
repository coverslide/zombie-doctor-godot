# Zombie Doctor for Godot 4

This is a standalone Godot game repository. The runtime models and audio are
copied into `assets/` and `audio/`; no files or symlinks from the Vite project
are required. Open `project.godot` in Godot 4.7 or newer and run `Main.tscn`.

To build locally and deploy the Web export to the parent game directory, run:

```sh
make web
make deploy
```

`make web` writes `build/html/index.html`. `make deploy` copies `index.html`
and its companion files into the parent directory and writes Brotli sidecars.
`make check` checks the scene headlessly; `make clean` removes only `build/`.
Godot 4.7 export templates and the `brotli` command are required. The first
asset import can take several seconds.

## Controls

- Desktop: WASD to move, mouse to aim, left click to fire, Space to jump, Left Shift to dash, Esc to pause.
- Gamepad: left stick to move, right stick to aim, right trigger to fire, A to jump, B to dash.
- Touch: drag on the left half to move, drag on the right to aim, use the Fire and
  Jump and Dash buttons. The pause button is at the upper right.

## Current port

The playable Godot loop includes an open grass
arena with solid rock cover, unlimited syringe shots, zombie cures, survivors,
spitters, recurring bosses, stage progression, scoring, audio, menus, and touch
controls. It uses Godot's Compatibility renderer and a small arena mesh to limit
mobile memory use. Best score and mute preference are saved under `user://`.

Some details of the web version have simplified implementations here. Survivors
use fists or limited gunfire without equipped weapon meshes, the grass field is
flat, and score and stage presentation are basic.
