# v0.20.1 — vínculo entre braços FPS e arma

Base remota verificada: feature/v200-remaster-ballistics-quality-20261020,
45da6e40017a1074ecf4514e40cac040bf844939. É a branch remota mais recente e contém
o cenário/remaster da imagem. Não foi possível consultar a branch local Debian.

## Evidências e correção

weapon_hands.gd substituía o contato solicitado por `_limited()`, encurtando o
alvo em direção ao ombro quando a arma estava fora do alcance. A validação
comparava o punho ao marcador já deslocado e tolerava mais 10 cm. O smoke nem
verificava o deslocamento do alvo da sniper. Assim, IK válida não significava
punho no ponto solicitado da arma.

O patch preserva os contatos originais e resolve a restrição de alcance por
translação conjunta dos ombros/rig, sem esticar ossos ou mover a arma. A projeção
iterativa usa os comprimentos reais importados, com margem de extensão de 4%.
Se ambos os contatos forem incompatíveis com o rig, o erro final continua falhando:
não é mascarado pelo deslocamento do marcador. O limite final agora é 25 mm.

A sniper atualiza seu transform dentro de Weapon, mas as mãos interpolavam
posições no espaço do pai: durante recuo/ADS ficavam atrasadas. Agora os contatos
de repouso seguem a arma no mesmo frame, depois da atualização dos viewmodels
(process_priority=10). Interpolação permanece apenas no deslocamento deliberado
da mão para operações de ferrolho/recarga. Os polos de cotovelo são recalculados
após ajustar os ombros. O modelo começa oculto até a primeira pose validada.

Arquivos: weapon_hands.gd, tests/v160_weapon_hands_smoke.gd, este relatório.
Não foram alterados weapon.gd, sniper_view.gd, dano, balística, munição, câmera,
posturas, inimigos, cenário ou GLBs. Não há merge na main.

## Limites importantes

A imagem também mostra mãos abertas e orientação pouco convincente. O código
usa override_tip_basis=false e não anima dedos. Esta entrega NÃO inventa eixos
locais do BAMEN nem promete corrigir a palma/dedos sem inspecionar o rig real.
Os pontos originais de pegada foram preservados: sua correspondência com a
superfície da arma ainda exige inspeção gráfica. Um punho no alvo não comprova
contato da palma. A melhoria entregue elimina clamp/deslizamento dos alvos;
acabamento anatômico permanece pendente.

O pacote BAMEN foi localizado, mas sua obtenção para inspeção falhou por acesso
HTTP 403. Não houve contorno da restrição nem download de modelo alternativo.
Godot/Blender indisponíveis no PATH. Nenhuma ferramenta instalada.

Executado: revisão estática dos contratos, git diff --check e fixture matemática
sintética usando duas cadeias de 0,60 m: o antigo clamp deslocava um alvo em
8,32 cm; translação conjunta de ombros resolveu o alcance mantendo os contatos.
Isso NÃO mede os braços do usuário nem substitui execução Godot.

PENDENTE NO DEBIAN: parsing, smoke dos braços, smoke de posturas e renderização.
O novo smoke exige erro final <=25 mm, nenhum deslocamento do alvo de repouso
>1 mm, e simula deslocamentos da sniper verificando câmera/munição/transform
preservados. Não comprova qualidade dos dedos nem contato da malha skinned.

## Testar

Fechar jogo/editor e preservar mudanças locais se git status indicar arquivos
rastreados modificados. Não apagar os assets não rastreados.

```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v201-fps-arm-grips
GODOT_BIN="$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64"
"$GODOT_BIN" --headless --editor --path "$PWD" --quit
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/v160_weapon_hands_smoke.gd
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/v140_player_stance_smoke.gd
"$GODOT_BIN" --path "$PWD" res://main.tscn
```

Se a branch já existir, usar git switch fix/v201-fps-arm-grips. Nenhum ZIP novo.
Verificar 1/2, recuo após tiro, Lee ADS, sniper scope, recarga, ferrolho,
agachamento e troca 1K/2K. Fotografar repouso da sniper e Lee. O solver pode
aproximar os ombros da arma: conferir também corte de antebraços na tela.
Caso as mãos sumam, enviar HANDS POSE UNSAFE e a saída completa do smoke.

Rollback, após preservar alterações locais:

```bash
git switch -c rollback/v201-arms 45da6e40017a1074ecf4514e40cac040bf844939
```
