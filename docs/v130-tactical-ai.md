# WW2 FPS v0.13.0 — IA tática, cobertura, investigação e recarga

## Base verificada
`fix/v122-enemy-rig-weapon-pose` @ `a7c712daec9717b360c7f113f69d7cf0e3616b46`.
Esta branch contém o trabalho de rig, orientação e empunhadura aceito
visualmente pelo usuário (Astra, PR #29). Não recuperar arquivos da v0.12.1.

## Entrega
- `enemy_combat.gd`: estados PATROL, INVESTIGATE, ADVANCE,
  SEEK_COVER e IN_COVER. Detecção visual anterior preservada,
  com 0,90 s de reação ao alerta por som. Busca última posição
  conhecida, respeita obstáculos e não dispara sem linha de visão.
- `enemy_cover.gd` novo: avalia sacos de areia, caixas e barris
  existentes no World. Só aceita cobertura se raycast do jogador até
  a altura de soldado agachado encontra o objeto físico e se a rota
  direta até o ponto está livre. Nunca teletransporta o personagem.
- Após exposição prolongada (>2,5s), HP <= 65 ou pouca munição,
  o inimigo considera cobertura. Ele se abaixa, alterna janelas de
  observação/disparo e abandona abrigo quando o jogador se aproxima.
- Audição: cada disparo **efetivamente realizado** pelo Lee-Enfield
  ou sniper emite o sinal `gunshot` do Player; inimigos a <=32m
  investigam o ponto. Apenas uma chamada na rotina real de tiro de
  cada arma; lógica de dano, munição, animações e mira intactas.
- Munição inimiga: 5 tiros, intervalo aleatório de disparo anterior
  preservado, 2,7 segundos para recarga. Enquanto recarrega não
  atira; rifle montado inclina levemente, sem fingir que há
  clip/magazine 3D para o inimigo.
- `enemy_soldier.gd`: mistura agachamento procedural nos
  quatro ossos das pernas, desce visual do corpo e corrige a
  altura das sete hitboxes ao agachar. O IK de braços e a arma
  montada ao Spine2 feitos pelo Astra continuam responsáveis
  pela empunhadura, agora também durante o agachamento.
- Acertar a perna diminui 28% a velocidade de avanço enquanto vivo.
  Reação a tiro informa a IA e aumenta a prioridade de cobertura.

## Arquivos e proteção de regressão
Alterados: `enemy_combat.gd`, `enemy_soldier.gd`, `player.gd`,
`weapon.gd`, `sniper_view.gd`. Novos: `enemy_cover.gd`,
`tests/v130_tactical_smoke.gd` e esta documentação.
NÃO alterados: `enemy_soldier.tscn`, `hud.gd`, `main.tscn`,
`world_props.gd`, `graphics_menu.gd`, GLBs, texturas, damage zones`.
A única alteração de cada arma é a emissão de sinal após
`shot_audio.play()` quando um disparo é confirmado.

## Limites de escopo
- É IA tática inicial, **não** A* nem navmesh. Caminhos obstruídos
  são rejeitados pelo raycast; quando não houver rota/cobertura
  válida, o inimigo pode manter a posição ou perseguir de forma
  simples. Não prometer rota em torno de casas/obstáculos.
- O agachamento é procedural sobre rig e colisores aproximados;
  não substitui clips animados de caminhada/recarga/cobertura.
- Apenas um Panzergrenadier no mapa para validação. Sem alterações
  em IA de outros NPCs, multiplayer ou persistência.
- Som/tiros de armas e combate do jogador usam os sistemas pré-existentes.

## Teste Debian — sem instalação
Fechar Godot, preservar mudanças locais, executar:
```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/feature/v130-enemy-tactical-ai
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" \
  --script res://tests/v130_tactical_smoke.gd
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" \
  --script res://tests/v120_combat_smoke.gd
```
F5: dispare Lee-Enfield e sniper fora do campo de visão do
soldado para testar investigação por som. Verifique busca de
cobertura junto de caixas/sacos de areia, agachamento temporário,
disparos somente ao se expor, cinco tiros e pausa de recarga;
reação de tiro na perna, headshot, tela de morte, ESC e reinício.
Log deve registrar `HEARD SHOT`, `SEEK_COVER`, `COVER reached` e
`RELOADING` **somente se as respectivas condições ocorrerem**.
O planejamento pode corretamente retornar vazio quando uma
cobertura física válida não estiver acessível do ponto atual.

## Validação e rollback
Análise estática do GitHub nesta execução. O ambiente de edição
não contém Godot instalado. Não afirmar que smoke/headless/F5
passaram sem testar no Debian. PR de rascunho, nunca merge em main.
Rollback seguro: `git switch fix/v122-enemy-rig-weapon-pose`
sem excluir arquivos 3D locais.
