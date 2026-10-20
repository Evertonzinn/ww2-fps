# WW2 FPS v0.10.3 — Spawn do inimigo no World

## Evidências do Debian
- `enemy_soldier.tscn` iniciado isoladamente imprime:
  `WW2 FPS enemy READY: visual meshes=5 bones=65 HP=3`.
- `main.tscn` carrega cena e armas mas não imprime logs de
  `enemy_soldier.gd`. A instância do inimigo não iniciou na cena principal.
- `panzergrenadier_1k.glb` está presente e já importado.
- Não é necessário mudar materiais, escala, esqueleto ou GLB.

## Alteração localizada
- `world_props.gd`: pré-carrega `enemy_soldier.tscn`; agenda
  `_spawn_initial_enemy()` com `call_deferred` no fim do `_ready()`.
  Adiciona uma instância em `(1, 0, -4)` apenas se ainda não existir.
- `main.tscn`: remove a instanciação estática anterior e a referência
  correspondente, deixando uma única fonte para o spawn de teste.
- Logs de agendamento, instanciação e inicialização de GLB são explícitos.
- `enemy_soldier.gd`, `enemy_soldier.tscn`, armas, FOV, ADS, munição,
  danos e menu não foram alterados.

## Teste no Debian
```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v103-runtime-enemy-spawn
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" res://main.tscn --quit-after 90
```
Esperado:
```
WW2 FPS world: enemy spawn scheduled
WW2 FPS enemy: loading res://assets/characters/panzergrenadier/panzergrenadier_1k.glb
WW2 FPS enemy READY: visual meshes=5 bones=65 HP=3 ...
WW2 FPS world: EnemySoldierTest added to SceneTree ...
```
Depois F5: validar soldado na estrada, marcador SOLDADO TESTE, posição,
escala, FPS e 3 tiros suficientes para eliminá-lo.

## Riscos e limites
Os logs anteriores confirmam a ausência de inicialização na cena principal,
mas não identificam a causa interna da instanciação estática não executar.
A nova estratégia é explícita, controlada e observável.
Godot não está instalado neste ambiente de edição: testes headless e visuais
permanecem pendentes; nenhum merge automático.

## Rollback
`git switch fix/v102-enemy-debugmarker-safe` preserva GLBs locais.
