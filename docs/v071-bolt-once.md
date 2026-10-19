# WW2 FPS v0.7.1 — corrigir ciclo infinito do ferrolho

## Incidente e causa
Godot importa clipes com prefixo/sufixo 'cycle' ou 'loop' como animações em repetição. O glTF anterior denominava a animação 'BoltCycle'. A regra é documentada em https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html

## Correção
- ZIP separado com lee_enfield_rigged_once_1k.glb e lee_enfield_rigged_once_2k.glb: o clipe agora se chama 'BoltAction_Once'.
- Somente a string do nome da animação foi alterada dentro do JSON do glTF. BIN, triangulação, texturas, UVs, amostras de animação e materiais permanecem byte a byte iguais.
- weapon.gd prefere o novo GLB, com fallback para rigged_1k/2k anterior e GLB não animado.
- Ao vincular AnimationPlayer, impõe Animation.LOOP_NONE, inclusive para o GLB anterior.
- Proteção adicional: interrompe a execução após 0,86 s e atualiza o estado final da animação.
- Recarga automática, disparo, mira, menu 4K e qualidade de texturas preservados.

## Debian
Fechar o Godot. Conferir git status --short. git fetch origin e git switch --track origin/fix/v071-bolt-animation-once.
Extrair ww2fps-v071-lee-enfield-bolt-once.zip na raiz do projeto (onde fica project.godot). Não remove arquivos antigos.
Executar ~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --quit. Abrir editor e F5.
Log esperado: Lee-Enfield: one-shot bolt animation ready: BoltAction_Once | loop_mode=0.

## Critérios
- Parado antes de atirar; um disparo -> uma animação -> parado após 0,86s.
- Sem segundo disparo durante ciclo; após 5 tiros inicia recarga automática com consumo correto da reserva.
- Mira alinhada, sem ferrolho extra, menu gráfico, V-Sync, troca de textura 1K/2K e FPS sem regressão.
- Não mesclar até conferir visual e runtime no Debian. A main permanece intacta.

## Rollback
Retornar à feature/v061-auto-reload-graphics (rifle estático, recarga automática validada), sem reset hard e sem apagar assets locais.