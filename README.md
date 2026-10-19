# WW2 FPS

Protótipo FPS original inspirado no ritmo dos jogos clássicos de Segunda Guerra Mundial, desenvolvido em **Godot 4.7.2 (GDScript, renderizador Compatibility)**.

## Rodar no Debian

Abra este diretório no editor do Godot ou use:

```bash
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --path .
```

A cena principal está definida em `project.godot`.

### Verificação sem interface

```bash
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --quit
```

Isso verifica importação e carregamento de recursos, mas **não substitui** o teste visual de GPU nem os testes de controles e física.

## Controles

| Entrada | Ação |
| --- | --- |
| WASD | Andar |
| Shift | Correr |
| Espaço | Saltar |
| Mouse | Olhar |
| Botão esquerdo | Atirar |
| Botão direito | Mirar |
| R | Recarregar |
| Esc | Soltar cursor |

## Estado da v0.4 (experimental)

- Vila modular com casas, fachadas, telhados e obstáculos.
- Céu e iluminação ambiente para o renderizador Compatibility.
- Texturas discretas geradas em tempo de execução (48×48 px por material).
- Pavimento lateral com MultiMesh para reduzir chamadas de desenho.
- Rifle provisório aprimorado por malhas simples; falta importar um modelo 3D final.
- Contador de FPS e tempo médio estimado por quadro no HUD.
- Alvos com dano, munição, recarga e feedback de tiro herdados da v0.3.

### Checklist de validação da v0.4

1. Executar sem erros vermelhos no Depurador.
2. Confirmar que as faces laterais das casas não estão pretas.
3. Caminhar entre as casas e colidir com os obstáculos.
4. Mirar, acertar alvos (3 disparos) e recarregar.
5. Medir FPS por 60 segundos andando, correndo e atirando.
6. Comparar o menor FPS percebido com a v0.3 nas mesmas condições.

A captura anterior da v0.3 mostrou 60 FPS a 1152×648 em uma GT 730 com nouveau, **não uma garantia de FPS mínimo ou desempenho no Windows**. A taxa pode estar limitada por sincronização vertical.

**Os telhados, portas e janelas são fachadas visuais; as casas ainda possuem colisão sólida e não são exploráveis.**

Nenhum asset, personagem, mapa ou marca oficial de Call of Duty foi incorporado ao projeto.
