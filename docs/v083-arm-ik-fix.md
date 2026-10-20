# v0.8.3 — BAMEN: fixed shoulders + inverse kinematics

## Incident (user screenshot)
The v0.8.2 art pass produced detached arms and open shoulder endcaps directly in the camera frustum. Root cause: _apply_target displaced the complete shoulder-to-fingers hierarchy by (target_wrist - rest_wrist), with no elbow rotation, IK or stable shoulder anchor. The imported BAMEN mesh is an FPS viewmodel, so its shoulder ends are deliberately open and must be kept off-screen.

## Evidence
The source GLB contains 52 bones: Arm_1.L_02 / Arm_2.L_03 / Hand_1.L_04 and Arm_1.R_021 / Arm_2.R_022 / Hand_1.R_023. Shoulder→elbow = ~0.347 m, elbow→wrist = ~0.246 m. Previous direct shoulder translation had no anatomical constraint.

## Scope
- Only weapon_arms.gd changes.
- Import the same CC BY 4.0 BAMEN 1K/2K GLBs; no new download necessary.
- Offset entire imported model toward the body (rig_offset) so open shoulder caps remain out of view.
- Create two SkeletonIK3D modifiers, each with shoulder root, wrist tip, Marker3D target and elbow magnet.
- Keep shoulders anchored: no more set_bone_global_pose translation.
- Clamp hand targets to 95% of available two-bone reach (prevents unrealistic stretching when the charger is high).
- Continue syncing left hand with bolt and charger positions. Right hand target is stationary relative to Weapon.
- No gameplay, ammunition, damage, casing, menu or licensing changes.

## Limits and validation
This is an **IK proof-of-concept**, not hand-crafted poses with finger grips. Finger/thumb articulation and shoulder seam blending require Blender and an authored AnimationPlayer/IK rig. The reload clip may still be higher than natural reach and the hand will stop short of it rather than stretch.
No Godot 4.7.2 runtime was available in the build container. This branch is draft until visual and parser tests pass on Debian.

## Test
1. Close Godot; inspect git status --short, fetch, switch --track origin/fix/v083-bamen-fps-arm-ik.
2. Use previously downloaded bamen_arms_1k.glb. No new asset pack.
3. Godot --headless --editor --path . --quit, check parser errors.
4. F5: both arm shoulders/caps remain offscreen, wrists near stock/support, ADS not blocked.
5. R with a partly empty 10-round magazine: hand left moves toward charger but may stop at maximum reachable distance. No disconnected shoulder geometry.
6. Fire and exhaust magazine: ammunition/ejection and FPS should match v0.8.2.
7. Menu graphic quality 1K/2K should reload skeleton/IK without duplicate nodes.
8. If weird bend or visible caps persist, send screenshots. Tune rig_offset, elbow pole and hand targets without changing weapon, ammo or the asset.

## Rollback
Switch to feature/v08-enfield-authentic-reload to disable arms entirely while retaining verified shooting/reload, or feature/v082-bamen-rigged-arms for regression comparison. Never delete local CC BY assets or reset --hard.
