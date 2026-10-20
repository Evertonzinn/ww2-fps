# WW2 FPS v0.6 — Lee-Enfield 3D

Esta branch parte da `feature/v05-anti-square-art-pass` e contém **somente a adaptação da apresentação do rifle**, sem alterar disparo, mira, recarga e inimigos/alvos.

## Instalação do asset

O GLB não está incluído nesta branch: ele foi entregue ao mantenedor em um ZIP separado, gerado a partir do arquivo Sketchfab fornecido.

1. Baixar o pacote `ww2fps-lee-enfield-godot-v06.zip` da conversa.
2. Extrair **na raiz do projeto** (onde existe `project.godot`).
3. Confirmar que existe `assets/weapons/lee_enfield/lee_enfield_2k.glb`.
4. Fechar e reabrir o editor Godot, aguardando importar o GLB.
5. Rodar `F5`.

Sem o GLB no caminho esperado, `weapon.gd` mantém automaticamente o rifle procedural antigo da v0.5.

## Opcional: texturas 1K

Caso o FPS caia, basta alterar `RIFLE_3D_PATH` em `weapon.gd` para:
`res://assets/weapons/lee_enfield/lee_enfield_1k.glb`

As variantes compartilham 8.497 triângulos em 44 meshes, material PBR, sem esqueletos ou animações. A 1K tem menos consumo de textura.

## Teste mínimo no Debian

```bash
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --quit
```

No editor Godot, teste: WASD, Shift, pulo, mira, disparo, recarga e três impactos nos alvos. O som, contador de FPS e efeitos da v0.5 devem permanecer.

**Limitações conhecidas:** a animação de recarga é procedural, não move as peças do ferrolho; sem mãos animadas. A posição de ADS é inicial e pode precisar de calibração visual no editor, dependendo de como a câmera importa a malha.

## Licença

Veja `docs/lee_enfield_license.md`. O asset original é de Talamander (CC BY 4.0). Esta licença permite redistribuição/modificação com atribuição adequada.
