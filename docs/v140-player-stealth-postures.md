# WW2 FPS v0.14 — Postura tática do jogador e furtividade

## Base e garantias
Branch base verificada: `fix/v131-tactical-crouch-smoke` @ `4278185e68bcc69aa656654747ae496393d8e704`.
Mantém a v0.12.2 do Astra e a IA tática da v0.13.1.
Não altera GLBs, Skeleton3D, animações das armas, dano, ferrolho,
carregador, mira, câmera de zoom/FOV, menu gráfico nem renderizador.

## Controles (alternância por tecla, não manter pressionado)
- `C`: em pé -> agachado; agachado -> em pé; deitado -> agachado.
- `Ctrl`: em pé/agachado -> deitado; deitado -> agachado.
- `WASD`: move na postura atual; `Shift` só corre em pé.
- `Espaço`: só pula em pé. R, 1, 2, clique, ADS, menu ESC
  e câmera livre continuam com os mesmos contratos.
- Aumentar postura sob teto/obstáculo sólido é recusado com log,
  mantendo a posição e a colisão anterior.

## Mecânica
- Nova `player_stance.gd` independente integra com Player.
- Em pé: cápsula vertical h=1,8m, corrida 8m/s, caminhada 5m/s.
- Agachado: cápsula vertical h=1,26m, 2,05m/s.
- Deitado: **cápsula física horizontal** 1,5m, raio=0,29m,
  rastejo 0,90m/s, câmera baixa/deslocada para frente.
- Centro do CharacterBody3D muda para preservar contato dos pés
  com o solo; a posição visual da câmera interpola suavemente.
- `PhysicsDirectSpaceState3D.intersect_shape` checa espaço livre antes de trocar a postura.
  Isso não substitui testes de geometria em rampas, portas e obstáculos reais.
- `main.tscn`: cápsula deitado é definida/desativada na cena,
  não criada durante Player._ready, prevenindo falha de SceneTree.
- HUD mostra `EM PE`, `AGACHADO`, `DEITADO` e situação tática.

## Furtividade audível para a IA
- Player emite `footstep(position, hearing_radius)` **somente quando percorre
  distância suficiente apoiado no chão**, nunca a cada tecla.
- Alcance de audição aproximado (raio do evento):
  caminhada 7m, corrida 14m, agachado 1,5m e deitado 0,8m.
- O inimigo em `enemy_combat.gd` agora ouve passos dentro do alcance,
  entra em investigação e não confunde isso com o sinal de disparo
  já existente (`gunshot`). **Não é invisibilidade**: um inimigo
  que enxergar você ainda pode atirar.
- Não foram adicionados arquivos de áudio para passos nesta entrega.
  "Silencioso" significa **baixa percepção acústica pela IA**.

## Testes Debian sem instalação
Fechar Godot e preservar alterações locais:
```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/feature/v140-player-stealth-postures
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" \
  --script res://tests/v140_player_stance_smoke.gd
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" \
  --script res://tests/v130_tactical_smoke.gd
```
Depois F5: C agacha e volta, Ctrl deita e volta agachado,
WASD rasteja, Shift não corre nas posturas baixas, espaço não pula,
scope/ADS e carregador funcionam agachado/deitado, animações de
tiro não alteradas, atirar ainda denuncia posição e inimigo
consegue perceber passos rápidos, mas não passos silenciosos à distância.
Com Debug > Visible Collision Shapes, verificar cápsula vertical e horizontal,
cabeça/câmera e mudança de colisores. Testar teto baixo antes de declarar
bloqueio de levantar validado.

## Limites/validação
Desenvolvido e auditado estaticamente via GitHub. Godot 4.7 não disponível
no ambiente de autoria; **não declarar PASS sem execução no Debian**.
A movimentação não tem animação de corpo/ braços TPS do jogador;
a câmera e colisão realmente alteram postura, sem um corpo FPS animado.
A cápsula deitado é horizontal com rotação seguindo o yaw do jogador
e não é um sistema completo de física para rastejar em terrenos irregulares.
Para maior realismo: IK de corpo do jogador, sons de passos por superfície,
lean Q/E, deslize por sprint e stamina, supressão, visibilidade por iluminação.
PR draft e `main` intacta. Rollback:
`git switch fix/v131-tactical-crouch-smoke`.
Nunca excluir assets locais do Panzergrenadier/armas, nem forçar reset.
