# v0.6.2 — Lee-Enfield: ciclo visual das peças da ação

## O que foi inspecionado

O asset fornecido pelo usuário contém 44 malhas / 8.497 triângulos. A arma está dividida em meshes com nomes não semânticos e **não possui animações**. A análise geométrica local apontou três malhas pequenas na parte superior do receptor como *candidatas* a componentes móveis:
- `Cube.009_Low`
- `Cube.010_Low`
- `Circle.001_Low`

**Isso não prova que todas sejam o ferrolho correto.** A identificação precisa exige inspeção no Blender. A v0.6.2 introduz um teste visual **experimental**, e não afirma oferecer uma animação histórica de ferrolho fiel.

## Implementação

- `weapon_bolt.gd` localiza apenas três malhas candidatas pelo nome, sem editar o GLB original.
- Cria movimento pequeno de recuo e avanço (75 mm) durante os 0,44 s seguintes ao disparo.
- Converte o deslocamento em metros para o espaço local de cada nó, apesar das transformações grandes herdadas do glTF.
- Ao alternar texturas 1K/2K, restaura os offsets originais, libera referências antigas e se associa ao novo modelo.
- Sem o GLB ou caso os nomes sejam distintos na importação, o rifle mantém a animação anterior do viewmodel, sem falhar.
- Nenhuma alteração em tiro, auto-recarga, HUD, menu gráfico ou controles.

## Teste no Debian

```bash
cd /mnt/ows-data/games/ww2-fps
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
```

No Godot:
1. Validar ausência de erro vermelho no Depurador.
2. Atirar com o rifle e observar a região do receptor/ferrolho; conferir se a geometria não se deforma nem atravessa a coronha.
3. Checar console para `visual bolt cycle bound to ...`. Se aparecer aviso sobre candidates not found, o GLB importado não corresponde aos nomes previstos e o código mantém fallback.
4. Alternar texturas 1K e 2K no menu e repetir o disparo.
5. Testar recarga automática do quinto tiro, munição reserva, ADS, V-Sync e pausa.
6. Testar 60 segundos de FPS e comparar com a v0.6.1.

## Critérios para merge

- Não mesclar se qualquer uma das três malhas se deslocar incorretamente.
- Não declarar animação real do ferrolho pronta até o Blender confirmar e isolar a peça correta.
- A `main` continua estável enquanto os PRs são validados.
