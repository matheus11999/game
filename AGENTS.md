# Brumora: persistent project direction

Read `docs/ART_DIRECTION.md` and `docs/PLANO.md` before changing visuals or game systems.

- This is a native Godot creature game, not a web dashboard. Preserve an immersive world, fantasy HUD, and consistent creature identities.
- The user rejected the simple 32px placeholder creatures and card-dashboard presentation. Use the approved detailed creature atlas and regional backgrounds. Do not regenerate placeholders over detailed production art.
- Art changes must preserve each creature's silhouette, material colors, expressive face, and relative scale. New assets should match the reference sheets, with transparent backgrounds for sprites.
- Animate movement, attacks, damage, healing, and shields smoothly. Keep pixel art crisp. Minimize visual work while the window is minimized.
- Windows x64 and a local server are the first delivered platform. Use the same Godot gameplay project for later desktop/mobile exports, with platform-specific adapters and UI adjustments.
- Godot is pinned to4.7.2 in `.godot-version`. The user has Docker Desktop: prefer `docker compose up --build -d` for the localserver and `docker compose --profile tools run --build --rm test` for server tests.
- Keep game authority on the TypeScript server. Never trust client-supplied rewards, stats, elapsed time, or battle outcomes.
- In the MVP, PvP means asynchronous battles against another account's saved defense. Do not describe it as live multiplayer or Steam friend integration.
- Run meaningful server tests and type checking after server changes. Use the client smoke test after UI/network changes. Re-export the Windows ZIP after changes intended for the delivered build.
- Package no development databases, tokens, credentials, logs, caches, or node_modules. Include third-party licenses and identify untested platform behavior honestly.
- Preserve the user's files and progress. Do not reset databases or profiles without a specific request.
