# WW2 FPS v0.8 — Recarga histórica com charger clips e estojo físico

Base: `fix/v071-bolt-animation-once` aprovada pelo usuário. Branch experimental, `main` inalterada.

## Histórico e escopo
- Lee-Enfield No.4: carregador destacável de capacidade **10**, normalmente **mantido na arma** e abastecido por dois clips de 5 cartuchos.
- Não ejetamos o carregador como arma semiautomática moderna. Adicionamos carregamento com charger clip visual sem mãos (provisório).
- Mag: 10/30, após 10 tiros -> 0/30; entra um clip: 5/25; segundo clip: 10/20, e o ferrolho fecha.
- Recarrega automaticamente com reserva. R top-up parcial, carregando no máximo 5 por segmento.
- Ejeção de estojo é `RigidBody3D` real: sai pela direita, gira, colide com o chão e se remove em 8 segundos; no máximo 18 instâncias mantidas.
- Disparos, raycast, dano, mira, menu e fallback permanecem.

## Modelo incluído em ZIP separado (não no GitHub)
- `lee_enfield_charger_1k.glb` e `lee_enfield_charger_2k.glb` preservam 44 meshes originais e respectivas texturas.
- Três animações importadas: `BoltAction_Once` (0,86 s), `BoltOpen_Once` (0,43 s, mantém aberto), `BoltClose_Once` (0,48 s). Todas forçadas a `Animation.LOOP_NONE`.
- Sem segundo ferrolho sobreposto. As malhas existentes usam o mesmo rig glTF.
- Créditos Talamander CC BY 4.0 preservados no ZIP e documentos anteriores.

## Arquivos do repositório
- `weapon.gd`: state machine serializa disparo -> extração -> abrir -> clips -> fechar; munição atualizada ao concluir cada clip.
- `weapon_reload_fx.gd`: estojos físicos e clips procedurais leves; efeitos apenas visuais.
- `docs/v08-historical-reload.md`: esta documentação.

## Instalação Debian
1. Fechar Godot. `git status --short`. `git fetch origin`. `git switch --track origin/feature/v08-enfield-authentic-reload`.
2. Extrair `ww2fps-v08-enfield-charger-bolt.zip` na raiz do projeto sem apagar GLBs anteriores.
3. Verificar `assets/weapons/lee_enfield/lee_enfield_charger_2k.glb`.
4. `~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit`, depois abrir no editor e F5.

## Testes de aceite
1. Sem erros vermelhos Godot (parser e runtime); log deve mostrar `action=.. open=.. close=..`.
2. Um tiro: ferrolho faz apenas um ciclo e um estojo físico é ejetado. Não há duplicação.
3. Após 10 tiros: ferrolho aberto, dois clips de até 5 descem pelo receptor, fecha e volta a permitir atirar.
4. A contagem deve seguir 10/30 -> 0/30 -> 5/25 -> 10/20, sem valores negativos; reserva parcial respeitada.
5. R com 7/30 insere apenas três cartuchos e só consome três da reserva.
6. Esc pausa a recarga, texto do HUD e estojos; gráficos e resolução persistem.
7. Troca 1K/2K feita fora do ciclo; ADS mantém alinhamento, sem perda de FPS excessiva na GT 730.
8. Se faltar novo GLB, sistema faz fallback: rifle antigo renderizado e carregamento visual continua, mas sem abrir/fechar a ação.

## Limitações
Os clips foram construídos proceduralmente e não têm mãos animadas. A geometria do GLB possui rig baseado em malhas identificadas por inspeção; exige checagem visual e Blender para resultado final. O teste no Godot do usuário ainda não foi executado.

## Rollback
`git switch fix/v071-bolt-animation-once` restaura o controlador anterior (ferrolho em um único ciclo e carregador de cinco). Não apagar arquivos locais nem usar reset --hard.