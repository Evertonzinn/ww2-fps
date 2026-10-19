# WW2 FPS v0.6.4 — BoltAssemblyVisual

## Evidência
- Godot encontrou quatro malhas candidatas na v0.6.3, mas o usuário confirmou que a arma mexia e o ferrolho não.
- O GLB original tem 44 meshes, 8.497 triângulos e nenhuma animação ou rig.

## Correção experimental
- Substituímos a tentativa de mover quatro malhas genéricas por um conjunto mecânico explicitamente separado.
- Coberturas antigas só são ocultas se as quatro malhas estiverem presentes.
- Um BoltAssemblyVisual com corpo metálico, colar, haste, curva e maçaneta é criado ao lado do receptor.
- BoltSlide recua 86 mm e BoltLockRotation gira 0,93 rad (~53°) em 4 fases.
- O tempo de ciclo foi aumentado para 0,80 segundo para ser observado no teste.
- A animação do rifle, recarga automática, disparo, ADS, menu 4K e mudança 1K/2K permanecem.
- A fonte do GLB (CC BY 4.0) não foi alterada; o mecanismo é geometria original provisória.

## Limitações
- Não é ainda o ferrolho histórico extraído do modelo. Precisa de preparação do asset no Blender para arte final.
- O ponto de encaixe está estimado por bounding boxes; ajustar LOCATION após screenshot no Godot.

## Teste mínimo
1. Rodar Godot --headless --editor --path . --quit; sem erro de parsing.
2. Em F5, conferir o log: BoltAssemblyVisual: bolt body, handle and knob created.
3. Uma vez disparado, identificar alavanca levantando, voltando, avançando e travando de forma independente.
4. Testar quinto tiro: recarga automática após operação do ferrolho; HUD de 5/25.
5. Esc / resolução / V-Sync / texturas 1K e 2K; sem mecanismos duplicados após troca.
6. Testar ADS, impactos, reserva vazia e estabilidade de FPS.
Não mesclar na main antes dos testes visuais. Se preferir a versão anterior, voltar à feature/v063-lee-enfield-bolt-action.