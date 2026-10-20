# WW2 FPS v0.8.1 — First-person hands, art-pass provisório

## Objetivo
Evitar o efeito de 'clip flutuando sem pessoa' na v0.8 aprovada visualmente. Apenas visual; nenhuma alteração no sistema de carregamento ou contagem de munição.

## Alterações
- `weapon_arms.gd`: dois braços FPS geométricos com mangas oliva, luvas, palmas, dedos e polegares, construídos uma vez na inicialização.
- Mão direita fixa na região de empunhadura; mão esquerda apoia o rifle, vai ao ferrolho nas fases 1 e 3 e acompanha o clip na fase 2.
- `weapon_reload_fx.gd`: adiciona somente `get_charger_position()` para sincronizar a mão com a posição do clip, inclusive no curso vertical da inserção.
- `weapon.gd`: instancia `FirstPersonArms` e chama update_pose no processamento visual após atualizar a posição do clip.
- Assets glTF/Talamander, rig do ferrolho, munição (10 por carregador e clips de cinco), ejeção física de estojos, ADS e menu 4K preservados.
- Sem novas texturas ou arquivos pesados. Os braços são placeholders, **não rigs realistas**.

## Verificação no Debian
1. Fechar Godot, executar `git status --short` e conferir modificações locais.
2. `git fetch origin` e `git switch --track origin/feature/v081-first-person-arms`.
3. `~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --quit`.
4. Abrir projeto, F5: verificar se há apenas duas mãos, mangas, e rifle 3D intacto.
5. Pressionar R com munição parcial; mão esquerda deve ir ao receptor, agarrar o clip visualmente, descer junto e retornar.
6. Esgotar munição: duas sequências de clip de cinco; ADS deve permanecer centralizado depois da recarga.
7. Conferir estojo ejetado uma vez por tiro, recarga 10/30 -> 0/30 -> 5/25 -> 10/20 e pausa Esc.
8. FPS estável na GT 730, sem geometria tampando a mira de ferro.

## Limitações / próximos passos
- Braços com primitivas leves e dedos simplificados; posições são iniciais e precisam de inspeção visual antes de qualquer merge.
- Para qualidade final de 3D, substituir `FirstPersonArms` por um rig de braços humano com IK/AnimationPlayer e sincronizar eventos do ferrolho/clip.
- Se mão atravessar o rifle ou cobrir ADS, ajustar somente as constantes de pose no arquivo `weapon_arms.gd`; não alterar `weapon.gd`.
- A v0.8 fica intacta. Retornar com `git switch feature/v08-enfield-authentic-reload`; não usar reset --hard nem apagar GLB local.