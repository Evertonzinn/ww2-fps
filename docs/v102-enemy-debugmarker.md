# WW2 FPS v0.10.2 — Correção de acesso nulo ao DebugMarker

## Erro real reproduzido no Debian pelo usuário
```text
ERROR: Node not found: "DebugMarker" (relative to "/root/EnemySoldier")
  at: @implicit_ready (res://enemy_soldier.gd:15)
WW2 FPS enemy: loading res://assets/characters/panzergrenadier/panzergrenadier_1k.glb
SCRIPT ERROR: Invalid assignment of property 'visible' ... on a null instance
  at: _ready (res://enemy_soldier.gd:70)
```

O modelo é encontrado e o Godot começa a carregá-lo. O erro é a dependência não
essencial de um Label3D de diagnóstico que pode não existir em uma cópia da
cena local. A inicialização tenta acessar `locator.visible` quando
`locator == null`.

## Correção
- `@onready` usa `get_node_or_null` em vez do caminho obrigatório `$DebugMarker`.
- Se o label não existir, `_ensure_locator()` o cria em memória, durante `_ready()`,
  preservando o marcador e permitindo que o GLB continue carregando.
- Nenhum arquivo binário, malha, Skeleton3D, câmera, arma, colisão, dano ou cena foi modificado.
- A definição estática `DebugMarker` em `enemy_soldier.tscn` continua válida.
- O fallback se aplica somente se o nó estiver ausente.

## Teste Debian
```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v102-enemy-debugmarker-safe
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" res://enemy_soldier.tscn --quit-after 30
```

Esperado: não gerar mais `Node not found: "DebugMarker"` nem `Invalid assignment ... visible on null`.
Log esperado: `WW2 FPS enemy READY: visual meshes=... bones=... HP=3`.
Depois usar F5 na cena principal para validar modelo, marcador, orientação, escala
e três impactos eliminando o soldado.

## Limitações
Análise estática e revisão do diff somente; Godot não está instalado no
ambiente de autoria. O teste real de execução deve ocorrer no Debian.
Assets GLB continuam locais (ZIP anterior). Não mesclar sem aceite visual.

## Rollback
`git switch fix/v101-enemy-visible-asset-diagnostics` (preserva arquivos locais).
