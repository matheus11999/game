# TaskMon — animação nativa de peças autorais

## Pipeline ativo

O renderer de produção em `scripts/main.gd` usa `creature_rig_pool.gd` e `creature_rig.gd`: Skeleton2D, onze Bone2D e Polygon2D com pesos, peças desenhadas separadamente e sobreposição nas juntas. `creature_motion.gd` e os antigos flipbooks permanecem referências históricas e testes isolados; não são o backend ativo. Não restaurar o recorte de membros do PNG inteiro.

O pool recebe `begin_frame(delta, enabled)` em `_process`, e `paint(owner, actor_key, species_id, target, animation, tint)` no desenho. Uma chave estável `world:<id do exemplar>` acompanha exploração, batalha e rodapé; `card:<id>` e `preview:<espécie>` têm relógios independentes. `dispose()` libera os SubViewports ao sair. Atores sem uso são descartados após 120 ticks. Cada ator avança uma vez por tick, mesmo com múltiplos desenhos; janelas ocultas/minimizadas não avançam o rig. Primeira imagem pode ser renderizada mesmo pausada para evitar um quadro transparente.

## Arte e coordenadas

`assets/rigs/{id}-parts.png` tem doze peças isoladas, quatro colunas e três linhas lógicas. `rig-metadata.json`, `rig-species.json` e `rig-enemies.json` definem pivôs, retângulos de destino, crops e limites de renderização. Não assumir células uniformes: usar `row_edges`/`source_rects` quando necessário. Partes são normalizadas independentemente na folha; a proporção final é definida no metadata e deve ser inspecionada montada.

`faces_left` informa orientação da arte fonte (padrão direita, exceção atual Espinbroto). `_sprite(... flip)` recebe a direção desejada: true=esquerda. Espelhamento e origem do projétil consideram a mesma orientação fonte; não deduzir orientação do atlas antigo de inimigos. Larguras negativas são centradas usando a largura absoluta. O chão é o ponto local y=0, inclusive com padding abaixo dele.

## Movimento e estados

Fagulim usa quatro apoios, cadência de 0,90 Hz e velocidade base de 15,36 pixels de mundo/s. `ground_speed` é assinado; o pool converte para pixels locais conforme a altura de renderização e o espelhamento. `speed_factor` entra uma vez na fase, sem repetir o multiplicador de viagem. Apoio deve acompanhar o chão; conferir tanto IK quanto a linha opaca pintada das patas. Nunca andar sentado.

Estados de produção: idle, locomotion, attack, cast, hurt, blink, appear e death. Cabeças neutral/blink/cast/hurt são desenhos distintos; corpo, membros e cauda usam animação do rig. Ataques têm antecipação e recuperação procedurais; ainda não são ciclos desenhados exclusivos de cada espécie. Projéteis e impactos são efeitos separados. Linha temporal atual: lançamento 0,27 s; impacto/dano/hurt 0,81 s. O muzzle segue a cabeça articulada. `external_alpha=true` deixa aparição/morte sob a opacidade do combate, evitando multiplicá-la duas vezes.

Para este estilo, a técnica adequada é híbrida: rig para movimento contínuo, poses autorais para expressões/ataques especiais, efeitos separados. Itens de interface simples usam AnimationPlayer, tweens ou shaders; não precisam de esqueleto. O rig não garante qualidade por si só: volume, juntas, silhueta e transições exigem revisão visual.

## Redesenho solicitado em 15/10/2026

O usuário rejeitou a aparência de raposa comum e pediu um monstro. Fagulim passa a ter folhas carbonizadas/jade com veios de brasa, patas com dedos claros, orelhas em folha e cauda de semente flamejante. Referência única: `assets/ember-taskmon.png`; peças: `assets/rigs/ember-parts.png`. A substituição de identidade é explicitamente solicitada, mas aprovação artística final continua com o usuário. Preservar as outras espécies.

## Verificação

- `tests/creature_rig_kinematics_test.gd`: apoio e velocidade do chão.
- `tests/fox_rig_contact_test.gd`: velocidades assinadas, linha opaca das patas distantes (renderizador real).
- `tests/creature_rig_volume_test.gd`: variação de área de membros durante 24 fases (renderizador real).
- `tests/creature_rig_states_test.gd`: oito estados das quinze espécies.
- `tests/creature_rig_pool_test.gd`: lifecycle, pausa, espelhamento, alinhamento e limpeza.
- `tests/rig_production_integration.gd`: cliente real com servidor QA isolado em memória na porta 18787; viagem, combate, rodapé e estados, capturas gráficas.

Passar testes técnicos não aprova a arte. Minimização real requer gerenciador de janelas/Windows; Xvfb sem WM não permite validar esse comportamento de plataforma. Revisar também as outras espécies: há pendências conhecidas de peças/encaixes em Espinbroto, shardguard e rootelder.

## Postura experimental: sentar e levantar

`creature_rig.gd` também oferece estados explícitos sit/rise para Fagulim, `sit_blend` público e bloqueio das passadas até estar em pé. `_party_is_seated()` impede o avanço local do cenário até terminar de levantar. Entretanto, as peças atuais em pé e o torso rígido único produzem agachamento; isso não foi aprovado como sentar convincente. **A produção não habilita auto-sentar.** A API allow_sit exige também metadata.seated_pose_approved=true, ausente no metadata real. Não ativar sem novas peças de torso/quadril sentado ou subrig de coluna e revisão visual. O teste creature_rig_posture_test.gd valida o contrato técnico experimental, não aprovação artística. Combate imediato/restaurado força postura em pé para preservar cronologia de impacto; aproximação normal permite levantar animado.
