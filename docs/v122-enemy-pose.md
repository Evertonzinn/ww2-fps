# v0.12.2 — integração visual do inimigo armado

## Base e limite de confirmação

Base remota verificada: `fix/v121-enemy-rifle-ik-locomotion`,
HEAD `6c2d64886e4096af960f99c22027a6490a03bf8f`, PR #28.
É a versão mais recente compatível com o relato. Não é possível consultar a
branch ativa no terminal Debian do usuário a partir deste ambiente.

Análise feita sobre scripts/cena atuais e o glTF-fonte do pacote fornecido
`ww2_panzergrenadier_2k_cc0.zip` (o nome do ZIP não substitui a licença interna).
O arquivo possui 65 joints, cinco meshes e nenhum clip de animação.
Os GLBs convertidos locais do usuário não foram reimportados neste ambiente.
Nenhum asset foi alterado, baixado de terceiros ou substituído.

## Causas identificadas

1. **Mapeamento de ossos quebrado após importação.** A fonte usa
   `mixamorig:RightArm_48`. O importador Godot sanitiza `:` como `_`, gerando
   `mixamorig_RightArm_48`. A expressão anterior
   `split(":")[-1].split("_")[0]` retorna `mixamorig`, não `RightArm`.
   A reprodução sobre os nomes reais sanitizados encontra 0/14 ossos obrigatórios.
   As funções de IK retornam silenciosamente quando não encontram esses ossos:
   os braços permanecem na pose de origem. A normalização corrigida encontra 14/14.
   Referência: `_sanitize_bone_name` em `modules/gltf/gltf_document.cpp`, Godot.
2. **Frente do modelo oposta à do combate.** Na fonte, os dedos dos pés avançam
   em +Z: pé esquerdo Z -0,0827 m, base dos dedos +0,0550 m; direito -0,0776 →
   +0,0575 m. Modelo sem correção de yaw; arma, detecção e giro usam -Z.
   Rotaciona-se apenas o visual em PI, mantendo root de combate/hitboxes intactos.
3. **Pegada incompleta.** A IK anterior buscava posição do punho nos marcadores,
   sem compensar a palma, orientar o pulso ou fechar os dedos. Havia marcadores
   afastados das superfícies da arma e coronha excessivamente larga/comprida.
4. **Arma desligada do torso.** Rifle era filho do root físico, mas respiração e
   flinch modificavam só o modelo/ossos. Agora acompanha o delta do Spine2 e a
   pose dos braços é resolvida depois da atualização do corpo.
5. **Passada desacoplada da distância.** O relógio fixo de animação era o mesmo
   para patrulha (0,7 m/s) e perseguição (2,1 m/s). A fase agora acompanha o
   deslocamento horizontal real, com transição suave para repouso e flexão de
   joelho para trás. A lógica de perseguir e girar não foi reescrita.

## Correção e arquivos

- `enemy_soldier.gd`: normalização dos nomes importados/fonte, diagnóstico de
  ossos ausentes, giro exclusivo do visual, referência do torso, alvo da palma
  a 45 mm do punho, orientação das mãos, fechamento moderado de dedos e passada.
- `enemy_combat.gd`: proporções/posição do rifle existente, bases dos marcadores,
  acompanhamento do torso e prioridade explícita da pose depois do corpo.
- `tests/v122_enemy_pose_smoke.gd`: teste dos assets reais em 1K e 2K, quatro
  orientações, repouso/flinch, distância palma/grip <25 mm, orientação do punho,
  cotovelos abaixados, limite de dobra do punho, arma à frente e ausência de
  acumulação de transforms. Também verifica fase de passada por distância.
- `docs/v122-enemy-pose.md`: este relatório.

O rifle continua sendo a geometria procedural já presente. Sua silhueta foi
estreitada e a coronha encurtada para a pose; não é um novo asset detalhado.
Materiais do soldado e GLBs não foram alterados para mascarar um erro de rig.

## Verificações realizadas

- HEAD e árvore do repositório inspecionados antes de editar.
- Reprodução do bug de nomes com os joints reais: 0/14 antes, 14/14 depois.
- Hierarquia e transformação de repouso do glTF-fonte analisadas numericamente.
- Solver de dois segmentos reproduzido numericamente com os comprimentos reais.
  Alvo direito: 0,218 m para alcance de 0,482 m; esquerdo: 0,433 m para 0,488 m.
  Erro numérico de posição <0,001 mm. Ângulo punho/antebraço aproximado:
  18,3° à direita e 11,2° à esquerda na pose neutra. Isso é checagem matemática,
  **não execução do GDScript nem aprovação da deformação visual da malha**.
- Comparação automatizada: detecção, perseguição, `_fire`, dano, reação/morte,
  raycasts, áudio e tracer inalterados. O ponto de saída acompanha a arma
  reposicionada, como já previa `_fire`; nenhum cálculo de dano foi modificado.
- `git diff --check` aprovado.
- Godot/Blender não encontrados no PATH. Nada instalado. Smoke tests Godot,
  parsing, iluminação, deformação dos dedos, clipping e F5 não executados.

## Testar no Debian — PENDENTE

Feche o editor, confira `git status --short` e preserve alterações locais.

```bash
cd /mnt/ows-data/games/ww2-fps
git fetch origin
git switch --track origin/fix/v122-enemy-rig-weapon-pose
GODOT_BIN="$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64"
"$GODOT_BIN" --headless --editor --path "$PWD" --quit
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/v122_enemy_pose_smoke.gd
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/v120_combat_smoke.gd
"$GODOT_BIN" --path "$PWD" res://main.tscn
```

Se a branch local já existir, use `git switch fix/v122-enemy-rig-weapon-pose`.
Não precisa ZIP novo nem instalar nada; mantenha os GLBs já utilizados.
O teste v122 exige as duas variantes e falha explicitamente se alguma faltar.
Esperado: `WW2 FPS v0.12.2 POSE SMOKE: PASS` e o PASS de combate já existente.
Esses resultados são esperados, não resultados executados neste ambiente.

No jogo verificar:

- Rosto e pontas dos pés voltados para o mesmo lado do cano; aproximação frontal.
- Braços dobrados, cotovelos baixos, mão direita junto ao gatilho e apoio sob o rifle.
- Arma acompanha respiração, caminhada, giro, flinch e recuo sem se soltar.
- Conferir de frente, perfil e costas; parar/retomar marcha; comparar 1K/2K.
- Detecção, disparo, headshot, dano do player, morte, HUD e reinício.
- Lee-Enfield e sniper, ADS/retículo, recarga, menu Esc e preferências.

## Limitações e riscos residuais

Não há clips autorados, captura de movimento, IK de pés nem arma de alta
qualidade no asset do inimigo. Foot sliding residual e interseções finas de dedos
podem exigir ajuste após teste real. Hitboxes aproximadas continuam fixas como
na base: não foram convertidas para seguir bones. A melhoria não pode receber
aceite de remaster só por passar no teste geométrico.

Problemas de corrupção gráfica em terminal/gerenciador de arquivos relatados
fora do jogo não foram diagnosticados nem atribuídos à GPU por este patch.

## Rollback

Com alterações locais preservadas:

```bash
git switch -c rollback/v122-to-v121 6c2d64886e4096af960f99c22027a6490a03bf8f
```

Não excluir GLBs, `.godot` ou assets locais. Sem reset --hard/clean.
Main e branch base não foram alteradas; PR em rascunho sem merge automático.
