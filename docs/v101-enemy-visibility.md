# WW2 FPS v0.10.1 — Diagnóstico de inimigo invisível

## Causa verificável
O PR #22 introduz `enemy_soldier.tscn` e o script, mas os binários
`panzergrenadier_1k.glb` e `panzergrenadier_2k.glb` **não estão no GitHub**.
São distribuídos separadamente por `ww2fps-v100-panzergrenadier-assets.zip`.
A implementação v0.10.0 desativava modelo e colisão silenciosamente quando
`ResourceLoader.exists()` falhava ou quando não encontrava Skeleton3D.
Não é possível confirmar pelo print se a causa específica é falta de asset,
falha de importação, orientação da câmera ou esqueleto. O teste abaixo distingue.

## Correção sem dependências
- Mostra aviso em tela e `push_error` com caminho exato caso o modelo não exista
  ou não tenha sido importado pelo Godot.
- Tenta GLB 1K, fallback GLB 2K e `scene.gltf` se esse último estiver no diretório
  da personagem e suas dependências estiverem presentes.
- Mantém modelo visível se o rig não possuir o número esperado de ossos; registra
  aviso e número de bones. Só desativa quando não há malha renderizável.
- Adiciona temporariamente marcador `SOLDADO TESTE` à altura 2,17m como indicação
  independente da textura. Se marcador aparece e modelo não, é problema da
  geometria/escala/renderização; se ambos não aparecem, confira branch/cena.
- Aproxima spawn de x=2.2,z=-10 para x=1,z=-4, visível perto do ponto inicial.
- Nenhuma alteração em armas, dano, HUD original, scope, menu ou assets.

## Instalação — fechando o editor antes de importar
```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v101-enemy-visible-asset-diagnostics
unzip -n ~/Downloads/ww2fps-v100-panzergrenadier-assets.zip -d .
test -s assets/characters/panzergrenadier/panzergrenadier_1k.glb && echo "GLB OK"
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
```

Após F5, verificar uma destas saídas:
- Soldado e placa SOLDADO TESTE: importação concluída e modelo visível.
- Apenas placa: renderização/transform do GLB requer correção adicional.
- Aviso vermelho SOLDADO NAO CARREGADO: modelo ausente / importação falhou.
- Nem aviso nem placa: a branch ou a cena em execução não é esta, ou personagem
  já foi eliminado; confira SceneTree remoto e Output.

No Output, log de sucesso:
`WW2 FPS enemy READY: visual meshes=... bones=... HP=3 model=...`

### Restrições
GLBs continuam fora do GitHub; este PR não afirma correção sem instalação dos
assets originais. No ambiente de autoria não havia Godot disponível. O aceite
gráfico e FPS real exigem validação F5 no Debian. Sem merge automático.

### Rollback
`git switch feature/v100-first-enemy-soldier`, sem remover GLBs locais.
