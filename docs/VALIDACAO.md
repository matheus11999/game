
## TaskMon 0.2 — revisão Windows local

Esta seção substitui o estado visual e de AFK descrito no histórico abaixo.

- 25 testes do servidor passaram no Windows e no container Node24, incluindo idempotência, ownership, loot excedente, custos/limites, presença com jogo aberto, GS, identidade estável da batalha e conclusão de aprimoramento após reinício real do SQLite.
- TypeScript passou com tsc --noEmit.
- Godot4.7.2 importou e executou nativamente com OpenGL Compatibility na NVIDIA GeForce RTX5050 Laptop GPU.
- Revisão gráfica cobriu todas as15 espécies e45 sons, os três cenários ilustrados, mapa, inventário compacto, perfil/conquistas, cards, habilidades e rodapé. O mundo procedural foi testado como experimento e depois rejeitado pelo usuário; ele está desativado.
- UI foi revisada com Inter500, Cinzel, botões contidos e feedback de hover/press. Foco de teclado e estados de comandos durante animação passaram em teste gráfico dedicado.
- Cena real com seis rigs: mediana16.662ms/quadro, p95 16.703ms, CPUmediana8.054ms (90 quadros,15 de aquecimento). Medição pontual neste hardware, não garantia universal.
- Smoke integrado final passou com failures=0: registro, GS, rotas, UI contextual, turnos sem repetir spawn, vitória/loot, início do aprimoramento com materiais, arena, rodapé automático, Escape e conclusão do prazo do aprimoramento.
- Teste gráfico de projéteis detectou pixels visíveis entre emissor e alvo para ataques básicos das seis espécies. Animações de corpo são complementadas por emissão, trajetória, trilha, impacto e recuperação.
- Saves preservados no volume original game_brumora-data; backup anterior à atualização salvo fora do repositório. Sessão do cliente mantém o caminho legado.

A execução de uma animação com rig não cria um conjunto completo de poses desenhadas para cada criatura. Expansões de conteúdo, ciclos desenhados, áudio final produzido em estúdio, balanceamento prolongado e testes de outros hardwares continuam sendo trabalho de produção futuro.

---

# Histórico anterior

# Validação da entrega

## Validação anterior na nuvem Linux — Godot 4.6.3

- Godot 4.6.3 importou os recursos e executou o cliente com renderização OpenGL Compatibility em Xvfb/Mesa.
- Oito testes Node passaram: variação e normalização de atributos; AFK sem duplicação; limite de 8h e coleção; relógio anterior; cura/escudo; combate determinístico e limite de turnos; API real com duas contas, ownership, idempotência e ranking; recuperação do banco após reinício.
- TypeScript verificado com `tsc --noEmit`.
- Smoke test do cliente passou: conexão HTTP, registro e escolha inicial, expedição, intervenção manual, fim de combate, retorno ao mapa, diálogos, ranking, modo rodapé e restauração da janela.
- Foram capturadas imagens reais das telas inicial, exploração, combate e rodapé para inspeção.
- Os templates Godot oficiais foram verificados por SHA-512; o ZIP oficial Node Windows 24.19.0 foi novamente conferido por SHA-256. O executável Node e o template Godot Windows foram inspecionados como PE x64.
- O launcher passou por simulação de ciclo de vida em Linux, com servidor HTTP e processo de jogo de teste: pasta com espaços; encerramento do servidor próprio após o jogo; limpeza após falha ao abrir o jogo; rejeição de segundo launcher com servidor automático; dois clientes com servidor iniciado separadamente; recuperação de lock com PID encerrado. Essa simulação não executa o jogo nem os arquivos `.bat` no Windows.
- O empacotador usa uma pasta temporária nova, inclui os catálogos JSON exigidos pelo servidor, as licenças das fontes, `AGENTS.md` e a direção de arte. A exclusão de `.env`, bancos, arquivos WAL, logs e caches foi conferida. Sintaxe do Python e do launcher Node validada.

## Atualização para Godot 4.7.2

A revisão final usa Godot 4.7.2, igual ao editor local do usuário, e está fixada em `.godot-version`. Os itens anteriores preservam o histórico da validação com 4.6.3.

- Quinze testes do servidor passaram, e a verificação TypeScript passou.
- Importação e execução com OpenGL Compatibility, Xvfb e Mesa/llvmpipe passaram. Cenários regionais e efeitos de combate foram exercitados sem erros de script. O driver virtual avisou que não suporta alterar V-Sync; isso não impediu os testes.
- O smoke test final terminou com `failures=0`: conexão, inicial, atributos, expedição, inimigo com atlas próprio, intervenção e efeitos por criatura, conclusão da batalha, retorno à exploração e ranking. A regressão de clique no ranking durante uma consulta automática também passou: o comando enfileirado é executado após a consulta.
- O modo rodapé iniciou e venceu automaticamente um encontro, avançou a caravana no servidor, encerrou o resultado e retomou a viagem. A janela normal foi restaurada.
- Foram capturadas telas reais da seleção, expedição, batalha e rodapé desta revisão.
- A entrega Windows é exportada com os templates oficiais 4.7.2. O empacotamento verifica PE x64 e o ZIP inclui runtime Node, catálogos JSON, licenças das fontes e instruções de continuidade local. A execução nativa no Windows continua pendente.

## Servidor Docker validado na nuvem

- Docker Engine 28.4 construiu as imagens de runtime e testes a partir do `Dockerfile`, com Node 24.19.0 e imagem base fixada por digest.
- `docker compose up --build -d` iniciou o serviço, que atingiu estado saudável. O HTTP foi acessado pelo host em `127.0.0.1:8787`.
- Os quinze testes passaram dentro do container de testes.
- Registro de conta, início de expedição, encontro com inimigo próprio e turno com eventos de combate passaram pela API do container.
- O volume nomeado mantém os dados separados do código. Esses resultados usam containers Linux na nuvem; o Docker Desktop e o cliente Godot no Windows ainda precisam do teste local.

## Limitações e próximos testes

O ambiente de execução é Linux. O pacote Windows é exportado e sua estrutura conferida na nuvem, mas execução nativa de `.exe`/`.bat`, compatibilidade com drivers Windows, assinatura, DPI, multi-monitor e desempenho no computador do usuário ainda precisam ser validados. Builds Android/iOS, autenticação Steam, amigos Steam e PvP ao vivo não foram implementados nem testados.

60 FPS é o alvo configurado para deslocamentos e efeitos; não há benchmark em Windows. O atlas é um primeiro conjunto de pixel art com animações curtas; a direção visual gerada não deve ser confundida com um conjunto completo de animações finais.

A interface e o backend são de MVP. O ranking é local, sem temporadas ou proteção completa contra abuso de contas. O backend aceita HTTP apenas no loopback por padrão e não deve ser publicado diretamente; hospedagem requer HTTPS, autenticação recuperável e revisão de produção.

O banco, sessões e contas usados nos testes não são incluídos no ZIP distribuído. O launcher automático reserva uma única janela para manter o ciclo de vida do servidor previsível; para testar dois jogadores, abrir `Iniciar-Servidor.bat` primeiro e depois executar `Iniciar-Brumora.bat` em duas janelas. Fechar essas janelas não encerra o servidor iniciado manualmente. A pesquisa atual de concorrentes e disponibilidade da marca/domínios continua limitada pelos bloqueios de rede documentados no plano.


## Revisão de HUD e retomada — 14/10/2026
Godot 4.7.2: import sem erros e visual_review com failures=0 após revisão de botões, título, GS, HP e efeitos. Capturas forçam redesenho antes da leitura do framebuffer. Teste de retomada usa GET /api/state no resultado persistido e aciona o sinal pressed do botão ContinueBattle, verificando retorno à exploração. O erro histórico relatado no editor não apareceu nos logs disponíveis nem no teste atual; não atribuir causa sem evidência. Limpeza de animações foi reforçada ao carregar/encerrar batalhas.


## Revisão final — jornada persistente e arte de folhagem
40 testes autoritativos do servidor no Docker, typecheck, e 58 verificações do UI smoke integrado passaram. UI smoke terminou sem falhas, erros, avisos ou vazamentos de recursos após drenagem do áudio no teardown. O teste nativo/HTTP de expedição confirmou desgaste de HP mantido entre encontros, retorno com resumo real, moeda com três casas, ícones canônicos e feedback. Wipe contra chefe real encerrou a jornada e expandiu o rodapé para exibir o resumo. Nenhum crédito de XP/moedas por ticks.
Velocidade visual: 12 pares de escala/aceleração comprovaram o recuo do pé na velocidade do chão, sem multiplicar aceleração duas vezes. Índices/corte de poses, 15 estados de rig por espécie, variação de VFX por exemplar, projéteis e 540 recortes de câmera aprovados. A raposa usa rig quadrúpede contínuo; oito poses anteriores de caminhada são referência preservada, não o ciclo ativo.
Fonte atual TaskMon-Interface (Alegreya Sans SC Medium OFL), sem fallback de sistema, Cinzel nos títulos. Revisão final independente em DESIGN_REVIEW.md; notas são avaliação interna do recorte observado, sem garantia universal de desempenho, hardware ou plataformas. Builds e backups preservam a pasta/volume legado de saves.
