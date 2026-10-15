# Plano do jogo — 14 de outubro de 2026

## Estado desta entrega: MVP implementado

O primeiro alvo é Windows x64 com servidor local, conforme pedido. Há cliente Godot nativo, sprites, animações, terrenos, três rotas, sistema de atributos, raridades, combate, progressão AFK, arena assíncrona e persistência. A implementação usa Node 24 com HTTP nativo, TypeScript e SQLite; não exige Fastify ou PostgreSQL para o teste local. O pacote inclui runtime do servidor e inicializador. Builds mobile, integração Steam e PvP ao vivo são próximos marcos, não funcionalidades já entregues.

As exportações Windows foram preparadas na nuvem Linux; execução nativa e consumo no seu computador precisam de teste. Não há garantia de desempenho, viralização, aprovação das lojas ou disponibilidade de marca.

## Decisão proposta

Criar um jogo 2D de criaturas originais em pixel art, com expedições AFK, pequenas intervenções táticas, PvE manual e desafios PvP. Desktop primeiro, com experiência compacta no rodapé; Android e iOS com interface adaptada e progresso calculado ao retornar. O objetivo é uma produção acessível à assistência de IA, com poucas tecnologias e entregas pequenas verificáveis.

O produto será um aplicativo nativo em Godot, não um jogo dependente de navegador. TypeScript será usado no servidor, sem exigir uma interface web. Uma implementação web encapsulada poderia ser avaliada em outros projetos, mas não é a escolha deste planejamento. A engine fornece renderização, animação, áudio, entrada, cenas e exportação; não fornece automaticamente a direção de arte ou o serviço multiplayer.

Este documento é planejamento, não uma implementação ou prova de viabilidade comercial. Não existe evidência suficiente para prometer viralização. Nenhum nome ou domínio abaixo está confirmado como disponível.

## Pesquisa: evidência e limitações

As consultas diretas à Steam, Unity e RDAP da Verisign receberam HTTP 403 do proxy da rede. Portanto, não foi possível confirmar catálogo, funcionalidades atuais, preços, avaliações, concorrentes lançados recentemente ou disponibilidade de nomes em outubro de 2026.

Foi possível consultar a documentação oficial do Godot no GitHub, confirmando exportações para Windows, Linux, macOS, Android e iOS, licença MIT e exigência de macOS com Xcode para exportar para iOS. A documentação consultada também classifica o suporte C# a iOS como experimental; a proposta usa GDScript.

As referências conhecidas a seguir servem para orientar uma pesquisa de mercado. As comparações são baseadas nas propostas conhecidas dos jogos, sem auditoria atual de suas versões. Os links são buscas para localizar os títulos, não páginas consultadas nesta sessão.

| Referência | Relação com a proposta | O que estudar |
| --- | --- | --- |
| Rusty's Retirement | Fazenda idle que ocupa uma faixa da tela | Legibilidade em pouco espaço, baixa distração e sensação de vida |
| Desktopia | Construção e progressão junto à área de trabalho | Convivência com outras janelas e gerenciamento compacto |
| Chillquarium | Coleção de peixes com progressão idle | Desejo de colecionar, raridade e sessões curtas |
| Spirit City: Lofi Sessions | Companheiros e descoberta de espíritos numa experiência de foco | Vínculo emocional, personalização e atmosfera |
| Super Auto Pets | Formação de equipes e batalhas automáticas, incluindo experiências assíncronas | Estratégia antes da luta, replays e partidas compartilháveis |
| Monster Sanctuary | Coleção de monstros, sinergias e combate tático | Profundidade de equipes pequenas e identidade dos monstros |

Busca de cada título: https://store.steampowered.com/search/?term=Rusty%27s+Retirement ; https://store.steampowered.com/search/?term=Desktopia ; https://store.steampowered.com/search/?term=Chillquarium ; https://store.steampowered.com/search/?term=Spirit+City ; https://store.steampowered.com/search/?term=Super+Auto+Pets ; https://store.steampowered.com/search/?term=Monster+Sanctuary

O título exato e a página de “Taskbar Hero”, citado pelo usuário, ainda precisam ser identificados; não assumir que corresponde a outro jogo de nome parecido.

Antes de decidir posicionamento comercial, pesquisar avaliações recentes, sessões de jogo, preços, frequência de atualizações e reclamações sobre interferência na área de trabalho, consumo de recursos, repetição e monetização. Não extrapolar demanda ou faturamento a partir da existência desses títulos.

## Conceito e diferencial a testar

Uma pequena caravana de criaturas percorre ilhas flutuantes numa faixa do desktop. O jogador organiza equipes de três criaturas, define uma rota e uma doutrina de combate. A caravana explora automaticamente e retorna com materiais e descobertas.

O diferencial proposto é combinar rotas escolhidas pelo jogador, comportamento configurável da equipe e intervenções curtas. Isso é uma hipótese de posicionamento; sua exclusividade precisa de pesquisa adicional.

- Antes da expedição: escolher rota, equipe e prioridade, como proteger o curandeiro ou guardar energia para o chefe.
- Durante o AFK: combate e coleta automáticos; eventos seguem uma resposta predefinida se o jogador não estiver presente.
- Intervenção opcional: assumir uma luta de 30–90 segundos, mudar a formação ou resolver um encontro. Sem penalidade por ignorar notificações.
- Ao retornar: coletar resultados, descobrir criaturas, melhorar o acampamento e trocar a rota.
- PvE manual: desafios de chefes com escolhas por turno. Reaproveitar o mesmo sistema de combate do modo automático.

Criaturas, silhuetas, mundo, interface, animações, sons e terminologia devem ser próprios. Evitar copiar sistemas visuais reconhecíveis de Pokémon, seus dispositivos de captura, personagens ou assets dos concorrentes. Mecânicas de gênero podem inspirar experimentos originais.

## Engine, linguagens e ferramentas

| Componente | Escolha | Motivo |
| --- | --- | --- |
| Cliente | Godot 4 estável, versão fixada após o protótipo | Bom fluxo 2D, código e cenas em texto, licença MIT |
| Linguagem do cliente | GDScript | Menos configuração e boa integração com o editor |
| Renderização inicial | Compatibility, a validar nos aparelhos alvo | Adequada ao protótipo 2D; medir compatibilidade e consumo |
| Servidor | TypeScript + Node.js 24 com HTTP nativo | API pequena e sem dependências de execução no MVP |
| Banco | SQLite no MVP; avaliar PostgreSQL para hospedagem com maior concorrência | Contas, progresso, partidas e rankings persistentes |
| Pixel art | Aseprite ou alternativa compatível | Sprites, paletas e animações controlados |
| Steam | GodotSteam, após teste de compatibilidade da versão | Adaptador comunitário para recursos Steam, com manutenção a acompanhar |

Unity com C# é uma alternativa válida se houver experiência prévia ou dependência forte de seus plugins. Para este jogo 2D pequeno, Godot oferece um ponto de partida enxuto. Não iniciar com Unreal, microserviços, Kubernetes, blockchain, marketplace ou vários frameworks.

Fontes oficiais efetivamente consultadas:

- https://github.com/godotengine/godot-docs/blob/master/tutorials/export/index.rst
- https://github.com/godotengine/godot-docs/blob/master/tutorials/export/exporting_for_ios.rst
- https://github.com/godotengine/godot/blob/master/LICENSE.txt

## Compatibilidade e AFK

Steam é uma distribuição e integração de desktop. Android e iOS usarão lojas, builds e autenticações próprias. O mesmo projeto poderá compartilhar gameplay e assets, mas precisará de interfaces e adaptadores por plataforma.

- Windows: primeiro alvo. Janela compacta sem borda junto ao rodapé; transparência e passagem de cliques somente se o protótipo comprovar funcionamento. Não embutir o jogo na barra de tarefas do sistema. Respeitar foco, monitores, escala de tela e áreas reservadas.
- macOS e Linux: validar comportamentos de janela separadamente; Linux/Wayland pode limitar posicionamento e transparência. Oferecer uma janela compacta convencional como alternativa.
- Android/iOS: interface touch com alvos maiores. Não prometer overlay permanente sobre outros apps. Não depender de execução contínua em segundo plano.
- AFK offline: guardar início, rota e configuração; calcular progresso ao retornar. No jogo conectado, relógio e recompensas relevantes são validados pelo servidor. Limite inicial de 12 horas é uma hipótese de balanceamento.
- Sem conexão: permitir PvE local limitado, sem enviar recompensas não verificadas para ranking ou economia competitiva. Definir previamente a fronteira entre salvamento local e conta online.
- Baixo consumo: reduzir atualização e animações quando a janela estiver oculta; simular recompensas por tempo decorrido. Medir CPU, memória, bateria e comportamento durante suspensão.

Para iOS, planejar acesso a Mac com Xcode, aparelhos reais e contas de publicação. O ambiente Linux atual não comprova builds iOS.

## Multiplayer sem complexidade desnecessária

Primeiro implementar PvP assíncrono: o jogador publica uma equipe defensora e outra pessoa desafia uma configuração validada. O servidor simula a batalha e registra resultado, versão das regras e replay. A defesa é controlada automaticamente; não apresentar esse modo como uma partida simultânea entre dois jogadores.

Desafios por código permitem jogar com amigos em qualquer plataforma. No desktop, a integração Steam poderá abrir convites e localizar amigos elegíveis conforme as APIs, privacidade e disponibilidade. Amigos Steam não se tornam automaticamente uma lista de contatos no celular. Usar um ID interno e vinculação autenticada de contas para conectar as plataformas.

Uma conta online deve resolver conflitos de sessões e salvamentos, verificar provas de autenticação das plataformas e impedir dupla coleta de recompensas. Nunca confiar em um ID Steam ou placar enviado pelo cliente sem validação.

Depois da validação do PvP assíncrono, adicionar duelos ao vivo por turnos com prazo de decisão, reconexão e regra de abandono. Combate de ação em tempo real aumenta muito o custo de rede, animação, sincronização e QA; não faz parte do primeiro lançamento.

## Ranking e Hall da Fama

- Liga competitiva com poder normalizado e conjunto de regras explícito; tempo AFK e compras não devem determinar a vitória.
- Classificação por habilidade, com partidas de colocação e temporadas. Matchmaking também pode considerar incerteza da classificação.
- Ranking separado de coleção e exploração, pois mede objetivos diferentes.
- Hall da Fama com campeões de temporada, conquistas excepcionais e replays selecionados. Preservar registros após revisão de resultados suspeitos.
- Desafios entre amigos sem impacto na liga para reduzir manipulação; impor limites e investigar padrões em partidas competitivas.
- Servidor autoritativo para recompensas online, resultados, classificação e datas. Requisições idempotentes, regras versionadas, limites de chamadas e trilha de alterações.

O servidor é necessário para competição confiável. Cloud save sozinho não torna um ranking resistente a alterações locais.

## Design assistido por IA

Definir uma bíblia visual antes de produzir muito conteúdo: paleta limitada, resolução base, escala dos sprites, espessura dos contornos, sombras e três referências de atmosfera. Criaturas precisam de silhuetas distintas, especialmente na interface compacta.

Proposta inicial: pixel art colorida e acolhedora, criaturas de 32×32 ou 48×48 pixels, animações curtas e uma caravana legível. Os tamanhos são hipóteses; testar a leitura em monitores com diferentes escalas antes de fixá-los. Ícones e texto precisam de contraste e não podem depender só de cor.

A IA pode produzir código, testes, ferramentas, propostas de arte e documentação. Imagens geradas precisam de adaptação para sprites, revisão de consistência e conferência de direitos/licenças. IA não elimina testes em aparelhos, direção artística, contas de publicação ou decisões de produto.

Manter cenas pequenas, dados de criaturas em JSON, lógica de combate independente da interface, ferramentas de geração reproduzíveis e um adaptador por plataforma. Evitar editar grandes cenas manualmente sem validação. Implementar uma função por vez com critérios de aceite e builds executáveis.

## Escopo e sequência

Estimativas para uma pessoa dedicada com assistência de IA, sujeitas a experiência, produção de arte e resultados dos protótipos. Não são prazo garantido. As fases mobile e live PvP são adicionais.

| Fase | Estimativa | Entrega e condição para avançar |
| --- | --- | --- |
| Prova técnica | 1–2 semanas | Rodapé no Windows, alternativa de janela comum, build Android, combate mínimo e investigação da exportação iOS. Testar foco, DPI, suspensão e consumo |
| Protótipo de diversão | 3–5 semanas adicionais | 6 criaturas, 1 região, AFK, retorno offline e um chefe com intervenção. Pessoas externas entendem e querem retornar |
| Versão demonstrável | 4–6 semanas adicionais | 12 criaturas, 3 regiões, 3 chefes, evolução simples, UI final de amostra, tutorial, save e replay |
| Alpha online | 5–8 semanas adicionais | Contas, progresso validado, PvP assíncrono, desafios por código, liga e Hall da Fama; testes de concorrência e manipulação |
| Steam e beta desktop | 3–5 semanas adicionais | Integração Steam validada, convites, conquistas, distribuição, telemetria mínima e polimento |
| Mobile | Planejar após a prova técnica | UI adaptada, vinculação de conta, testes reais, bateria, assinaturas e submissão às lojas |
| PvP ao vivo | Expansão posterior | Turnos simultâneos ou alternados, tempo limite, reconexão e métricas de matchmaking |

O total aritmético até beta desktop é aproximadamente 16–26 semanas se as fases ocorrerem em sequência e sem retrabalho significativo. Reservar margem; um iniciante sozinho pode precisar de mais tempo. Não lançar quatro plataformas e PvP ao vivo no mesmo primeiro marco.

## Critérios de aceite importantes

- Uma sessão AFK deve retornar exatamente uma recompensa, mesmo após repetição de requests ou uso em dois aparelhos.
- Ajustar o relógio local não altera resultados competitivos.
- Replays reproduzem resultados nas regras versionadas da partida.
- O jogo não rouba foco durante trabalho; o usuário consegue pausar, ocultar e silenciar.
- Suspensão, encerramento inesperado e retorno offline não corrompem o progresso.
- Todo modo automático tem escolhas compreensíveis e toda intervenção opcional respeita quem está ausente.
- Definir orçamento de desempenho a partir das medições do protótipo, em vez de prometer consumo baixo sem testar.

## Potencial de divulgação

Criar motivos naturais para compartilhar: replay curto com virada de combate, cartão de equipe, aparência rara cosmética, caravana personalizável e torneio entre amigos. Na Steam, medir interesse numa página e demo; nas redes, testar vídeos curtos da interação real.

Registrar retorno no dia seguinte, frequência de expedições, uso das intervenções, conclusão do tutorial, desafios enviados e conversão de visitas em wishlists quando disponível. Definir metas após medir uma primeira coorte. Não usar um número arbitrário de retenção como garantia comercial.

Começar com testes de 10–20 pessoas para detectar problemas de compreensão e conforto. Depois ampliar amostra e comparar versões. Se o interesse desaparecer quando a novidade passa, revisar o ciclo antes de acrescentar multiplayer complexo.

## Monetização proposta

Primeiro testar o jogo sem pagamentos. Para desktop, avaliar compra única e conteúdo cosmético posterior. Para mobile, avaliar demo com desbloqueio ou modelo compatível com a conta compartilhada. Definir direitos de acesso entre lojas antes de vender. Evitar vender força, tentativas competitivas ou boosts que dominem o ranking. Receita recorrente não é garantida; prever hospedagem e manutenção dos serviços online.

## Nomes candidatos — disponibilidade não verificada

| Nome | Domínio .com para investigar | Identidade sugerida |
| --- | --- | --- |
| Brumora | brumora.com | Criaturas e ilhas na névoa; boa pronúncia em português |
| Nimbrio | nimbrio.com | Nuvens, movimento e criaturas pequenas |
| Duskburrow | duskburrow.com | Abrigos e exploração ao entardecer |
| Mossrelay | mossrelay.com | Caravanas, natureza e conexão entre jogadores |
| Wispward | wispward.com | Espíritos viajantes e proteção da equipe |

Brumora é a preferência provisória pela sonoridade; não é uma recomendação de marca liberada para uso. Todas as cinco consultas RDAP foram bloqueadas pela rede. Não existe confirmação de domínio livre, ausência de jogo homônimo ou disponibilidade de marca.

Validação necessária: RDAP/registrador no momento da compra; buscas Steam, App Store e Google Play; buscas web e nomes de redes sociais; pesquisa de marca no INPI e em bases internacionais adequadas ao mercado. Domínio sem registro não significa marca livre, e uma resposta RDAP de ausência não garante disponibilidade comercial no registrador. Não registrar nomes automaticamente.

Para concluir a pesquisa atual, liberar nas configurações da rede os destinos necessários: store.steampowered.com, partner.steamgames.com, www.bing.com, rdap.verisign.com, apps.apple.com e play.google.com. Os domínios já permitidos devem ser preservados. Não houve alteração de rede nesta tarefa.

## Primeiro passo executável

Testar o pacote Windows desta entrega, avaliar conforto do modo rodapé, clareza das escolhas, leitura dos sprites e vontade de retornar. Corrigir problemas observados antes de expandir conteúdo e adicionar integração Steam. Provas Android/iOS permanecem pendentes.

## Sistema de criaturas entregue

Espécie define identidade, papel, elemento, atributos base e habilidade. Exemplar define identificador próprio, nível, XP, raridade, aparência luminosa e quatro atributos individuais. O jogador escolhe uma das três iniciais; elas têm raridade comum e individuais 8/15, evitando uma desvantagem arbitrária na escolha inicial.

| Espécie | Papel | Vida / ataque / defesa / velocidade base | Habilidade |
| --- | --- | --- | --- |
| Fagulim | Atacante | 82 / 28 / 11 / 22 | Golpe de 1,85× ataque; recarga 3 |
| Musgudo | Tanque | 132 / 17 / 23 / 9 | Escudo de 24% da vida de cada aliado; recarga 3 |
| Lunélia | Suporte | 94 / 18 / 13 / 19 | Cura de 34% da vida máxima do aliado mais ferido; recarga 3 |
| Marulito | Atacante | 92 / 25 / 14 / 24 | Golpe de 1,7× ataque; recarga 2 |
| Pedrume | Tanque | 145 / 20 / 25 / 7 | Escudo de 28% da vida de cada aliado; recarga 4 |
| Nimbico | Suporte | 102 / 19 / 16 / 20 | Cura de 30% da vida máxima do aliado mais ferido; recarga 2 |

Atributo final = arredondar(base × [1 + 0,075 × (nível − 1)] × bônus de raridade × [0,94 + 0,008 × individual]). Individuais inteiros de 0 a 15 são independentes por atributo. Raridades: comum 70%, incomum 22%, rara 7%, épica 1%, com multiplicadores 1,00 / 1,03 / 1,06 / 1,09. Aparência luminosa: 3%, sem bônus de combate.

Níveis 1–20. XP para próximo nível = nível × 40. Treino por moedas completa o nível atual por nível × 15 moedas. Esses valores favorecem testes curtos; não são economia final de lançamento.

Na liga, atributos são recalculados no nível 5 com multiplicador individual e de raridade iguais a 1. Papéis e habilidades permanecem. Isso preserva coleção no PvE e reduz vantagem de grind na competição.

## Combate e dificuldade entregues

Cada ação manual resolve um turno da equipe e dos inimigos por velocidade. Habilidades têm recarga por ações do portador. Dano mínimo 3; defesa reduz o valor em 0,48×defesa, variação entre 0,94–1,06 e crítico com 10% de chance e multiplicador 1,35. Escudos absorvem dano antes da vida e acumulam até 60% da vida máxima. Proteger adiciona 18% de escudo individual. Um tanque vivo recebe prioridade em parte das escolhas de alvo. Suporte automático cura quando o aliado mais ferido está abaixo de 80% de vida.

Há limite de 60 turnos; decide a vida proporcional restante. Cada batalha tem seed persistida, resultados calculados no servidor e proteção contra execução repetida do turno final. Não há energia paga, morte permanente ou perda de coleção por derrota.

Prado: inimigos nível 1 e chefe nível 3; Costa: níveis 4/6; Ruínas: níveis 7/10. Chefes têm três integrantes. Vitória desbloqueia a próxima região e, na primeira vitória, concede uma criatura adicional. Encontros selvagens sorteiam espécies da região. O balanceamento precisa de testes externos com as três iniciais e diferentes equipes.

As animações combinam atlas em pixel art, flutuação e deslocamentos contínuos, cenário em paralaxe, movimentos de ataque, reação a dano, partículas de cura/escudo, números flutuantes e interpolação das barras de vida. Atualização visual alvo: 60 FPS quando visível, 2 FPS quando minimizada. Isso é configuração, não resultado de benchmark em Windows.

## Jogo completo após a validação do MVP

1. **Direção de arte e conteúdo:** melhorar ciclos de caminhada, ataque, cura, vitória e derrota; criar evoluções próprias; ampliar para 24–36 espécies em seis biomas, cada um com tiles, props, encontros e chefes específicos. Primeiro validar uma espécie e um bioma de qualidade final. Os custos de arte podem mudar o escopo.
2. **Tática e progressão:** doutrinas por membro, equipamento com escolhas laterais, estados de combate, encontros de rota com respostas predefinidas, tutorial progressivo e objetivos de coleção. Evitar acrescentar sistemas que não alterem decisões.
3. **Online hospedado:** HTTPS, login recuperável, vinculação de plataformas, backup testado, migrações de dados, auditoria de recompensa, observabilidade, limites de requisição e moderação. Migrar o banco apenas quando recursos e volume exigirem.
4. **Steam:** App ID, integração do plugin validada na versão fixada, autenticação verificada, conquistas, convites e armazenamento/configuração sem conflito com a conta central. Fazer branch de testes e demo antes do lançamento.
5. **Competição:** temporadas, classificação com incerteza, histórico e replays completos, regras versionadas, medidas contra abuso de contas, Hall de campeões e recompensas cosméticas. Hall de exploradores do MVP não é ainda esse sistema sazonal.
6. **Multiplayer ao vivo:** duelos por turnos com prazo, reconexão, desistência e matchmaking. Co-op PvE pode vir depois, aproveitando as regras de combate. Não introduzir rede de ação em tempo real sem validar necessidade.
7. **Mobile:** mesmo gameplay, assets e servidor; interface touch adaptada, retomada de sessão, consumo, notificações opcionais e testes em aparelhos. Android primeiro; iOS com Mac/Xcode e assinatura. Exportar não substitui validar UX e lojas.
8. **Lançamento:** testes de estabilidade e balanceamento, acessibilidade, opções de áudio e notificação, localização, suporte, demo, análise de interesse e estratégia comercial. Receita e viralização dependem de validação.

## Critérios de teste no Windows

Conseguir extrair e iniciar sem instalação adicional; escolher qualquer inicial; descobrir aliados; trocar a formação; usar ataque, cura e escudo; fechar e reabrir sem perder progresso; vencer e perder encontros; desbloquear uma rota; alternar entre duas caravanas e concluir um duelo; mover e expandir o rodapé; confirmar que não atrapalha foco e trabalho. Registrar sistema, resolução, escala de tela, GPU e problemas. Esses testes nativos ainda são necessários.


## Revisão visual e técnica final do MVP

O usuário definiu Godot 4.7.2 como versão de referência; a CLI e os templates oficiais foram instalados e tiveram hashes verificados na nuvem. O projeto está fixado nessa versão em `.godot-version`.

A apresentação foi refeita: cenário panorâmico ocupando o mundo, fonte própria, HUD de fantasia, atlas transparente detalhado para as seis criaturas e nove inimigos, três cenários regionais e ornamentos coerentes. A direção persistente está em `AGENTS.md` e `docs/ART_DIRECTION.md`.

Os mapas têm paralaxe de panorama, névoa, partículas e primeiro plano. Cinco marcos visuais por região estão descritos em `assets/maps.json`; esses marcos ainda não são novos eventos de gameplay ou mapas de livre exploração. No rodapé, a equipe pode iniciar encontros, combater automaticamente, avançar após vitória e continuar a viagem; é possível pausar o automático e assumir o controle na janela expandida.

Inimigos: Espinbroto, Cascalhito, fauna costeira e lunar, com dois tipos por região e um chefe acompanhado. Os nomes, atributos e habilidades efetivos estão em `assets/enemies.json`, separado da coleção do jogador. Quinze perfis de efeitos cobrem as seis espécies e os nove inimigos/chefes, com eventos de combate estruturados identificando ator e alvo.

Validação: servidor com 15 testes; verificações de tipos; testes gráficos OpenGL no Godot 4.7.2 para mapas e efeitos; fluxo integrado de registro, exploração, combate, ranking e rodapé. A validação de execução Windows nativa continua sendo um teste no computador do usuário; consulte `docs/VALIDACAO.md` e `docs/LOCAL_HANDOFF.md`.
