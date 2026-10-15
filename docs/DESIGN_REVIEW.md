# TaskMon — revisão sênior de design

## Estado da revisão

**REVISÃO ANTERIOR SUPERADA — A NOTA 9,0 NÃO É VÁLIDA PARA O ESTADO ATUAL.** Evidência posterior do usuário e reprodução local confirmaram terreno duplo e engrossamento das pernas da raposa durante a animação. Esses defeitos não foram identificados na revisão anterior e invalidam sua conclusão de ausência de bloqueios. A produção está novamente em correção; uma análise independente deverá avaliar a versão corrigida. O conteúdo das rodadas abaixo fica apenas como histórico, não como aprovação para entrega.

## Rubrica de 0 a 10

Cada dimensão recebe uma nota própria. A média ponderada é publicada com as limitações da sessão de revisão e as evidências. Uma média não esconde um bloqueio funcional: botões inacessíveis, perda de progresso, criatura sem sprite ou erro de execução impedem aprovar a entrega.

| Dimensão | Peso | Critério observável para 9 |
| --- | ---: | --- |
| Direção de arte e coesão | 20% | Criaturas com identidades consistentes, resolução adequada ao tamanho de tela e tratamento de borda coerente; nenhum placeholder ou efeito destoante. |
| Cenário, escala e profundidade | 15% | Os três biomas são reconhecíveis; primeiro plano, chão e fundo têm separação; pés/sombras tocam o chão; zoom não corta ações; deslocamento/paralaxe não cria saltos. |
| Layout e hierarquia | 15% | Mundo domina a exploração, combate tem HUD próprio, cartas e inventário cabem sem desperdício; rótulos/valores nunca colidem; boa composição em 1280×800 e janela compacta. |
| Clareza de UX | 15% | Jogador distingue explorar/combater/aprimorar; ícones recebem tooltips claros; navegação, voltar/fechar/expandir são sempre visíveis; estado/desabilitação de ações é evidente. |
| Feedback e legibilidade de combate | 15% | Origem, trajeto e impacto do ataque têm sequência causal; dano/cura/escudo são distintos; barras têm leitura rápida e resposta suave; entrada, derrota e resultado são claros sem sobreposição. |
| Animação e presença | 15% | Idle visível sem deformação de borracha; olhos/asas/apêndices adequados à anatomia; nenhuma criatura anda sentada; passos não deslizam excessivamente; ataque tem antecipação e recuperação; transições preservam escala e contato. |
| Progressão e inventário | 5% | XP de jogo, loot, espaço disponível/excedente e tempo de aprimoramento são compreensíveis; preços/requisitos ficam próximos da ação; ganho/nível/aprimoramento têm feedback e atualização consistente. |

Os slots principais da equipe mostram retrato, categoria, nível e XP. **Atributos devem aparecer ao abrir a carta**, conforme a preferência atual do usuário; a ausência de estatísticas nos slots principais é intencional e não reduz a nota.

## Escala de avaliação

- **0–3:** fluxo quebrado, ilegível ou muito distante da direção aprovada.
- **4–5:** protótipo funcional com problemas visuais/UX frequentes.
- **6–7:** base coerente, mas defeitos perceptíveis em várias ações ou telas.
- **8:** apresentação boa, com problemas localizados que ainda afetam o polimento.
- **9:** qualidade consistente na sessão observada, sem defeitos relevantes nos fluxos revisados.
- **10:** excepcional na abrangência verificada; não equivale a ausência universal de defeitos.

## Percurso de revisão exigido

1. Onboarding e exploração nos três biomas, com pelo menos um trecho em movimento e outro parado.
2. Cartas de coleção, detalhes, escolha de mapa, perfil/conquistas e inventário cheio com loot pendente.
3. Batalha real com ataque básico, habilidade, dano, cura/escudo, spawn, morte e retorno pelo botão de continuar.
4. Fagulim sentado → levantar → caminhar → parar → sentar; iniciar combate a partir de repouso; conferir piscada, patas e sombra em reprodução, não apenas imagem.
5. Modo rodapé e restauração por ícone/Escape, incluindo situação de combate e resultado.
6. Loot e XP vindos do servidor, início/fim do aprimoramento temporizado e atualização dos valores visíveis.

Capturas fixas servem para composição, contraste, alinhamento, tipografia e enquadramento. Movimento e causalidade requerem reprodução em Godot. Testes sintéticos mostram situações difíceis de obter, mas devem ser identificados como fixtures; não comprovam por si só recompensas ou economia reais.

## Critérios de bloqueio e iteração

Para cada problema registrar tela/ação, impacto percebido, evidência, severidade e correção concreta. Corrigir primeiro bloqueios, depois problemas que aparecem repetidamente e por último detalhes cosméticos. Após cada conjunto de mudanças rever os mesmos pontos e informar o que melhorou e o que ainda limita a nota. Não atribuir 9 por obrigação nem mascarar limitações de uma única pose raster como animação desenhada completa.

## Limites que devem acompanhar a nota

Informar versão/build observada, resolução, tipos de captura/reprodução, fluxos reais versus fixtures e qualquer estado não reproduzido. Uma revisão local de desenvolvimento não comprova comportamento em mobile, outras GPUs, resoluções arbitrárias ou publicação nas lojas.

## Rodada 1 — evidências e correções

`tests/visual_review.gd` executado graficamente em OpenGL/NVIDIA RTX 5050 Laptop: `failures=0`. O percurso reproduziu idle → levantar → caminhar → parar → sentar, três biomas, mapas, inventário cheio/baú, detalhes, coleção, perfil e combates com zoom assentado após 0,95 s. São fixtures visuais identificadas como tal; não constituem prova de recebimento de recompensas reais. O smoke integrado de conta/servidor e os testes de economia são verificações separadas.

| Dimensão | Nota inicial | Observação |
| --- | ---: | --- |
| Direção de arte | 8,8 | Identidade consistente, cenários detalhados e criaturas limpas em escala de jogo; filtro de criaturas conserva contornos legíveis. |
| Cenário e profundidade | 9,0 | Biomas distinguíveis, chão com volume e contato; enquadramento de combate reúne os dois lados sem menus de exploração. |
| Layout e hierarquia | 8,4 | Detalhe da criatura agora cabe; faltam alinhar ações nos mapas e eliminar o pequeno corte de rodapé no inventário com baú. |
| Clareza de UX | 8,5 | Ícones contextuais e custos estão claros; mensagem de treino deve explicitar ausência de XP/recompensas. |
| Feedback de combate | 8,6 | Trajetória/impacto e barras respondem; nome flutuante de habilidade invade barras e repete a informação do HUD inferior. |
| Animação e presença | 8,2 | Raposa usa passos em pé e não anda sentada; detectada discrepância entre velocidade do chão e recuo dos pés do rig. |
| Progressão/inventário | 9,0 | Ganhos `+0,125`/XP legíveis; inventário compacto, custos por material e tempo próximo da ação. |

Evidências em `%LOCALAPPDATA%/Brumora/taskmon-captures`: `taskmon-walking-0.png` e `taskmon-walking-step-0.png` (poses distintas sobre o chão), `taskmon-rest-after-walk-0.png`, `taskmon-boss-0.png`/`1.png`/`2.png`, `taskmon-impact-0.png`, `taskmon-atlas-hd.png`, `taskmon-creature-upgrade.png`, `taskmon-inventory-populated.png`, `taskmon-decimal-gains.png` e `taskmon-profile-complete.png`.

Correções verificáveis para a próxima rodada:

1. Remover o nome flutuante da habilidade que cruza a barra, conservando preparação/impacto e o nome fixo no HUD.
2. Alinhar os botões Explorar no rodapé das três cartas de mapa, independentemente do número de linhas da descrição.
3. Garantir que o inventário com baú não produza corte/scroll por poucos pixels na nota final redundante.
4. Sincronizar o apoio dos pés com o chão: velocidade atual de chão = `24 × 0,64 = 15,36 px/s`. O rig anterior recuava o pé de Musgudo em aproximadamente 6,4 px/s, produzindo patinação. `stride_for_ground_speed` já corrige isso por tamanho/cadência, com teste em 64/128/192 px. Revisão visual da formação final ainda pendente.
5. Entrada em combate deve respeitar a posição corrente da equipe e a preparação de postura; deslocamento excessivo para trás distrai do encontro.

Medições de `TIME_PROCESS` lidas imediatamente após salvar PNG incluem readback/codificação e não são benchmarks de frame. Nos trechos de combate 1/2 o monitor indicou 60 FPS e cerca de 11 ms de processamento; essa sessão curta não é garantia universal de desempenho. Áudio teve presença dos 45 arquivos verificada; esta nota não inclui uma auditoria perceptiva de mixagem. A anatomia oculta de sprites estáticos continua sendo uma limitação de produção: as outras 14 espécies usam rig, e não novos ciclos desenhados completos.

## Rodada 2 — avaliação final

O percurso gráfico completo foi repetido após a integração atual: `Visual review finished, failures=0`. Não houve acesso a conta real; as capturas utilizam fixtures locais, sem atribuir recompensas ao jogador. O atlas de 620 px recebeu uma recaptura adicional com `--atlas-only`, também `failures=0`.

| Dimensão | Nota final | Evidência e mudança percebida |
| --- | ---: | --- |
| Direção de arte e coesão | 9,1 | Fonte própria, ornamentos discretos, ícones canônicos e criaturas preservadas formam linguagem consistente de fantasia. |
| Cenário, escala e profundidade | 9,1 | Exploração ativa ocupa o mundo ampliado, sem cards inferiores; três biomas têm identidade e chão legível. Combate aproxima a câmera e preserva o lado da equipe. |
| Layout e hierarquia | 9,0 | Inventário/baú sem corte, detalhe com ações visíveis, atlas de 620 px com três ações alinhadas e margens equilibradas. |
| Clareza de UX | 9,0 | Inspeção por criatura, nome/nível no mundo, atributos somente ao abrir a carta, ícones com contexto e resumo com ação clara de continuar. |
| Feedback visual de combate | 9,0 | Impacto direcional, número com contorno/pop, barras com rastro, habilidades sem texto flutuante sobre HP, moeda e XP com símbolos próprios. |
| Animação e presença | 8,8 | Raposa deixou de correr por flipbook e usa quatro apoios contínuos; chão/passada sincronizados e exemplares iguais com fases independentes. A passagem entre artes de levantar/sentar ainda tem poucos intermediários e mudança sutil de volume; refinamento futuro, sem bloquear o fluxo AFK observado. |
| Progressão e inventário | 9,0 | Resumo ilustrado apresenta tempo, abates, batalhas, moeda decimal, XP e materiais; requisitos e duração do aprimoramento permanecem próximos da ação. |

Média ponderada pela rubrica: **9,0/10**. A nota cobre o jogo 2D estilizado e os fluxos observados; não representa realismo biológico completo nem animação de produção AAA. O item de animação permanece deliberadamente abaixo de 9, em vez de ocultar a limitação da transição de postura.

### Verificações específicas pedidas

- Velocidades **0,5×, 1× e 2×**: execução nativa com expedição ativa; o teste comprovou acoplamento `delta_distância = delta_walk_clock × 24` em todas as velocidades, evitando aplicar aceleração duas vezes. Capturas `taskmon-speed-0_5-twins.png`, `taskmon-speed-1_0-twins.png` e `taskmon-speed-2_0-twins.png` mostram o mesmo conjunto nessas condições.
- **Dois Musgudos distintos**: IDs diferentes produziram fases próprias; as duas criaturas foram renderizadas juntas. `combat_variation_test.gd` também confirmou padrões visuais diferentes por ator nos 15 perfis, mantendo identidade elemental e instante de impacto.
- **Raposa**: pose em pé, rig contínuo de 0,90 Hz e quatro apoios; caminhada sentada bloqueada. Testes de postura e galeria upright/blink aprovados. Não se considera o antigo ciclo de corrida de 12 FPS aprovado.
- **Apresentação**: resumo da expedição, ganhos de três casas decimais, inventário com loot pendente, perfil, coleção, detalhes, três mapas e três combates capturados e inspecionados. Fighters das fixtures possuem nível 5 explícito.

### Encerramento e limites

Os problemas da rodada 1 foram corrigidos e conferidos: sobreposição de nome de habilidade, ações dos mapas desalinhadas, corte do inventário, discrepância de velocidade dos pés e deslocamento excessivo da equipe na entrada em combate. O último refinamento reduziu o atlas para 620 px sem esconder conteúdo. Não há nova correção bloqueante para esta entrega local.

Permanecem fora da nota: testes longos com jogadores, mixagem auditiva perceptiva, outras GPUs/DPI/plataformas, enquadramentos arbitrários e estabilidade de horas de AFK. Os testes de economia/HP persistente/resumo e o smoke de conta são validações separadas do servidor/cliente; as imagens deste documento não os substituem. Não se usa o custo de salvar PNG como métrica de FPS normal.
