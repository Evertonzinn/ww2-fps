# v0.15.7 — diagnóstico de skinning e enquadramento FPS

**Atualização após execução no Debian:** o usuário executou o smoke e retornou
falhas de orientação pé->dedos nos dois lados. Foi adicionada uma correção de
runtime em `player_body_visual.gd`: `_align_feet_forward()` mede essa direção
nos bones reais em repouso, resolve o yaw para -Z e gira o root visual inteiro.
O posicionamento passa a transformar a âncora pela base final rotacionada,
preservando a posição do quadril/piso após o giro. Não muda escala, câmera,
armas, controles ou arquivos GLB.

Não se presume que a falha signifique exatamente 180 graus: o ângulo é calculado
em runtime e impresso em `FORWARD`. Direções degeneradas/contraditórias falham
explicitamente. O export `body_yaw_degrees` passa a ser um ajuste adicional à
calibração (valor padrão 0). O teste de orientação permanece exigente.

Verificação matemática executada: cinco direções de origem convergem para -Z;
âncora preservada com três rotações e escala uniforme. Não equivale a execução
Godot. **Correção de orientação implementada; aceite visual pendente no Debian.**
Abaixo está o diagnóstico inicial e seu histórico; a causa de toda a
invisibilidade ainda não foi comprovada.

Base consultada antes da edição: `fix/v156-player-body-anatomical-framing`,
HEAD `43f91807dfb7d6ee62048ab02af369f7848920ca` (igual à referência).
Branch de trabalho: `fix/v157-player-body-fps-visibility`.

## Evidência comprovada no código

- `main.tscn`: BodyVisual é irmão de Head. Player começa em Y=0,95 m;
  Head em Y=0,60 m relativo ao Player. Camera3D tem FOV=75° e herda o pitch
  de Head, limitado em player.gd a ±1,4 rad. Corpo não deve herdar esse pitch.
- `player_body_visual.gd`: BodyVisual recebe Y=-0,95 em pé; em agachamento
  -0,68 e deitado -0,34. O loader altera a escala do root importado e tenta
  posicionar o piso a partir de ossos em repouso. A escala relativa efetiva
  entre meshes e rig só pode ser confirmada com o GLB/import real.
- A altura `corrected_visual_height` é `reference_span * (target_span /
  reference_span)`. Para valores finitos, ela apenas recupera target_span
  (0,86 ou 1,03), independentemente da altura deformada de Pants/Boots.
  O smoke antigo aceitava esse resultado como evidência de normalização.
- O smoke antigo projetava dois pontos de ossos e comparava sua ordem em Y.
  Não checava se estavam dentro da tela, nem skin/binds/pesos, layers, near/far
  ou vértices deformados. Dois ossos válidos não demonstram roupa visível.
- A allowlist Pants/Boots evita expor as malhas inteiras do tronco, mas os nomes
  das malhas não provam que os vértices que contêm estão fora da câmera.
- Não existe script de conversão britânico versionado na base. O documento
  v150 refere-se a um script entregue separadamente. Seu conteúdo não foi
  presumido nem reconstruído nesta entrega.

**Causa comprovada dos falsos positivos:** o teste verificava indicadores do
loader, não o resultado geométrico independente. **Causa da invisibilidade:**
ainda não comprovada. Export, bind poses, escala efetiva, culling, material e
enquadramento continuam hipóteses até medir os arquivos locais. O valor 0,011 m
relatado não basta para atribuir o defeito ao Blender ou ao driver Nouveau.

## Mudança restrita

1. `tests/support/player_body_probe.gd` (novo): reconstrói a posição de cada
   vértice usando a paleta `global_bone_pose * inverse_bind`, índices e pesos
   de cada superfície (4 ou 8 influências), depois o transform global da malha.
   Resolve binds por nome ou índice e verifica a SkinReference registrada.
2. `tests/v150_player_body_smoke.gd`: substitui os falsos positivos por medições
   independentes, salva JSON e oferece inspeção gráfica isolada.
3. Este documento.

Na entrega diagnóstica inicial nenhum runtime mudou. A atualização modifica
somente player_body_visual.gd para a orientação descrita acima, além deste
relatório. Cena principal, assets, configurações e controles continuam intactos.
Nenhuma dependência instalada; o offset anatômico não foi aumentado.

O JSON registra SHA-256 do GLB, configuração `.import`, hierarquia/transforms,
rest pose e pose atual dos bones, binds, arrays/pesos válidos, material/culling,
AABB estático separado dos bounds deformados, câmera e projeção. Mede em pé e
agachado, pitch 0°, -60° e -75°. Exige projeção bilateral de Pants/Boots a -75°,
rejeita projeção microscópica e verifica altura deformada/piso em pé. Registra
sentido pé->dedos a partir dos bones efetivamente encontrados e testa deformação
na passada. Verifica ocultação em prone e preservação das transformações locais
da hierarquia da arma e da câmera. O smoke de controles de postura fica intacto.

O teste geométrico usa CPU para poder executar sem display. Não consulta pixels.
Materiais com shader customizado ou blendshapes ativos são rejeitados como
não suportados pelo preditor. No modo gráfico, compara também com
`bake_mesh_from_current_skeleton_pose()` do engine (tolerância 1 mm), após um
frame renderizado. O bake requer Skin registrada e ignora blendshapes.

Referências primárias para as operações, não para o asset local:
- https://docs.godotengine.org/en/4.6/classes/class_meshinstance3d.html
- https://docs.godotengine.org/en/stable/classes/class_skinreference.html
- https://github.com/godotengine/godot/blob/master/scene/3d/skeleton_3d.cpp
- https://github.com/godotengine/godot/blob/master/scene/3d/mesh_instance_3d.cpp

## Executar no Debian

Fechar jogo/editor. Conferir mudanças locais antes de trocar de branch; não
usar clean, reset --hard ou force. Os assets não rastreados devem permanecer.

```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v157-player-body-fps-visibility
GODOT_BIN="$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64"
"$GODOT_BIN" --headless --editor --path "$PWD" --quit
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/v150_player_body_smoke.gd 2>&1 | tee /tmp/ww2-v157-body.log
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/v140_player_stance_smoke.gd 2>&1 | tee /tmp/ww2-v157-stance.log
```

Se a branch já existir, usar `git switch fix/v157-player-body-fps-visibility`.
O pipeline com tee serve para capturar logs; para obter o código de saída do
Godot no Bash, consultar `${PIPESTATUS[0]}` imediatamente após cada pipeline.

O body smoke imprime o caminho absoluto de `user://v157-player-body-diagnostic.json`.
Enviar esse JSON e ambos os logs, inclusive em caso de FAIL. Não é necessário
publicar modelos ou texturas. O JSON contém paths locais; revisar antes de
compartilhar publicamente. Exit 2 = GLB/import ausente; 1 = falha; 0 = critérios
geométricos passaram, **não aceite visual**.

Para inspeção real em OpenGL Compatibility, sem alterar o renderer configurado:

```bash
"$GODOT_BIN" --path "$PWD" --script res://tests/v150_player_body_smoke.gd -- --inspect
```

A cena principal é carregada em um processo de teste e congelada (sem IA,
movimento ou recuo). A instrumentação não é carregada pelo jogo normal.

- **1:** câmera FPS real olhando -75°.
- **2:** câmera externa frontal do corpo FPS no lugar real do jogador.
- **3:** perfil do corpo FPS.
- **4:** GLB completo original, se disponível, deslocado para inspeção. A câmera
  se ajusta aos bounds previstos; a escala do arquivo completo não é alterada.
- **Esc:** sair.

Enviar screenshots de 1, 2 e 3 e, se possível, 4. O enquadramento externo mostra
se a roupa acompanha o rig e se está sob os olhos ou distante deles. O modelo
completo permite comparação sem substituir o FPS. A inspeção é estática; não é
um novo sistema de câmera nem uma alteração dos controles do jogo.

Depois testar gameplay normal, sem `--script`:

```bash
"$GODOT_BIN" --path "$PWD" res://main.tscn
```

Verificar pernas/botas olhando para baixo, caminhada/corrida, agachamento,
prone oculto, ADS das duas armas, recarga, C/Ctrl/Espaço e teto baixo.
Com a atualização, o runtime alinha a frente do modelo e mantém a âncora após
o giro. Confirmar se botas/pernas aparecem naturalmente; o restante do
diagnóstico continua necessário caso persista invisibilidade.

## Resultados e limites

Executado aqui: conferência do HEAD, leitura dos contratos completos, comparação
estática do escopo e `git diff --check`. Uma reprodução numérica independente
mostrou que spans 0,011 / 0,86 / 86 retornam todos normalized=0,86 na fórmula
antiga. Outro contraexemplo com hip/foot em X=20 m, Z=0,14 m e separação vertical
0,86 m passa a ordem vertical e fica à frente da câmera a -1,3 rad, mas projeta
em X normalizado 14,058 / 5,853, inteiramente fora da tela. Esse é um
contraexemplo do teste, não uma medição do modelo do usuário. Godot e Blender não encontrados no PATH;
GLBs britânicos e conversor não encontrados no workspace. Não houve instalação.

PENDENTE DE TESTE NO DEBIAN: parsing, smoke do corpo, smoke de posturas, comparação
CPU/bake e inspeção gráfica. Não há PASS de execução registrado nesta entrega.
Não foi possível comprovar transforms ou bind poses reais do arquivo local.

Mesmo um PASS geométrico não verifica pixels, transparência/texturas, backface
culling, oclusão pela arma/chão, clipping durante toda a passada ou sincronismo
com modificadores de skeleton. O raio central frontal detecta interseções dos
triângulos de roupa, mas não substitui a inspeção de toda a tela. Limites de
altura/projeção são critérios conservadores de diagnóstico, não metas usadas
para reposicionar o modelo. Se a CPU divergir do bake, investigar o preditor e
modificadores antes de concluir que o GLB está errado.

Risco de regressão da atualização: sentido das pernas mudou para a frente
do jogador; verificar marcha e agachamento. Rig e meshes giram juntos. A
calibração depende de cadeias válidas de pé/dedos; falha explícita se ausentes.
Risco da instrumentação: scripts ainda sem parsing no engine; custo elevado de
percorrer todos os vértices apenas no teste; espera de GPU somente em --inspect.
Não chamar essas funções a cada frame do jogo.

Próxima correção depende da evidência: bind/paleta inválida requer pipeline de
export reproduzível preservando o original; geometria correta fora do frustum
requer enquadramento fundamentado; geometria correta no frustum sem pixels
requer investigar material/culling. Não corrigir um caso usando o tratamento
do outro. Sem licença verificada, nenhum FBX/GLB/textura deve ir para o GitHub.

## Rollback

Após preservar alterações locais, retornar à base em uma branch separada:

```bash
git switch -c rollback/v157-diagnostic 43f91807dfb7d6ee62048ab02af369f7848920ca
```

Sem apagar assets locais. Main e base não alteradas; entrega em Draft, sem merge.
