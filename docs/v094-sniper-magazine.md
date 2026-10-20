# WW2 FPS v0.9.4 — Carregador 3D destacável da sniper

## Base e escopo
Branch base: `fix/v093-sniper-viewmodel-forward` (PR #19, último teste visual aprovado do rifle).
Alteração cirúrgica apenas em sniper_view.gd e nesta documentação. Scope (PR #18), animação original do ferrolho, câmera/raycast, sons, munição, HUD e Lee-Enfield permanecem inalterados.

## Asset 3D
Pacote do chat `ww2fps-sniper-v094-magazine.zip` contém `sniper_rifle_mag_1k.glb` e `sniper_rifle_mag_2k.glb`, cada um derivado do respectivo arquivo 1K/2K que já funcionava.
- As quatro malhas originais do rifle foram preservadas sem modificações; acrescentou-se somente uma quinta malha de carregador, com três superfícies de material.
- Carregador metálico modelado especificamente para a geometria original, com corpo de chapa afunilado, ranhuras, ressaltos, trava e chapa de base; acabamento PBR procedimental de metal azulado.
- **288 triângulos adicionados por variante**. Não há malha duplicada no receptor nem transformação dos nós originais.
- Criados os nós nomeados `SniperMagazinePivot` e `SniperMagazineMesh` dentro do glTF, posicionados a partir dos cartuchos originais em coordenadas do arquivo fonte.
- O modelo original de Martin Trafas segue CC BY 4.0, com atribuição no pacote.

## Recarga visual
- Ao pressionar R ou ao acabar a munição, o carregador se destrava e desliza para baixo (apenas quando o ferrolho termina seu ciclo, se necessário).
- O carregador vazio vira um RigidBody3D independente com colisão apenas contra o cenário; o novo carregador entra por baixo e trava no poço.
- Estojos e munição seguem os sistemas já existentes, sem modificação de reserva/dano.
- Até 6 carregadores ejetados em cena, com expiração de 12 segundos (pausável).
- Os GLBs antigos continuam sendo fallback: sem pacote novo, a sniper funciona como na v0.9.3, somente sem animação visual de troca.

## Instalar
1. Fechar Godot. `cd /mnt/ows-data/games/ww2-fps` e `git status --short` para verificar alterações locais.
2. `git fetch origin` e `git switch --track origin/feature/v094-sniper-magazine-reload`.
3. Extrair `ww2fps-sniper-v094-magazine.zip` no diretório do projeto, sem excluir ou sobrescrever assets anteriores.
4. Rodar `~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit` e depois F5.

## Checklist antes do merge
- Console: `Sniper: detachable 3D magazine imported: SniperMagazinePivot`.
- Tecla 2: carregador visível sob o receptor sem flutuar ou atravessar madeira; rifle aponta para frente.
- RMB: luneta circular e retículo centralizados; tiro atinge centro.
- R após 1–4 disparos: carregador antigo cai, novo vem de baixo, consumo de munição correto.
- No último tiro, ciclo do ferrolho termina antes da animação de troca, com FOV e áudio preservados.
- Testar 5/20 -> 0/20 -> 5/15 e manual em 3/20 -> 5/18.
- Verificar que cada recarga gera no máximo um carregador descartado e que ele não bloqueia projéteis.
- Trocar 1/2, teste textura 1K/2K, menu Esc (pausa também remove TTL), janela e FPS estável.
- Capturar print parado e vídeo recarregando. **Não mesclar antes de validação visual**.

## Limitações
- Não há modelo de mão/rig de recarga no arquivo: magazines animados proceduralmente, sem mão humana. A aparência próxima de remaster depende de um rig de mãos corretamente autorado e testado em Blender.
- A posição do poço foi estimada usando geometria do GLB e cartuchos: conferência visual no Godot Debian é obrigatória.
- O projeto não foi compilado graficamente aqui; sem alteração na main nem instalação de dependências.

## Rollback
`git switch fix/v093-sniper-viewmodel-forward` retorna ao código da sniper anterior e ignora o novo GLB. Não apagar assets, não usar reset --hard.