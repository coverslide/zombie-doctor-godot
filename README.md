# Zombie Doctor for Godot 4

This is a standalone Godot game repository. The runtime models and audio are
copied into `assets/` and `audio/`; no files or symlinks from the Vite project
are required. Open `project.godot` in Godot 4.7 or newer and run `Main.tscn`.

To export the Web build to the parent game directory, run:

```sh
./export.sh
```

The export writes `../godot.html` and its companion files beside the current
web game. Godot 4.7 export templates are required. The first import can take
several seconds.

## Controls

- Desktop: WASD to move, mouse to aim, left click to fire, Space to jump, Esc to pause.
- Gamepad: left stick to move, right stick to aim, right trigger to fire, A to jump.
- Touch: drag on the left half to move, drag on the right to aim, use the Fire and
  Jump buttons. The pause button is at the upper right.

## Current port

The playable Godot loop includes an open grass
arena with solid rock cover, unlimited syringe shots, zombie cures, survivors,
spitters, recurring bosses, stage progression, scoring, audio, menus, and touch
controls. It uses Godot's Compatibility renderer and a small arena mesh to limit
mobile memory use. Best score and mute preference are saved under `user://`.

Some details of the web version have simplified implementations here. Survivors
use fists or limited gunfire without equipped weapon meshes, the grass field is
flat, and score and stage presentation are basic.
