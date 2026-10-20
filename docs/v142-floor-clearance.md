# WW2 FPS v0.14.2 — Auditoria da colisão de posturas

Base verificada: `fix/v141-stance-smoke-audit` @ `b2b73b44e4fc6ccbf8e19265650e6751601d4490`.
Relato real no Godot 4.7.2 Debian: ao pressionar C,
`WW2 FPS player: posture blocked by overhead/obstacle` e
`FAIL — C did not activate crouching collision (stance=0 upright_disabled=false prone_disabled=true)`.
O erro anterior de teste na v0.14.1 estava corrigido; este erro
comprova que o **controlador** rejeita a mudança de postura.

## Causa provável fundamentada
`player_stance.gd::_space_is_available()` executava um
`intersect_shape` da cápsula inteira com `margin=0.005` e
excluía apenas o Player. Em `main.tscn`, World/Ground é
um `StaticBody3D` sob o jogador. Com Jolt e a cápsula apoiada
no piso, a margem e a precisão do contato podem produzir
colisão de consulta com o próprio **chão**, embora ele não
impeça agachar/deitar. O log original não traz nome do
colisor: a hipótese de piso ainda requer teste real.

## Remediação sem esconder obstáculos
1. **Em pé → agachado:** o raio da cápsula é mantido, a
altura diminui e a base fica no mesmo nível; a geometria
agachada é um subconjunto estrito da cápsula em pé.
Não há necessidade de consultar cena inteira para redução.
2. **Outras transições:** preservam checagem `intersect_shape`
usando o volume e transform reais da postura de destino.
A consulta exclui o RID do jogador e **somente** o corpo
`World/Ground`, que é o piso físico conhecido do protótipo.
Caixas, paredes, tetos e demais obstáculos permanecem
dentro da máscara e bloqueiam postura quando invadidos.
`margin=0.0` evita expansão artificial da forma.
3. Se ainda houver um obstáculo verdadeiro, o log identifica
seu caminho, por exemplo `/root/World/TestLowCeiling`.
4. Corrige saída redundante `posture blocked...`
que aparecia para cada tentativa recusada.

## UI solicitada
Remove `SHIFT PARA CORRER` e todas as instruções de
teclas/ações do indicador de postura. HUD mostra apenas
`EM PE`, `AGACHADO` ou `DEITADO`. Não altera
vida, munição, FPS, dano ou tela de morte.

## Escopo
Mudanças em `player_stance.gd`, `hud.gd`, smoke de
postura e este relatório. Nenhuma alteração em
`weapon.gd`, `sniper_view.gd`, IA, GLBs, rig do Astra,
dano, câmeras/FOV, menu gráfico ou física global.

## Validação no Debian — sem instalações
```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v142-stance-floor-clearance
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v140_player_stance_smoke.gd
```
Esperado em um teste completamente aprovado:
`PASS: C crouches, vertical collision and silent speed`;
`PASS: Ctrl prone, horizontal capsule, crawl speed and low camera`;
`PASS: no clipping/standing through a ceiling`;
`PASS: stealth hearing range changes enemy detection`;
`WW2 FPS v0.14 PLAYER STANCE SMOKE: PASS`.

Depois, F5: agachar com C, Ctrl deitar, Ctrl levantar
agachado, C levantar, movimentação lenta, câmera correta,
impedir erguer sob obstáculos, tiro/recarga de Lee-Enfield,
ADS da sniper, áudio de detecção e combate do inimigo.

**Validação estática apenas:** Godot não instalado
no ambiente de autoria. Não afirmar PASS até rodar
o teste real no Debian. Se aparecer um caminho
de obstáculo no log, verificar antes de ampliar exclusões.

PR draft, main intacta. Rollback seguro:
`git switch fix/v141-stance-smoke-audit` sem apagar
os GLBs, cache ou alterações locais.
