# TaskMon — rig anatômico 2D

`scripts/creature_motion.gd` reutiliza os atlas canônicos. Não produz novas imagens e não afirma possuir quadros desenhados de caminhada. A malha mantém UVs originais e aplica transformações por região anatômica: torso coerente, cabeça e pescoço, membros com IK de dois segmentos, pés com fase de apoio, cauda e orelhas da raposa, asas em pivôs e apêndices aquáticos/espirituais. Os 15 IDs do catálogo têm idle; ritmos, massa e anatomia variam por espécie.

## Integração

Instanciar uma vez como `preload("res://scripts/creature_motion.gd").new()`. Chamar `begin_frame()` no início de `_draw()`. Aplicar a transformação de posição dos pés antes de `paint(canvas, sheet, source, target, id, time, walking, frozen, tint, action_pose)`. O retângulo local termina em y=0; largura negativa espelha a criatura. O chamador não deve aplicar squash/stretch ou bob adicionais ao sprite. A malha já mantém terrestres no plano de contato e define altura de voo para espécies voadoras.

`tint` inclui alpha, adequado a entrada/saída e flashes. `action_pose` é uma influência assinada para antecipação e lançamento; o chamador sequencia os eventos de combate. `frozen=true` usa desenho direto sem reconstrução do rig. Recursos de malha permanecem vivos entre frames para impedir comandos com RID inválido; buffers dinâmicos são reutilizados por posição de desenho.

O argumento opcional final `animation: Dictionary = {}` mantém compatibilidade com as chamadas existentes. Exemplo: `{"state": "hurt", "age": 0.12, "seed": 3.0, "upright": true}`. `animation_metadata(id)` declara os nove estados `idle`, `stand`, `locomotion`, `attack`, `cast`, `hurt`, `blink`, `appear`, `death`, as durações e o tipo de locomoção das 15 espécies. `sample_animation(id, time, state, age, seed, upright)` retorna uma amostra determinística com pose, deslocamento, rotação, opacidade e fechamento das pálpebras. O estado pode ser amostrado externamente e o próprio resultado passado como `animation`.

Ataque tem antecipação, lançamento e recuperação; cast levanta asas/apêndices e sustenta preparação; hurt recua cabeça/ombros; appear entra por opacidade com assentamento; death perde sustentação e desaparece. Essas transformações são animação de rig e não quadros adicionais desenhados. O chamador conecta os eventos do combate e evita duplicar alpha/deslocamento já aplicado no mesmo evento.

## Regra de postura

**Uma criatura nunca anda sentada.** A pose canônica sentada de Fagulim serve exclusivamente ao idle após parar. A metadata marca `requires_upright_pose`; a malha bloqueia caminhada nessa pose até o chamador selecionar arte em pé e informar `upright=true`. Antes de deslocar ou combater, usar a pose de levantar/standing; ao parar, assentar as patas antes de retornar ao idle sentado. O driver `creature_pose_player.gd` seleciona o novo atlas de poses de Fagulim; os ciclos desenhados dessa espécie não devem ser anunciados como ciclos das outras 14.

Ao desenhar quadros de caminhada já articulados, informar `drawn_walk_cycle=true` para não somar IK a um passo que já está pintado. Arte nova pode fornecer `anatomy` com pivôs/hips/feet normalizados, reutilizando os demais controles do perfil.

Revisão posterior: o usuário rejeitou o ciclo de oito poses a 12 FPS por parecer corrida e destoar da equipe. O modo atual em avaliação usa a pose em pé do frame 0 de `ember-locomotion-v2.png` com rig quadrúpede contínuo: `upright_profile("ember")`, quatro fases de apoio, cadência de 0,90 Hz e elevação de 0,012 da altura. O deslocamento do pé continua sincronizado com o chão de 15,36 px/s. O atlas de 12 poses é preservado para transição, piscada e reação; sua existência não implica usar o flipbook rejeitado para viajar. `upright_eyes("ember")` fornece os dois olhos e amostras de pálpebra calibrados para essa pose.

Pés são alinhados transladando a linha alpha sólida ao plano do chão. Não se comprimem os vértices transparentes inferiores contra o piso: isso distorcia a margem e suspendia a região opaca das patas. A cauda da raposa em pé termina antes da região dos quadris; seu movimento não deve arrastar a coxa traseira.

## Independência por exemplar e feedback

O chamador passa `animation.seed` derivado do ID estável do exemplar, não apenas da espécie. Respiração, asas, cauda, fases do passo e piscadas usam essa identidade para evitar criaturas duplicadas sincronizadas. O deslocamento de fase não altera a velocidade do pé apoiado nem os marcos de ataque/impacto.

`combat_effects.paint` aceita `instance_seed: float = 0.0` como último argumento. Ele altera curvatura, rotação de faíscas, correntes de cura e detalhes da proteção dentro da mesma identidade elemental. Preparação, lançamento e instante do impacto mantêm a cronologia do evento. Um golpe não deve usar relógio global para decidir o resultado ou a quantidade de dano.

`combat_effects.paint_damage(canvas, font, text, pos, age, color, crit=false, font_size=26, instance_seed=0)` desenha números centralizados, contorno escuro, sombra e pop com recuperação curta. Críticos têm tamanho/destaque dourado e uma estrela breve. Passar `font=null` usa PixelifySans canônica para o estilo de combate; fontes fornecidas são respeitadas. O número dura até 1,05 s após o impacto, portanto o chamador não deve descartar o evento logo após 1,1 s desde sua preparação.

## Piscada anatômica e filtro

Cada espécie possui âncoras próprias para os olhos no atlas canônico. As pálpebras são dois caps elípticos convexos sobre a íris, com cor extraída do mesmo material facial da textura e uma linha curta na junção quando fechadas. Não se usa faixa preta genérica sobre o rosto. O arco de fechar/abrir dura 170 ms, com pausas de 3,7–5,4 s e fases individuais; emissivos são ocluídos pela cor do painel/material. Hurt pode semicerrar olhos e death fecha-os progressivamente.

A máscara ignora polígonos degenerados em tamanhos minúsculos. Texturas novas não reutilizam coordenadas de olhos antigos: fornecer `eyes: [{"center": Vector2(u,v), "radius": Vector2(ru,rv), "sample": Vector2(u,v)}]` em coordenadas normalizadas do `source`, ou `blink_enabled=false` enquanto os pontos não forem revisados. O novo atlas de Fagulim pode usar a pose de piscada desenhada em vez da máscara.

Somente as criaturas usam um `CanvasTexture` em cache com filtro linear; mipmaps são selecionados quando disponíveis na textura original. UI, ícones e cenário mantêm seu filtro independente. A textura original permanece a fonte dos pixels de referência, dimensões, UVs e alpha.

Apoio ocupa 62% do ciclo: o pé permanece no chão enquanto recua em velocidade constante. Retorno ocupa 38% e levanta o pé com uma curva suave. `foot_offset` e `profile` ficam expostos para integração futura com velocidade de deslocamento e terreno inclinado. Alpha isolado abaixo da silhueta não determina o contato: o rig detecta a última linha de opacidade consistente. A sombra deve permanecer na origem dos pés.

`stride_for_ground_speed` sincroniza o pé apoiado com o terreno, independentemente da escala do sprite. O padrão `ground_speed=15.36` corresponde à viagem atual (`24 unidades/s × 0,64` do chão); o chamador pode passar um valor assinado em `animation.ground_speed` para deslocamentos de outra velocidade/direção. Caminhada explícita tem prioridade sobre estados neutros `idle/stand` durante formação; ataque/cast/hurt mantêm sua prioridade. O teste verifica a velocidade efetiva de apoio em três escalas.

## Verificação

Executar Godot 4.7.2 com `--path . --script res://tests/creature_motion_smoke.gd --rendering-method gl_compatibility --resolution 1280x800`. O teste renderiza os 15 rigs, verifica apoio no chão e retorno levantado, confere estabilidade de buffers/UV e salva `user://creature-motion-gallery.png`. Render nativo OpenGL validado na GPU NVIDIA RTX 5050 Laptop do computador local. A galeria de 15 rigs simultâneos é um teste de carga, não uma promessa de 60 FPS; o orçamento completo deve ser medido na cena final.

Os argumentos após `--` permitem revisar `--blink` (pálpebras fechadas das 15 espécies), `--blink-sweep` (todos os graus intermediários; sem erro de triangulação) e `--states` (estados de ataque/cast/hurt/entrada/saída). Asserções verificam as nove entradas para cada espécie, limites de alpha, fim da morte/início da aparição e a proibição de caminhada sentada. `tests/creature_eye_calibration.gd` desenha o atlas com grade; `-- --bottom` mostra o trecho inferior para conferir âncoras sem alterar a arte.

`--upright` na galeria de criaturas utiliza a raposa em pé e seu rig quadrúpede; pode ser combinado com `--blink`. `tests/combat_variation_test.gd` verifica que os 15 perfis apresentam pixels diferentes para IDs de atores diferentes no mesmo instante e exibe impacto/números/crítico. O teste de projéteis continua verificando presença real entre origem e alvo.

## Próxima etapa de produção

Uma única pose raster contém pernas ocluídas e não fornece vistas novas para giros de corpo. O rig atual evita deformação global e melhora continuidade, mas não inventa anatomia oculta. A evolução artística recomendada é separar o atlas em peças autorizadas com sobreposição em juntas e desenhar poses laterais/coerentes da mesma criatura para ciclos completos, preservando os assets e as silhuetas aprovadas.

## Runtime nativo de peças autorais — substituição em produção

A abordagem de ilhas extraídas do sprite inteiro da raposa foi rejeitada. Os resultados antigos de largura das patas não aprovam aquela técnica; o teste ampliado também detectou engrossamento da coxa. A montagem vigente deve usar `creature_rig.gd` e `creature_rig_pool.gd` com `assets/rigs/*-parts.png`.

Cada ator possui Skeleton2D, 11 Bone2D e Polygon2D texturizados com malhas de 5×8 células. Pesos misturam apenas a junta adjacente da própria peça. Pernas não compartilham influência com outra perna. O torso permanece coerente; não se deforma o PNG inteiro. As partes são autorais, separadas no atlas, com sobreposição nas juntas. Cabeças idle/blink/cast/hurt usam os desenhos específicos da folha.

Metadados editáveis: `assets/rigs/rig-metadata.json` (Fagulim), `rig-species.json` (iniciais + Broto) e `rig-enemies.json` (inimigos). Coordenadas locais têm pés em y=0 e centro x=0. Rects são `[x,y,w,h]`. `archetype` aceita quadruped/biped/flyer/floater/serpent; `hidden_parts` desativa peças incompatíveis; `source_rects` limita a janela de isolamento por índice; `render_bounds` define o enquadramento. O runtime recorta somente cada peça autoral por alpha dentro dessa janela. Não cria patas recortando um monstro completo.

Fagulim exige linhas próprias `[0,375,640,1024]`: a ilustração 1536×1024 não respeita limites uniformes de 341px. As patas foram calibradas por ponto de apoio da arte e a canela traseira dobra para trás. Escalas dos ossos são unitárias. A marcha tem apoio de64% e retorno de36%, a0,90Hz para15,36px/s; aumentar a velocidade aumenta a cadência, mantendo o comprimento do passo. IK compensa a respiração do torso e a fase de cada exemplar é independente.

Integração: instanciar Pool; chamar `begin_frame(delta,enabled)` no processo; no desenho chamar `paint(owner,actor_key,id,target,animation,tint)`; ao encerrar, `dispose()`. A chave deve identificar o exemplar/contexto, não a espécie. `animation` contém state, seed, ground_speed e opcional age/progress. Retorna false quando falta configuração. O pool mantém SubViewport512×512 transparente por ator, renderiza somente atores usados, desliga render dos demais, libera após120frames e preserva proporção ao ajustar à altura solicitada. enabled=false pausa animações/renderização. O alvo visual continua ancorado nos pés.

Validação nativa até aqui: teste da montagem de7espécies,90frames,11ossos cada; pool com dois atores independentes e flip; cinemática a0,5/1/2velocidade em240amostras cada, erro máximo de apoio0,836px e determinante unitário de todas as canelas. Isso valida cinemática/integração, não constitui aprovação artística final. As15montagens e suas transições ainda exigem revisão visual integrada e análise independente. Não transferir a nota9 da revisão invalidada para este runtime.

Teste complementar GL do rig autoral: `tests/creature_rig_volume_test.gd` isola quatro peças de pernas e mede pixels alpha>0,5 em24fases completas. Variações observadas: coxa frontal0,60%; canela frontal1,23%; coxa traseira0,52%; canela traseira0,73%. Limite de15% respeitado. Área de silhueta e escala dos ossos são medidas distintas: este teste verifica o desenho renderizado, o teste cinemático verifica os apoios. A largura projetada pode variar naturalmente com rotação; não se apresenta área como medição de largura.

Correção de escala validada posteriormente: `ground_speed` é velocidade em pixels do mundo; o pool converte para `ground_speed_local = world_speed × render_bounds.height / target.height`. `speed_factor` controla apenas cadência. Não aumentar cadência novamente por causa da escala do viewport. Novo teste mede deslocamento do apoio frente ao chão em alturas132/240 e velocidades0,5/1/2: erro relativo máximo0,52%, drift máximo0,641px. Repetido teste GL de área na amplitude correspondente à criatura de132px: variação máxima1,87% em24fases. `creature_rig_states_test.gd` passou15espécies×8estados, com cabeças autorais e alpha de aparição/morte.

## Checkpoint para continuidade na nuvem — 15/10/2026

O pipeline nativo acima está implementado e testado em cenas isoladas, mas **ainda NÃO está integrado ao renderer de produção em scripts/main.gd**. O jogo ativo permanece intencionalmente no rig anterior neste checkpoint. Não apresentar screenshots da galeria como prova de integração nem declarar o polimento concluído. A nota9 anterior segue invalidada.

Arquivos de runtime: scripts/creature_rig.gd (Skeleton2D/Bone2D/Polygon2D) e scripts/creature_rig_pool.gd (atores/SubViewports). Arte:15folhas autorais assets/rigs/{id}-parts.png. Configurações: rig-metadata.json, rig-species.json, rig-enemies.json. SubViewports têm tamanho mínimo512px e crescem para comportar as margens das asas/bounds; atores ausentes ficam com render desabilitado e são removidos após120frames. O dono deve chamar dispose ao encerrar.

Últimos resultados locais Godot4.7.2/NVIDIA RTX5050 Laptop/OpenGL: galeria15espécies/90frames/11ossos passou; pool2atores independentes/flip/transparência passou sem erros; estados15×8passaram; deslocamento dos apoios contra chão nas escalas132/240 e velocidades0,5/1/2 passou com erro máximo0,52% e drift0,641px; área das quatro peças de pernas da raposa em24fases passou com variação máxima1,87%. Os testes comprovam funções específicas; não substituem avaliação artística integrada, desempenho de batalha nem teste do executável exportado.

Próximos passos: integrar Pool na produção com fallback explícito; converter corretamente velocidade do mundo para espaço local (já feito dentro do Pool); verificar pés pintados vs bounds por espécie; revisar pequenas lacunas/fragmentos em Thornbud, Shardguard e Rootelder; conferir heads blink/cast/hurt e efeitos na exploração/combate real; medir frame time, restaurar pausa/minimização e confirmar pruning; pedir análise independente após terminar; então reexportar Windows. Algumas configurações de espécies têm bounds terminando y15 apesar do alvo IK y0: avaliar contato visual por espécie antes de mudar a margem. O renderer antigo de ilhas/patas recortadas não recebeu aprovação e deve ser substituído, não anunciado como solução final.
