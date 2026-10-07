# The Quiet Relay — working prototype

A small original movement/puzzle slice for Oblivion. The name is provisional. Bring the warm weight up three broken steps to the listening cradle, restore the bridge, and cross to the eastern door.

Open `project.godot` in Godot 4.7.2 and press F5. See [setup](../../docs/SETUP.md) and [design/tuning](../../docs/DESIGN.md) for details.

- A/D or left/right: move.
- Space, W, or up: jump; hold for height, release for a shorter jump.
- E: carry/drop, or place near the high cradle.
- R: restart at the last lit checkpoint; restored relay remains restored.
- Backspace: reset the whole room and puzzle.
- Esc: pause/resume. Close the window to quit.

Move toward the far edge of each step before jumping to the next. The top cradle shows a place prompt when close enough. The lower-floor checkpoint lights when crossed. Falling into the pit respawns you; a lost weight returns to its start. All scene visuals are generated in `scripts/world.gd`.
