# TaskMon — memória de continuidade local → cloud

Checkpoint de 15/10/2026, solicitado pelo usuário para continuar em cloud. Repositório: `matheus11999/game`, branch `main`. Projeto nativo Godot; não converter em site. Este arquivo é estado de trabalho, não uma aprovação de qualidade final.

## Primeiro passo na próxima sessão

Ler `AGENTS.md`, este arquivo, `ART_DIRECTION.md`, `ASSET_REGISTRY.md`, `TASKMON_PLANO.md` e `CREATURE_MOTION.md`. Preservar o histórico de decisões abaixo. Conferir o código antes de assumir que o planejamento antigo descreve o estado atual. O projeto mudou de Brumora para TaskMon, mas caminhos de dados legados foram mantidos.

**Próxima tarefa prioritária:** integrar o novo rig nativo de peças autorais ao renderer de produção, calibrar as quinze criaturas em movimento, corrigir fragmentos/encaixes e só então rodar análise sênior independente de design/UX/feedback/animação. O usuário pediu agentes especialistas e revisão de 0 a 10 com correções até atingir qualidade 9. A nota anterior 9 foi invalidada por defeitos reais; não copiá-la nem dar nota por passar testes técnicos.

## O que o usuário acabou de pedir

- Animações bonitas, contínuas, sem ficar estático; rejeitou patas da raposa grossas, parecendo papel, cortadas e a locomoção sentada/correndo.
- Parar de propor recortes de um PNG inteiro como solução final. Redesenhar peças das criaturas existentes e usar sistema articulado escalável, preservando a identidade visual.
- Corrigir ícones de menus recortados e descentralizados.
- Enviar código e memória ao GitHub para continuar o trabalho na cloud em breve. Não solicitou levar banco, credenciais ou sessão local.

## Estado real de animação: importante

**Produção ainda usa `scripts/creature_motion.gd` dentro de `scripts/main.gd`. O novo pipeline NÃO foi conectado ao renderer principal neste checkpoint.** Isso foi deixado explícito para evitar entregar a integração sem a revisão visual necessária.

Novo pipeline já produzido/testado:

- `scripts/creature_rig.gd`: Node2D, Skeleton2D, onze Bone2D, Polygon2D com pesos entre juntas adjacentes; cadeias independentes, apoio IK, cabeça/cauda/asas, estados e transições.
- `scripts/creature_rig_pool.gd`: pool de SubViewport transparente por ID de ator; evita clones sincronizados, controla atualização e descarta atores antigos. Tamanho aumenta conforme bounds, evitando cortes de asas.
- `assets/rigs/{id}-parts.png`: quinze folhas de peças autorais redesenhadas com superfícies ocultas e sobreposição nas juntas. Não são membros extraídos do atlas completo. Referências originais preservadas.
- `rig-metadata.json`: Fagulim/ember; `rig-species.json`: moss, luna, tide, crag, cloud, thornbud; `rig-enemies.json`: pebblebug, reefclaw, tidejelly, runewisp, shardguard, rootelder, abyssmaw, moonwarden.
- API: criar Pool; chamar `begin_frame(delta, enabled)` em `_process`; `paint(owner, actor_key, species_id, target_rect, animation, tint)` no desenho retorna bool; `available(id)` e `dispose()`.
- `animation`: state (`idle`, `locomotion`, `attack`, `cast`, `hurt`, `blink`, `appear`, `death`), seed estável por exemplar, ground_speed em pixels do MUNDO por segundo, speed_factor opcional, age/progress para repetir eventos corretamente. Pool converte velocidade para espaço local conforme tamanho de desenho; fase recebe fator uma vez.
- Não duplicar o antigo walk_clock na velocidade do novo rig. Cadência e comprimento de passada precisam acompanhar o mapa. Quadrúpedes, bípedes, voadores, flutuantes e serpente usam arquétipos diferentes.
- Fox possui row_edges específicos; nem toda folha é uma grade perfeitamente quadrada. Reutilizar source_rects/metadata, não assumir dimensões uniformes entre espécies.
- Prompts completos e ferramenta usada: `docs/ART_PROMPTS_PARTS.md`. Foi usada imagegen embutida. `assets/art-manifest.json` registra hashes para consistência.

Pendências já vistas na galeria: pequenos fragmentos em Espinbroto/thornbud, pé parcialmente separado em shardguard, peças de braço/perna em rootelder; revisar source_rects e encaixes. Conferir também proporção e material nas juntas de todas as espécies e o contato visível do pé pintado, não apenas o alvo IK matemático. Imagem de galeria não aprova movimento. Depois de integrar, medir custo/performance, minimizar janela, limpar pool e verificar ausência de leaks.

Integração deve preservar: antecipação → emissão de projétil independente → impacto → recuperação, danos/sons/HP sincronizados, estados de dano, cast, escudo e cura. Não voltar a transladar só o PNG e chamar isso de ataque animado. Usar os estados do novo rig nos eventos existentes de `_paint_fighter`; aposentar o caminho antigo quando a alternativa estiver validada.

## Correções recentes já ativas no cliente

- `world_painter.gd` voltou aos panoramas ilustrados; fonte do panorama recorta a parte superior e exclui o chão pintado. Só `ground-taskmon.png` forma o piso. Zoom-out não deve mostrar duas plataformas. Nunca reativar o experimento `procedural_world.gd` automaticamente.
- `encounter_director.gd`: viagem → aproximação por 2,2 s/52,8 unidades → engage/zoom/VS → combate → disengage suave. Inimigos visíveis durante aproximação, comandos bloqueados até terminar. Cenário permanece o mesmo.
- Mundo ampliado na exploração, zoom suave no combate; progressão visual interpolada sem saltos por polling.
- `_paint_unit_hud`: nome + `lvl N`, tipografia/HP idênticos na viagem e combate; removeu “Encontro selvagem”. Espaçamento inimigo156px, barras148px, sem sobreposição; nomes longos diminuem fonte para manter nível visível.
- Ícones: `_button`, `_decorate_button`, `_modal_button`, `_image_control` corrigem padding, estados, escala, filtro e alinhamento. Olho28px usa ícone16px com respiro; fechar36px tem ícone26px. Mesmos bounds em hover/pressed/focus/disabled.
- `menu_chrome.gd`: cartas, inventário compacto, resumo de expedição, emblema GS e barra de progresso compartilham molduras botânicas, medalhões e fundos ilustrados. Ainda sujeitos à avaliação do usuário e à análise final.
- `assets/ui/{hero-leaf,stat-leaf,gear-leaf,progress-vine,progress-satin}.svg` são vetores canônicos. Não substituir por caixas básicas.

## Leis permanentes de design e arte

- Fantasia coesa: folhas, ouro envelhecido e jade, fundo ilustrado e molduras; mundo em destaque, pouca redundância textual. Ações secundárias por ícone com tooltip.
- Fonte de interface: TaskMon-Interface.ttf (Alegreya Sans SC Medium, OFL). Cinzel para marca/títulos. Sem Arial/SystemFont/fallback do sistema.
- Preservar identidades/silhuetas/cores dos quinze monstros. Toda criatura precisa idle, andar/voar, ataque, dano, cast, blink, aparição e morte. Proibido andar sentada. Espécie que senta deve levantar antes de locomover e sentar só ao parar.
- Passadas ligadas a travel_speed e world_speed_multiplier; acelerar mapa deve acelerar caminhada sem aplicar fator duas vezes. Clones têm fase/efeito por exemplar.
- Não mostrar cards de equipe durante expedição; usar nome, nível e olho para abrir carta detalhada. Atributos só na carta, por ícones; categoria com ícone + Atacante/Tank/Suporte.
- Itens reutilizam os mesmos assets. Moeda=coin.svg; XP=xp.svg; eye.svg inspeção. Orb é Pérola, nunca substituir moeda por orb.
- Atacante tem habilidades/atributos de dano; tank de defesa/proteção; suporte de cura/apoio. Servidor e testes preservam esta coerência.

## Sistemas autoritativos já implementados

- Servidor TypeScript/Node24/SQLite; cliente não decide prêmios, tempo ou atributos.
- XP e moedas SOMENTE de inimigos abatidos; tempo de viagem/ticks não paga. AFK exige jogo aberto/conectado, presença com tolerância de oito segundos; sem farm offline.
- XP de abates creditada ao concluir batalha, participantes apenas, reservas excluídas; treino sem XP/loot. Prêmios idempotentes, abates parciais preservados. Balanceamento inicial deliberadamente lento, ainda sujeito a playtest.
- Moedas em milésimos inteiros, API decimal, UI até três casas (ex.:0,001). Não arredondar saldo para inteiro.
- HP persiste em expedition.hp por exemplar entre encontros. Subir nível/aprimorar não cura nem revive. Nova jornada cura uma vez; wipe encerra expedição. Treino/PvP usam HP isolado.
- Retorno manual, wipe ou troca de rota geram last_expedition_summary persistente com tempo, abates, batalhas, moedas, XP real por exemplar e materiais. Modal apenas apresenta; não paga novamente.
- Inventário inicia com quatro TIPOS, empilhamento por tipo, expansão+2 por moedas até20; excedentes ficam pendentes, nunca descartados.
- Aprimoramento separado do nível: materiais+moedas, graus0–10, tempo60×grau-alvo² segundos salvo no servidor e continua offline; melhora atributos/passiva/ativa. Sem compra de XP.
- GS, mapas com arte/estrelas/GS recomendado, perfil, conquistas. PvP é assíncrono contra defesa salva e normalizado; primeiras cinco vitórias/dia UTC dão prêmios. Não é multiplayer em tempo real nem integração Steam.

## Execução e testes na cloud

Node24+: `npm ci --prefix server`, `npm test --prefix server`, `npm run typecheck --prefix server`. Com Docker: `docker compose up --build -d`; `docker compose --profile tools run --build --rm test`.

Godot fixado em4.7.2 (`.godot-version`), renderer Compatibility. Importar: `godot --headless --path . --editor --import`. Testes GDScript: `godot --headless --path . --script tests/NOME.gd`; testes gráficos de alpha/captura precisam renderer real (OpenGL/Xvfb na cloud), não confiar em imagem do renderer headless. Adaptar apenas paths locais de captura/CLI, sem mexer nas regras de produto.

Os smokes HTTP `ui_smoke.gd` e `expedition_ui_smoke.gd` apontam EXCLUSIVAMENTE a127.0.0.1:18787, seção de sessão isolada e _save_settings noop. Antes de executar, subir servidor QA em memória: `node --input-type=module -e "import {createGameServer} from './server/index.ts'; createGameServer({dataPath:':memory:'}).listen(18787,'127.0.0.1');"`. Nunca usar conta real em fixture.

Verificado neste Windows/Godot4.7.2/RTX5050 antes do checkpoint:

- Servidor:40 testes+typecheck passaram.
- UI smoke integrado:59 verificações, zero falhas, incluindo wipe real/HP/resumo/aprimoramento.
- Expedition UI smoke:zero falhas,~18s.
- Ícones:466 verificações, zero falhas e capturas nativas.
- Encontros:39 verificações+18capturas nos três biomas; diretor44 verificações.
- Câmera/chão:540 verificações; visual_review sem falhas.
- Novo rig:15espécies×8estados, galeria90quadros; pool dois atores independentes; apoio132/240px em0,5/1/2× com erro relativo≤0,52% e drift≤0,641px; área renderizada das quatro partes de patas fox varia no máximo1,87% em24fases. Estes testes NÃO substituem a integração e a revisão artística.

Depois da integração, rerodar testes relevantes e capturas do jogo real, depois especialista independente de design; corrigir evidência sem inflar nota. Reexportar Windows quando houver build de entrega: templates4.7.2 oficiais + runtime NodeWindows verificado, variáveis GODOT_BIN/NODE_WINDOWS_EXE, `python tools/build_windows.py`. Não anunciar ZIP anterior como contendo integração ainda pendente.

## Dados locais: não pertencem ao Git

Local original: `D:\APPS\game`. VolumeDocker `game_brumora-data`, banco em `/app/server/data` no container; preservar. Nunca executar `docker compose down -v`. Cliente usa `%APPDATA%/Godot/app_userdata/Brumora — MVP/connection.cfg`; contém chaves e não foi enviado. Backups estão fora do repo, em AppData/Local/Brumora/backups. A cloud terá ambiente/dados de teste próprios; não deduzir que progresso real foi migrado.

Capturas/ZIP/logs/caches ficam fora do versionamento. Memória persistente é documentação no repositório; agentes e memória transitória de conversa não viajam automaticamente. A automação de computador foi interrompida por Esc do usuário; não retomar cliques sem nova solicitação em sessão apropriada.
