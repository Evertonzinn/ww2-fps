# v0.5 — Anti-Square Art Pass

Base: `main` consolidada (`217b0be`). Objetivo: reduzir a silhueta quadrada do protótipo, sem alterar controles, mira, recarga ou dano.

## Alterações incluídas

- Telhados com duas águas por `SurfaceTool`, fechamento triangular e beirais.
- Fachadas com batentes, portas visualmente recuadas, pranchas e chaminés alternadas.
- Bolsas de areia com `CapsuleMesh` sobre as colisões já existentes.
- Cercas com colisão, placa, carroça danificada e entulho batelado em `MultiMesh`.
- Coronha com seções de larguras diferentes, gerada por `SurfaceTool` no rifle.
- Decoração extraída para `environment/prop_builder.gd`, sem dependências externas.

Não há modelos oficiais ou texturas proprietárias de franquias comerciais.

## Regressão no Debian

```bash
cd /mnt/ows-data/games/ww2-fps
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --quit
```

Depois rode **F5** no editor e confira:

1. Sem erros de parser ou runtime no painel Depurador.
2. Quatro casas com telhados inclinados e fachadas com diferença visual.
3. Colisão com cercas, casa, carroça e barris.
4. WASD, Shift, espaço e rotação de câmera idênticos à versão anterior.
5. Tiro, ADS, recarga e alvos que somem após três acertos.
6. Medir FPS com V-Sync no mesmo estado e resolução da v0.4 por pelo menos 60 s.
7. Se aparecer regressão crítica, retornar para `main` sem mesclar.

**Limite:** ainda é geometria procedural otimizada, não asset final de Blender/Mixamo. O salto para fidelidade de CoD 2 exigirá modelos GLB com UV, materiais e animação dedicados.
