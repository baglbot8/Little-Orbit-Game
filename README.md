# Little Orbit

A Godot 4 cozy space-neighborhood game in active development. Play an astronaut, wander six spherical worlds, visit Lumi, Bolt, Pip and Miso, trade favors for decorations, and make Clover your home.

## Play

For iPhone, use the Safari web version and **Share → Add to Home Screen**. The repository includes a GitHub Pages build workflow and an original astronaut Home Screen icon. See [iPhone testing and GitHub Pages](docs/IPHONE_TESTING.md) for upload, hosting and local preview steps. This is a browser game; opening its icon still needs internet, and progress is stored per browser/device.

Touch play includes a left joystick, Run toggle, Jump, Use, Map, Bag and Pause. Drag open space to orbit the camera. While decorating, the lower buttons become Rotate, Refund and Place. Tapping dialogue reveals the rest; the reply button finishes the chat.

Double-click **Play Little Orbit.command** on this Mac, or open `project.godot` with Godot and press **F5**. From a terminal, run `godot --path .` in this folder. Built and exercised with Godot 4.7.1 on macOS / Apple Silicon. The game now uses Forward+ with Metal on this Mac, temporal antialiasing, soft shadows and ambient occlusion. Other engine versions and platforms have not been verified.

- **WASD** — walk around the planet
- **Shift + WASD** — run (release Shift to walk; decorating stays at walking pace)
- **Space** — hop
- **Right mouse drag** — orbit the camera
- **Mouse wheel** — zoom
- **E** — interact with a nearby neighbor, rocket, collectible, or shop
- **M** — choose a destination and fly there
- **B** — open the decorating bag on Clover
- **Left click** — place the selected decoration in front of you
- **R** — rotate the decoration
- **X** — return the closest placed decoration to your bag
- **V** — toggle sound (saved between sessions)
- **J** — open the neighborhood journal
- **C** — switch between a close walking camera and planet overview
- **H** — open the field guide
- **Escape** — pause/settings, close a panel or cancel placement

The start screen offers Continue, New Game, Settings and Quit. A new game requires confirmation when a save exists and preserves the previous save as `user://orbit_save.backup.json`. Settings include a master sound toggle, separate music/effects gains, fullscreen, and the field guide.

Start with a small decorating bag and 30 stardust. Visit Lumi on Luma and Bolt on Rust for favors. The Commons has a town hall journal, an 18-object shop with actual model previews, six complimentary spacesuit colors, and a wishing lawn. Pick a particular object or buy a surprise parcel. Each neighbor has six rotating favors across retrieving, gathering, decorating, visiting and wishing. The journal tracks progress; friendships unlock more personal conversations. A green decoration preview means the spot is clear; red means a path, pond, or object is in the way. Progress saves automatically and when the window closes, to Godot's `user://orbit_save.json`. Six-slot saves from the earlier build migrate without losing inventory. Audio/display preferences also live in `user://orbit_settings.json`. The start screen does not overwrite gameplay progress.

Controller mappings are also included: left stick move, RB run, A hop, X interact, Y bag, Back map, Start journal, LB camera, right stick look. A selects and B returns in menus. When decorating, A places, Y rotates, B cancels; clicking the right stick picks up. Software event routing is tested; a physical controller has not been verified.

## Verification

`godot --headless --path . --script res://tests/character_motion_checks.gd` checks rig attachment, walk/run blending, blinks and greeting recovery.

`godot --headless --path . --script res://tests/integration.gd -- --integration` runs the independent interaction suite: actual pointer hit tests, both favors and repeat rewards, all destinations, purchases/insufficient funds, placement restrictions and refunds, orientation around the sphere, and isolated save/load round trips. It does not touch player saves. The test exits nonzero on failures.

`godot --headless --path . --script res://tests/art_only.gd -- --integration --art-only` checks the latest home and foliage geometry, material batching, placement masks, building collisions and entry-step levels without loading player progress.

`godot --headless --path . -- --smoke-test` checks initial world generation, shop purchase, favor reward, and rocket travel without loading or altering player saves.

`godot --path . --max-fps 60 --quit-after 360 -- --capture` writes an actual rendered gameplay frame to `captures/clover.png` without altering player saves.

`godot --path . --script res://tests/polish_gallery.gd -- --integration` renders the actual start screen, settings, worlds and menus at multiple window sizes. `tests/render_catalog.gd` regenerates object, suit and neighbor thumbnails from the real 3D models. These scripts do not load or write player progress.

The polish gallery records source and capture hashes in `captures/polish/manifest.json` and rejects a run if production files change during capture. Catalog previews render through a transparent viewport so they fit both cream and selected cards.

`godot --path . --max-fps 60 --script res://tests/performance_tour.gd -- --integration` samples wall-clock frame intervals during a short running tour of each planet and a rocket flight. This is a bounded real-time measurement on the machine running it; Movie Maker output FPS is not used as a performance measurement.

## Production status

This is a playable procedural prototype, not a finished AAA game or an equivalent to Animal Crossing: New Horizons. It has original procedural models, terrain shading, spherical walking/running, articulated characters, UI, and synthesized music. The shops currently use menus, the favors are a small authored set, and buildings have no interiors. It still needs substantial content production, animation, accessibility and controller work, more extensive playtesting, performance profiling, and independent visual refinement. See `docs/POLISH_VISUAL_REVIEW.md` and `docs/POLISH_FUNCTIONAL_REVIEW.md` for the independent critics' findings and evidence boundaries. `REVIEW.md` preserves the earlier review.

All game content is generated locally; reference images supplied in the workspace are not included as game art.

## Components

- `scripts/main.gd`: game state, spherical movement, camera, travel, quests, decorating and persistence.
- `scripts/world.gd`: terrain, authored gardens, placement masks, obstacle footprints and merged static geometry.
- `scripts/art.gd`: original procedural characters, buildings, trees and decoration models.
- `scripts/homes.gd`: Lumi's garden cottage and Bolt's workshop, with curved-world foundations and entry steps.
- `scripts/botany.gd`: Clover's branching trees and softly shaded leaf canopies.
- `scripts/character_motion.gd`: blended walking/running, jump poses and idle head motion.
- `scripts/neighbor_motion.gd`: blinking, greetings and secondary head/antenna motion.
- `scripts/hud.gd`: responsive HUD, menus, dialogue, focus and sound controls.
- `scripts/ui_orbit_motif.gd`: original illustrated orbital motifs for menus.
- `scripts/touch_controls.gd`: finger ownership, joystick, touch actions and safe movement release.
- `scripts/audio.gd`: locally synthesized ambient score, cues and separate gain controls.
- `scripts/catalog.gd`: object names, prices, footprints and suit colors.
- `scripts/neighborhood.gd`: rotating favors, friendship milestones and neighbor writing.
- `scripts/atmosphere.gd`: procedural sky, Luma fireflies and wishing trails.
- `web/` and `.github/workflows/web-pages.yml`: single-thread web export, Safari loader, Home Screen metadata and GitHub Pages deployment.

`--gallery` renders the key game screens to `captures/` and exits. `--reel` runs a deterministic short demonstration suitable for Godot Movie Maker mode. These modes also leave player saves alone.

## Running and character update

Hold Shift while moving to run at 5.5 units/second; walking remains 3.3. Acceleration and the gait blend smoothly, jumping works while running, and menus stop movement. Decorating keeps walking speed. The astronaut has refined suit construction and color-safe accents; Lumi and Bolt blink, greet you, turn toward nearby players, and have articulated faces and antennae.

The scoped independent review is in `docs/CHARACTER_REVIEW.md`. Character comparison: `captures/characters_after.png`; actual running preview: `captures/running.webp`.
