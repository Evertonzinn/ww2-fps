# WW2 FPS v0.6.3 — Bolt action de quatro fases

Base: \`feature/v062-lee-enfield-bolt-cycle\`.

## Melhorias da integração

- Ciclo de quatro fases com tempos declarados: destravar/levantar, puxar, avançar, travar.
- Corrige a lista da prova de conceito anterior, que não incluía \`Cube.008_Low\` (região da ação próxima do cabo).
- Guarda transformações relativas à raiz importada: as malhas acompanham a câmera, incluindo ADS e sway.
- Não altera GLB de terceiros ou suas texturas.
- Se não encontrar as quatro malhas candidatas, não aplica animação parcial.
- Um novo tiro só é permitido após o ciclo e cooldown; a mira e tiro por raycast foram preservados.
- Estojo só é expelido quando se inicia a fase de extração.
- Ao acabar a munição, a recarga automática **aguarda o ferrolho concluir** e depois inicia, somente com munição de reserva.
- A tecla R continua disponível para recarga manual.

## Limite real

A inspeção da geometria sugere quatro componentes próximos ao ferrolho; os nomes genéricos do modelo **não permitem confirmar a separação exata de todas as peças**. Logo, o movimento é experimental e será validado no Godot. Para produção, separar e nomear as peças no Blender e animar pivôs próprios.

## Smoke test

\`\`\`bash
cd /mnt/ows-data/games/ww2-fps
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
\`\`\`

1. Sem erros de parser no Depurador; procurar no terminal "ciclo experimental do ferrolho ativo".
2. Depois de 1 tiro, observar levantar → puxar → avançar → travar; capturar gravação lenta do mecanismo se possível.
3. Pressionar dois tiros rapidamente: segundo não deve sair até concluir ferrolho/cooldown.
4. No quinto disparo com \`5/30\`, a recarga inicia após cerca de 0,44 s e passa a \`5/25\` no fim da recarga.
5. Esvaziar a reserva: não há recarga infinita, HUD indica \`SEM MUNICAO\`.
6. Conferir que o estojo aparece no recuo, não antes.
7. Menu Esc pausa totalmente a animação; gráficos 1K/2K reatam as malhas e restauram offsets.
8. Conferir ADS, V-Sync, sombras, desempenho e que nenhum elemento original atravessa a coronha.
9. Não mesclar se partes se moverem incorretamente. Voltar à v0.6.1 ou v0.6.2 se necessário.

A animação de mãos e recarga física dos cartuchos ainda não faz parte do escopo.
