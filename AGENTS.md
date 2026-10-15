# Brumora: persistent project direction

Read `docs/ART_DIRECTION.md` and `docs/PLANO.md` before changing visuals or game systems.
For cloud continuation, first read `docs/CLOUD_HANDOFF.md`: it records the current checkpoint, unfinished rig integration, user decisions and verified tests.

- This is a native Godot creature game, not a web dashboard. Preserve an immersive world, fantasy HUD, and consistent creature identities.
- The user rejected the simple 32px placeholder creatures and card-dashboard presentation. Use the approved detailed creature atlas and regional backgrounds. Do not regenerate placeholders over detailed production art.
- Art changes must preserve each creature's silhouette, material colors, expressive face, and relative scale. New assets should match the reference sheets, with transparent backgrounds for sprites.
- Animate movement, attacks, damage, healing, and shields smoothly. Keep pixel art crisp. Minimize visual work while the window is minimized.
- Windows x64 and a local server are the first delivered platform. Use the same Godot gameplay project for later desktop/mobile exports, with platform-specific adapters and UI adjustments.
- Godot is pinned to4.7.2 in `.godot-version`. The user has Docker Desktop: prefer `docker compose up --build -d` for the localserver and `docker compose --profile tools run --build --rm test` for server tests.
- Keep game authority on the TypeScript server. Never trust client-supplied rewards, stats, elapsed time, or battle outcomes.
- In the MVP, PvP means asynchronous battles against another account's saved defense. Do not describe it as live multiplayer or Steam friend integration.
- Run meaningful server tests and type checking after server changes. Use the client smoke test after UI/network changes. Re-export the Windows ZIP after changes intended for the delivered build.
- Package no development databases, tokens, credentials, logs, caches, or node_modules. Include third-party licenses and identify untested platform behavior honestly.
- Preserve the user's files and progress. Do not reset databases or profiles without a specific request.

## TaskMon — direção atual
- Leia docs/TASKMON_PLANO.md e docs/ASSET_REGISTRY.md antes de editar sistemas ou gerar imagens. Reutilize os assets canônicos dos itens; preserve a identidade entre gerações.
- XP vem de jogo; aprimoramento por materiais exige tempo persistente no servidor (60 * grau-alvo ao quadrado segundos), sem compra de XP.
- Inventário inicia com 4 tipos de materiais; excedentes vão para loot pendente. Não descartar itens.
- Marca atual: TaskMon. Caminhos legados de salvamento devem ser preservados para migração sem perda.


## Prioridade visual e UX atual
- O usuário rejeitou os terrenos totalmente procedurais. O cliente deve usar world_painter.gd, world-forest/coast/ruins.png e ground-taskmon.png. Não reativar procedural_world.gd automaticamente.
- UI: TaskMon-Interface (Alegreya Sans SC Medium) para leitura; Cinzel para marca/títulos; ícones com tooltip para mochila, perfil e ações secundárias. Evitar textos e ornamentos repetitivos.
- Movimento: rig anatômico, passos ancorados, projétil separado do corpo e impacto sincronizado. Não chamar uma translação do PNG de animação de lançamento completa.

## Leis de animação e apresentação (pedido do usuário)
- Toda criatura deve possuir estados de repouso, locomoção, ataque básico, reação a dano, conjuração de habilidade, piscar, aparição e morte. Ciclos devem respeitar anatomia, apoio e identidade; registrar limitações de arte ainda não produzida.
- É proibido locomover uma criatura em pose sentada. Espécies que sentam só podem fazê-lo em repouso; levantar antes de andar ou entrar em combate, sentar após parar. Voadoras mantêm lógica de voo própria.
- Botões têm acabamento suave, sem degraus excessivos; ícones sem texto ficam exatamente centralizados. A equipe exibe slots limpos; atributos e aprimoramento ficam na carta aberta ao clicar.
- Câmera mais afastada na exploração e próxima no combate, com transição suave; sprite filtrado para não serrilhar em escala fracionária. Rotas iniciam encontros automaticamente por padrão, com pausa explícita.


## Regras vigentes de jornada, papéis e identidade (substituem descrições anteriores)
- XP E moedas somente por inimigos abatidos; nenhum crédito por passagem de tempo. Custos e recompensas autoritativos; moeda em milésimos, UI com até três casas decimais.
- Vida persiste entre encontros da mesma expedição. Nível/aprimoramento não curam nem ressuscitam. Wipe encerra jornada; retorno manual também gera resumo de tempo, abates, batalhas e ganhos reais.
- Atacantes: habilidades e atributos voltados a dano; tanks: defesa/proteção; suporte: cura ou apoio. Validar coerência por testes antes de acrescentar espécies.
- Exploração sem cards de equipe. Nome e nível juntos; olho abre carta. Encontro no próprio cenário, sem troca de cena, equipe para e batalha inicia.
- Tipografia atual: TaskMon-Interface.ttf (Alegreya Sans SC Medium licenciada OFL) para toda UI/corpo/dano, Cinzel para títulos. Sem Arial/SystemFont/fallback do sistema. Esta escolha substitui Inter como fonte ativa.
- Direção conceitual: fantasia de folhas/folhagem, ouro e jade; molduras consistentes e fundos ilustrados nos menus. Ícones coin/xp/eye são assets canônicos. Não usar orb para representar moedas, pois orb é Pérola.
- Passadas e mapa compartilham travel_speed e world_speed_multiplier; não aplicar velocidade duas vezes. Raposa quadrúpede usa rig contínuo a 0,90 Hz, alinhado ao chão; não usar ciclo acelerado com aparência de corrida.

## Animação — decisão vigente de produção
- O usuário rejeitou patas recortadas do PNG inteiro e articulações com aparência de papel. Não recomendar nem ampliar esse atalho como solução final.
- Produzir peças anatômicas desenhadas com superfícies ocultas e sobreposição nas juntas; montar rigs nativos editáveis com Skeleton2D/Bone2D e malhas com pesos. Preservar identidades dos atlas canônicos.
- Validar a criatura montada em movimento, além da folha de arte: volume, juntas, silhueta, apoio dos pés, piscar, idle e transições. Nenhum método garante ausência automática de erros; registrar limitações e corrigir a evidência observada.
- Movimentos contínuos, antecipação e recuperação de ataques; voadoras e criaturas sem patas usam anatomia própria. Não converter o simples avanço do PNG em suposta animação completa.
