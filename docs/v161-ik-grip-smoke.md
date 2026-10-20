# v0.16.1 — Rigged FPS hand alignment checks

A first-person arm animation must not pass by checking only bone count
and that SkeletonIK3D nodes exist. This regression in
`tests/v160_weapon_hands_smoke.gd` checks actual Godot world positions
of wrist tips after four frame updates for Lee-Enfield and sniper.
It prints both residuals and FAILS if a wrist is more than 0.18m
from its IK grip target. This gives actionable numbers when mesh
arms appear detached. Headless IK convergence does NOT prove good
visual orientation or palm/finger contact; F5 screenshots remain
mandatory. No gun script, ammunition, camera or collision touched.
