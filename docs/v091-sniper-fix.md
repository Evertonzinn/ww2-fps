# v0.9.1 — sniper alinhada, reticulo e ferrolho do modelo

Base: feature/v09-sniper-second-weapon. Apenas sniper_view.gd, sniper_scope_overlay.gd e esta documentacao.

Diagnostico: o GLB tem um nodo raiz Sketchfab_model com matriz que transforma Y da arma em -Z do Godot e Z original em Y. A rotacao adicional em sniper_view.gd fazia o cano ficar vertical, como no screenshot do usuario.
O reticulo anteriormente dependia de shader em ColorRect com anchors definidos antes da inclusao na arvore. No screenshot ha zoom sem reticulo. Agora uma Control full-rect, adicionada antes do preset, desenha a mascara circular e linhas do reticulo no centro do viewport, sem outro render 3D.
O modelo contem quatro meshes originais. Object_4 corresponde ao mesh separado Object_2 na regiao do receptor, contendo a alavanca/ferrolho. O script testa animacao procedimental dessa malha original: elevar, recuar 7 cm, avancar e travar em 0,9s. Nao duplica componentes nem altera GLB e somente anima apos disparo.

VALIDACAO EXIGIDA: Godot 4.7.2 em Debian nao executado neste ambiente. Rodar importacao headless e F5, pressionar 2 e inspecionar rifle horizontal. Pressionar RMB e confirmar reticulo circular + FOV 20 com centro no impacto. Um tiro deve gerar exatamente um ciclo visivel de ferrolho. Caso Object_4 nao seja localizado, a arma continua estatica e o console registra warning.
Teste munição 5/20 ate 0/20 e recarga 5/15; tecla 1 retorna ao Lee-Enfield sem perder HUD, recoil, auto reload e menu.
Rollback seguro: git switch feature/v09-sniper-second-weapon. Evitar reset --hard e nao apagar GLBs locais.