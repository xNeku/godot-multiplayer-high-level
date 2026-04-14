# Godot Multiplayer (High-Level API)

A networked 2D arena prototype built in Godot 4 using ENet high-level multiplayer.

## What I implemented
- Host/client flow with room connection and disconnect handling.
- Authority-based player control and remote synchronization.
- Class/loadout system (`ClassData` + `WeaponData`) with per-role passives and abilities.
- Combat loop with shooting, throwable gadgets, cooldown abilities, and score tracking.
- Menu/lobby flow and game-over screen logic.

## Technical highlights
- Custom `HighLevelNetworkHandler` autoload to manage session lifecycle.
- RPC-based class sync and replicated player setup.
- Input/action mapping for movement, run, shoot, ability, and throw interactions.
- Modular scenes for weapons, projectiles, and utility tools (smoke, claymore, translocator).

## Controls
- `WASD`: move
- `Shift`: run
- `Left Click`: shoot
- `F`: ability
- `G`: throw gadget

## Engine
- Godot `4.5`

## Run
1. Open the project in Godot 4.5.
2. Run the `Menu` flow.
3. Start as host on one instance and join from another using the host IP.
