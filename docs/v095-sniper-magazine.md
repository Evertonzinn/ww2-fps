# v0.9.5 — carregador e munição da sniper

## Estado da entrega

Base auditada: `219f9ba6c1481b1d91fbf5a53e8882d1fcc25cf2`, branch
`feature/v094-sniper-magazine-reload`. Somente o visual do carregador é alterado.
Não é uma aprovação de qualidade comercial: importação, animação e iluminação
no Godot/GT 730 continuam **PENDENTES DE TESTE NO DEBIAN**.

## Evidências e causa-raiz

Os GLBs fornecidos no pacote `ww2fps-sniper-v094-magazine.zip` têm a mesma
geometria/hierarquia; diferem nas texturas. Há 8 nós e 5 meshes. A raiz Sketchfab
converte +Y fonte para -Z; o script já aplica a correção de orientação de v093.
Essas transformações foram preservadas.

`Object_5`, mesh 3/material `Sniper_rifle_ammo`, contém 3.350 triângulos em oito
componentes conectados (classificação por índices e posições soldadas a 1e-6):

| Componente | Faces | Limites em coordenadas fonte (metros) |
|---|---:|---|
| Seis cartuchos empilhados | 384 cada | Y -0,136937 a -0,090602; Z -0,067544 a -0,026138 |
| Suporte interno original, sem presumir que seja mola | 662 | Y -0,108433 a -0,089129; Z -0,067188 a -0,026524 |
| Cartucho de apresentação isolado | 384 | Y -0,018674 a 0,027661; Z 0,097496 a 0,104399 |

Esse último cartucho está **acima da luneta** (a luneta termina em Z 0,086164),
não na câmara. O gameplay não possui contador independente de cartucho na
câmara. Sua exclusão da cena ativa não altera munição lógica. Os bytes originais,
meshes, UVs e materiais originais continuam no GLB; o pacote v094 continua sendo
o arquivo-fonte imutável. O gerador verifica seu SHA-256 antes de trabalhar.

Object_5 era irmão de SniperMagazinePivot. Mover/ocultar o pivô não afetava os
cartuchos nem o suporte. A abertura frontal estreita do carregador adicionado
também deixava pontas de cartuchos para fora. A geometria antiga possuía uma tampa
superior fechada entre blocos usados como lábios e acabamento com faces duplas.

A recarga usava um relógio acumulado em `_process`, independente de reload_timer
atualizado na física. A ejeção só ocorria dentro de um intervalo: um frame que
saltasse esse intervalo podia perder a queda. A cópia do carregador era feita
no callback deferred, em vez de capturar seu conteúdo no instante da separação.

## Alterações

### Asset reproduzível, sem downloads ou dependências

`tools/build_sniper_mag_v095.py` usa exclusivamente a biblioteca padrão Python.
Entradas: os dois GLBs v094. Saídas novas: `sniper_rifle_mag_v095_1k.glb` e
`sniper_rifle_mag_v095_2k.glb`. Nunca sobrescreve as entradas.

- Mantém geometria original de corpo, luneta e ferrolho, materiais/texturas e
  prefixo binário byte a byte.
- Desativa a instância monolítica Object_5 e divide seus componentes por topologia,
  material e limites; falha se a estrutura divergir da fonte auditada.
- Cinco cartuchos nomeados `SniperMagazineRound01` a `05` e o suporte original
  tornam-se filhos do pivô. O sexto cartucho e o cartucho de apresentação permanecem
  nos dados originais, mas não na cena ativa.
- Cartuchos reutilizam UVs, normais e PBR originais; posição ajustada ao corpo.
- Novo pivô fonte: (0,0004855; -0,11377; -0,05).
- Corpo oco com parede de aproximadamente 1,1 mm, bordas chanfradas, base plate,
  nervuras discretas e lábios dobrados, sem tampa sobre a abertura de alimentação.
- Envelope local: 22 × 54 × 77 mm. Topo fonte Z -0,013, aproximado à parte
  inferior do rifle. Encaixe final e ausência de clipping requerem teste no jogo.
- Um material opaco, backface culling, textura de metal já existente (índice 9),
  metallic 0,82 e roughness 0,46. Não há novos mapas normal/roughness nem aumento
  de resolução; isso é calibração PBR, não uma nova textura artística de nível AAA.

| Medida | v094 | v095 |
|---|---:|---:|
| Triângulos do corpo do carregador | 288 | 480 |
| Superfícies do corpo | 3 | 1 |
| Triângulos ativos carregador + conteúdo | 3.638 | 3.062 |
| Triângulos ativos do rifle completo | 40.030 | 39.454 |
| Superfícies máximas carregador + conteúdo | 4 | 7 |
| Texturas adicionais | — | 0 |

A separação dos cinco cartuchos aumenta o máximo de superfícies, embora reduza
triângulos. Cada cartucho vazio fica invisível; o custo real precisa ser medido.
Até seis props continuam permitidos, com TTL pausável de 12 segundos.

### Código visual

Somente `sniper_view.gd` muda em runtime:

- Usa os GLBs v095. Se faltarem, avisa e mantém o fallback original; esse fallback
  não recebe as correções de geometria. Instalar o pacote é obrigatório para o aceite.
- Visibilidade dos cinco cartuchos deriva do contador existente, sem escrever nele.
- Durante recarga manual, o carregador descartado mantém sua munição visual
  remanescente; não se altera a política existente de reaproveitamento de munição.
- Recarga espera o ferrolho existente e usa o tempo lógico restante. Não altera
  duração da recarga nem do ferrolho.
- Saída: liberação de 1,5 mm, extração até 90 mm e inclinação só após afastamento.
- Captura uma única cópia visual antes de preencher o carregador novo; o evento é
  protegido mesmo se o intervalo de ejeção for saltado por um frame longo.
- Entrada: aproximação de 280 mm abaixo, alinhamento a 35 mm do encaixe, inserção
  axial e assentamento final de 1 mm, concluídos antes do término lógico.
- A trava é representada pelo assentamento; não se inventou um mecanismo histórico,
  animação de mão ou peça móvel que a fonte não contém.
- Corpo rígido usa basis ortonormal; escala fica na malha e na colisão dimensionada
  para o novo envelope. Colisão continua sem bloquear raycasts, como antes.

## Verificações executadas

- `git diff --check`.
- Gerador executado para 1K/2K; reconstrução repetida produz SHA-256 idêntico.
- `tests/check_sniper_mag_v095.py`: índices/buffers dentro dos limites, cinco
  cartuchos na subárvore correta, malha antiga não instanciada, envelope, normais
  compatíveis com winding, ausência de triângulos degenerados/duplicados na
  nova casca, preservação de dados originais e determinismo.
- Comparação com a base: `_fire`, `_physics_process`, `_process`, `request_reload`,
  ADS/scope, funções do ferrolho e equip/unequip permaneceram byte a byte iguais.
  As funções visuais chamadas por elas foram corrigidas.
- Inspeção de projeções geométricas e rasterização CPU com z-buffer, incluindo
  aproximação da perspectiva FPS. Isso não usa Godot, não reproduz sua iluminação
  PBR e não valida Nouveau, animação, física, importador ou performance.
- Nenhum Godot/Blender disponível no PATH verificado. Nada foi instalado.
  Parsing GDScript e execução headless **não foram realizados**.

## Instalação

Feche o editor e revise `git status --short`; preserve alterações locais antes
de trocar de branch. No diretório do projeto:

```bash
git fetch origin
git switch --track origin/fix/v095-sniper-mag-quality-realism
unzip -n ~/Downloads/ww2fps-sniper-v095-magazine.zip -d .
```

Se a branch já existir, use `git switch fix/v095-sniper-mag-quality-realism`.
O ZIP adiciona nomes novos, sem substituir GLBs anteriores. Código vem do Git;
o ZIP contém somente assets, manifest e atribuição, seguindo a distribuição
externa de modelos já usada no projeto.

Use o executável Godot **já instalado** para importar e depois executar o jogo:

```bash
/caminho/do/Godot-existente --headless --editor --path "$PWD" --quit
```

Esse comando está documentado para execução no Debian; não foi executado aqui.
Não instalar ou atualizar Godot para estes testes.

Para reconstruir em vez de usar o ZIP, se Python 3 já estiver disponível:

```bash
python3 tools/build_sniper_mag_v095.py \
  --source-dir assets/weapons/sniper \
  --output-dir /tmp/ww2-v095-assets
python3 tests/check_sniper_mag_v095.py \
  --source-dir assets/weapons/sniper \
  --output-dir /tmp/ww2-v095-assets
```

Copie apenas os dois GLBs v095 validados para `assets/weapons/sniper/`.
O manifest informa hashes da entrada e da saída.

## PENDENTE DE TESTE NO DEBIAN — bloqueia aprovação visual

- Importação 1K/2K e parsing GDScript sem erros.
- Repouso: carregador encaixado, cartuchos contidos, nenhum cartucho sobre luneta.
- Recarga manual após 1–4 disparos: uma queda, nenhuma munição suspensa,
  continuidade saída/entrada e carregador novo com conteúdo correto.
- 5/20 → 0/20 → 5/15; manual 3/20 → 5/18; reserva parcial e zero.
- Recarga automática aguardando ferrolho, sem salto final e sem queda duplicada.
- Esc durante saída, intervalo e inserção; pausar também os props e TTL.
- Slow frame/queda de FPS: uma ejeção, modelo restaurado ao término lógico.
- ADS, retículo, FOV, dano, recuo, ferrolho e troca 1/2 intactos.
- Menu gráfico e troca 1K/2K fora de recarga; recarga bloqueia substituição do GLB.
- Colisão dos props, limite de seis, expiração e desempenho próximo da referência.
- Inspeção FPS de clipping, z-fighting, acabamento PBR e dimensão aparente.
- Lee-Enfield sem regressões.

Riscos principais: importação dos nomes no Godot, encaixe perceptivo no receptor,
continuidade temporal na taxa real de frames, iluminação de material metálico
no Compatibility e custo das superfícies separadas. Não declarar remaster
comercial concluído sem essa validação.

## Rollback seguro

Com alterações locais preservadas, voltar à base em uma branch de recuperação:

```bash
git switch -c rollback/v095-to-v094 219f9ba6c1481b1d91fbf5a53e8882d1fcc25cf2
```

Os GLBs v095 podem permanecer no disco: a base usa os nomes v094. Não use
`git clean` nem `reset --hard`. Não foi alterada a main e não houve merge.
