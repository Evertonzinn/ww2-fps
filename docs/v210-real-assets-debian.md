# WW2 FPS v0.21 — instalar assets reais no Debian

## Status objetivo

Código publicado em `feature/v210-authentic-asset-integration-20261020`.
O PR é DRAFT; não considerar testes Godot/visual aprovados sem logs.
As malhas e texturas dos fornecedores são **arquivos locais**, não
estão no repositório público.

## Segurança antes do download

Em 20/10/2026 a pasta Drive fornecida pelo proprietário tinha
**anyone / writer**. Alterar para `Qualquer pessoa com o link: Leitor`
em **Compartilhar → Acesso geral** e verificar arquivos compartilhados.
O script abaixo verifica tamanhos observados no Drive, não assinatura
criptográfica, e jamais executa scripts contidos nos arquivos.

## Pré-requisitos

- Debian, Git e Godot 4.7.2 stable já usado neste projeto.
- Python 3 com `venv`; instalação de Pillow e gdown somente na venv.
- Espaço de disco suficiente para ZIPs originais, cópia otimizada e cache
  do Godot. Não usar automaticamente meshes de 4K do Blender em GT 730.

## Passo a passo

```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/feature/v210-authentic-asset-integration-20261020
# Se a branch já existir localmente:
# git switch feature/v210-authentic-asset-integration-20261020
# git pull --ff-only

python3 -m venv .venv
source .venv/bin/activate
python -m pip install Pillow gdown

mkdir -p /mnt/ows-data/games/ww2-asset-source
python3 tools/download_remaster_drive.py \
  --output /mnt/ows-data/games/ww2-asset-source
```

**Atenção:** os onze ZIPs anexados anteriormente no chat não estão
necessariamente disponíveis no Debian. Coloque seus arquivos originais
`stone_house.zip`, `realistic_tree.zip`,
`realistic_tree_models_for_games.zip` e
`kar98k_mauser_karabiner_98k_bolt_action_rifle.zip` no mesmo diretório
`/mnt/ows-data/games/ww2-asset-source`. Não use ZIPs modificados.

```bash
python3 tools/install_remaster_assets.py \
  --archives /mnt/ows-data/games/ww2-asset-source \
  --texture-size 1024 --runtime-only

python3 tools/install_polyhaven_local.py \
  --archives /mnt/ows-data/games/ww2-asset-source --size 1024

GODOT_BIN="$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64" \
  bash tools/run_remaster_smokes.sh

WW2_REQUIRE_REAL_ASSETS=1 \
 "$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64" \
 --headless --path "$PWD" --script res://tests/v210_real_assets_smoke.gd
```

Se o importador rejeitar um pacote por ausência ou incompatibilidade de
licença, **não contorne a validação**. Verifique a página do autor.

## Conferência visual F5

Inspecionar posicionamento de cada casa, clipping com colisores, troncos
e copas, orientação do rifle alemão em -Z, suporte das mãos e braço
no gatilho, recoil e recarga, ferimentos anatômicos, movimentação tática
e FPS contínuo. O smoke é estrutural e não substitui inspeção visual.
O método atual alinha rifles heurísticamente pela maior dimensão,
não garante orientação historicamente correta sem calibração artística.

## Limitação explícita

O conector ChatGPT do Google Drive aceita arquivos de até 256 MiB
nesta sessão; a French House de ~318 MB e a fortificação de ~647 MB
precisam ser baixadas no host Debian. `modular_fort_01_4k.blend.zip`
fica apenas na staging área: não há integração de fortificação em
tempo de execução aprovada nesta versão.

O projeto não deve ser rotulado como remake visual final enquanto
GLBs, rigs e performance não forem validados no hardware real.
