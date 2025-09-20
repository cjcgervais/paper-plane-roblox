
## Features
- Server spawner & reset flow
- Client intent → server physics loop (authoritative)
- Throttle ramping, directional lift, quadratic drag
- Bank-to-turn yaw assist
- Simple HUD (speed, throttle, stall flag)

## Controls (default)
- **W / S** – Pitch down / up  
- **A / D** – Roll left / right  
- **Q / E** – Yaw left / right  
- **Space / LeftShift** – Throttle up / down  
- **F** – Mount / Dismount plane  
- **R** – Reset (if provided in HUD or bind)

> If your local keybinds differ, see `StarterPlayerScripts/PaperPlaneController.client.lua`.

## Getting Started (Roblox Studio)
1. Clone the repo and open your place in Studio.
2. Drag the three folders into **Explorer** at the same levels shown above:
   - `ServerScriptService`
   - `StarterPlayer/StarterPlayerScripts`
   - `StarterGui`
3. Play (`F5`) and press **F** to mount, then fly using controls above.

## Development Workflow
```bash
# create a feature branch
git checkout -b feat/readme-polish

# make edits
git add README.md
git commit -m "docs: add project README"

# push and open PR
git push -u origin feat/readme-polish
