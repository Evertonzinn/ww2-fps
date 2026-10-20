# WW2 FPS — v0.6.1: mecânica de rifle e menu gráfico

Base `feature/v06-lee-enfield-model` (não mesclada na main).

## Funcionalidades
- Recarga automática após disparar o último projétil, **somente se houver munição reserva**.
- Recarga manual continua em R e não cria munição.
- Ejeção visual de estojo reaproveitando uma pequena malha, ciclo procedural do viewmodel após o tiro.
- **O GLB original não tem animação nem identificadores semânticos confiáveis para o ferrolho.** O ciclo implementado aqui é feedback visual; a peça física real do ferrolho ainda não foi animada.
- Esc abre e fecha o menu, pausa o jogo e libera/captura o cursor.
- Resolução de janela: atual, 720p, 1080p, 1440p, 2160p (4K, se o monitor suportar).
- Tela cheia usa a resolução **nativa**, não força 4K em monitor 1080p.
- Presets Eco/Equilibrado/Alto/Ultra modificam MSAA 3D e sombras simples.
- Troca de textura 1K/2K do rifle (arquivo GLB local obrigatório).
- V-Sync configurável, preferências salvas em `user://ww2_graphics.cfg`.

## Premissas e riscos
- O renderizador Godot Compatibility continua sendo o alvo. Ultra/4K não é recomendado para a GT 730.
- As malhas `.glb` do usuário **não são armazenadas nesta branch**, instalar o ZIP local do v0.6.
- Nenhum asset comercial pode ser redistribuído sem seus próprios termos.
- Não foram alterados Player/Head/Camera3D, alinhamento de mira, raycast ou dano.
- A mudança em `player.gd` altera Esc: em vez de apenas liberar o cursor, abre o menu.
- Sem o modelo, o rifle procedural de fallback funciona.

## Smoke test

```bash
cd /mnt/ows-data/games/ww2-fps
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --quit
```

1. F5: cena inicia sem erros vermelhos no Depurador.
2. Com o carregador 5/30, dispare 5 vezes e confirme **RECARREGANDO...**, depois 5/25.
3. Dispare com reserva zerada, confira **SEM MUNICAO** e ausência de recargas infinitas.
4. R antes de esvaziar inicia recarga; durante recarga, clique não dispara.
5. Verifique ciclo visual do rifle e estojo e a mira em ADS após o tiro.
6. Esc abre menu e congela movimento; Esc ou botão Voltar ao jogo retoma.
7. Mude para 720p/janela, aplique, reinicie e confira persistência.
8. Em um monitor realmente 4K, habilite 3840x2160 em janela (só se comportar) ou use tela cheia na resolução nativa 4K.
9. Compare FPS e dados de memória no preset Eco/2K vs Alto/2K.

Se houver qualquer erro de parsing, **não faça merge**. Recue para `feature/v06-lee-enfield-model`.

O menu define parâmetros de renderização; qualidade visual AAA depende também de malhas, texturas, LOD e materiais melhores.
