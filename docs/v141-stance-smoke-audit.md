# AUDITORIA CIRÚRGICA v0.14.1 — Smoke de posturas do jogador

Repositório: `Evertonzinn/ww2-fps`.
Base confirmada: `feature/v140-player-stealth-postures` commit `79fab2ac21693a834f0902593fe5332bdb8e95be`.
Relato real no Debian: engine inicia World e inimigo, mas teste falha imediatamente:
`WW2 FPS v0.14 PLAYER STANCE SMOKE: FAIL — initial standing stance invalid`.

## 1. Diagnóstico comprovado (falso negativo)
Em `tests/v140_player_stance_smoke.gd`, condição original:
```gdscript
if not bool(posture.call("is_standing")) or prone.disabled:
```
A cena `main.tscn` define `ProneCollisionShape3D` com
`disabled = true`. O `player_stance.gd::_ready()` também o
desativa explicitamente. Logo, `prone.disabled == true` é
**o resultado esperado** ao inicializar em pé. O teste rejeita
justamente o comportamento correto. Essa falha não comprova defeito
no controlador, na física do Jolt ou no Player.

Condição corrigida:
```gdscript
if not bool(posture.call("is_standing")) or standing.disabled or not prone.disabled:
```
Além disso, o teste valida altura real da cápsula em pé (1,8m) e
agachada (1,26m), registrando postura e estado dos dois colliders.

## 2. Fragilidade de sincronização do smoke
`await process_frame` repetido não garante passos de física;
no Godot headless há independência de `process_frame` e
`physics_frame`. Agora aguardamos a árvore World ser montada,
quatro passos de física do Jolt e um frame de processo antes
de conferir colisões. Não alteramos o timestep do jogo.

## 3. Revisão dos contratos de runtime
- `player_stance.gd`: enum STAND/CROUCH/PRONE; Ctrl/C como alternância;
  controle de 2 cápsulas por chave; `intersect_shape` antes de expandir
  sob obstáculo; câmera interpola; Shift/Espaço não operam deitado.
- `main.tscn`: contém a cápsula deitado desabilitada, raio 0,29,
  comprimento 1,50 e rotacionada 90°, enquanto a cápsula em pé está ativa.
- `player.gd`: cria o controlador, preserva disparo real, ADS, troca de
  armas, morte e menu. Emite passos calculados por distância real.
- `enemy_combat.gd`: conecta o sinal `footstep` somente para percepção
  sonora e mantém gunshot, tiro, cobertura e recarga existentes.
- `hud.gd`: exibe estado sem substituir vida, FPS e munição.

Nenhum outro erro de runtime foi **comprovado** no log apresentado.
O teste agora prossegue para agachar/deitar, teto baixo, levantar e
contratos de audição. Se algum deles falhar, registrar o erro específico
antes de modificar o gameplay.

## 4. Escopo
**Somente** `tests/v140_player_stance_smoke.gd` e este relatório.
Não instalar dependências, não mexer em GLBs, armas, rig do Astra,
mira, hitboxes do soldado, FPS, renderizador nem scripts de gameplay.

## 5. Teste no Debian
Fechar o editor e preservar alterações locais:
```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v141-stance-smoke-audit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v140_player_stance_smoke.gd
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v130_tactical_smoke.gd
```
Esperado no primeiro smoke:
`PASS: initial stance standing; upright enabled and prone disabled`
e, se demais verificações passarem,
`WW2 FPS v0.14 PLAYER STANCE SMOKE: PASS`.

Importante: sem Godot instalado no ambiente da auditoria,
os resultados headless e F5 permanecem **pendentes** até
a execução do usuário.

Rollback: `git switch feature/v140-player-stealth-postures`.
PR somente rascunho, main inalterada.
