# TaskMon — plano de polimento e sistemas

## Entendimento e diagnóstico
O código nativo Godot 4.7.2 usa desenho imediato para cenário, HUD e criaturas; o servidor TypeScript/SQLite é autoritativo. O combate reutilizava o menu da exploração, o atlas tinha margens incompatíveis com a sombra no chão e os eventos de turno eram exibidos quase simultaneamente. Preservar espécies, progresso e o volume Docker existente.

## Implementação aprovada pelo pedido
1. TaskMon como marca; manter caminhos de salvamento antigos para recuperar sessões.
2. HUD contextual: exploração, arena de combate e rodapé independentes. Escape restaura a janela; botão de expandir com ícone sempre dentro da área visível.
3. Cartas de criaturas com retrato, categoria (ícone + Tank/Atacante/Suporte), raridade, nível, XP, ícones de atributos e acesso a detalhes/aprimoramento.
4. XP exclusivamente por inimigos derrotados em combate concluído, nunca por ticks de expedição, treino ou compra. Aprimoramento de 0 a 10 por materiais aumenta atributos (+4%/grau), passiva (+1%/grau) e poder da ativa (+3%/grau). PvP normaliza grau e atributos; a economia não compra vantagem na liga.
5. Quatro espaços para tipos de materiais empilháveis; expansão +2 espaços por moedas até 20. Loot excedente vai ao baú pendente, sem descarte. Loot de PvE por região; duelos premiam até 5 vitórias por dia do servidor. Treino não dá loot. Resultados e coleta idempotentes.
6. Passivas de espécie: vigor, carapaça, cura, corrente, cristal e vento; benefícios calculados no servidor e descritos no catálogo.
7. Terreno em camadas, pontos de interesse, contatos alinhados à opacidade dos sprites; partículas, preparação de habilidade, projétil, impacto e recuperação sequenciados.
8. Inventário e detalhes com fundos ilustrados e custos/estado atualizado após ações.

## Ordem e verificação
Servidor/economia → UI e cartas → mundo/efeitos/arte → testes de regressão e screenshots nativas → exportação Windows e instruções locais. Testes usam banco e sessão separados; fazer backup do volume real antes de atualizar o servidor. Não trocar nem apagar saves. Nenhum recurso de PvP ao vivo será anunciado.

## Decisões finais que substituem propostas anteriores
- O usuário rejeitou os cenários totalmente procedurais: o cliente ativo volta aos cenários ilustrados em PNG de alta resolução por região. O módulo procedural fica somente como experimento.
- Interface mais contida e intuitiva: TaskMon-Interface (Alegreya Sans SC Medium) para leitura e controles, Cinzel para a marca/títulos, menos ornamentos e textos repetidos, ações secundárias por ícones com tooltips.
- AFK exige cliente aberto/conectado; oito segundos de tolerância de presença. XP/moedas/descobertas não acumulam offline. O prazo de aprimoramentos já iniciados continua offline.
- Aprimoramento tem prazo 60 × grau-alvo² segundos (1–100 minutos), com requisitos de nível e materiais. Graus iniciais usam fibra comum para todos os iniciais; graus avançados usam afinidade, núcleos e selos.
- Mundo: world-forest.png, world-coast.png e world-ruins.png; terreno ground-taskmon.png, com pés/sombras ancorados. Rig anatômico preserva os sprites e anima pés, idle e preparação de ataque.
- GS e conquistas são derivados do perfil autoritativo; seletor de mapas traz arte, estrelas e GS recomendado.
- Sons por espécie e ação, projéteis independentes e momentos de impacto sincronizados. Nenhuma compra de XP.

## Economia de combate e precisão monetária
- XP é somada por inimigo com HP zero no resultado autoritativo: `arredondar((2 + 0,6 × nível + poder / 110 + bônus de papel) × bônus de chefe)`. Poder usa HP × 0,35 + ataque × 2 + defesa × 1,5 + velocidade; Tank acrescenta 0,5 e Suporte 0,35; chefe multiplica por 2,5. Inimigos iniciais rendem cerca de 3–4 XP, evitando evolução de nível a cada poucos encontros.
- Cada participante da batalha recebe a soma integral, inclusive aliados caídos; reservas não ganham XP. Abates parciais PvE conservam XP, moedas e materiais dos inimigos efetivamente derrotados, inclusive ao perder ou retornar. Vitória por limite de turnos não inventa prêmios de inimigos vivos. Treino não dá XP. PvP dá XP de abates nas primeiras cinco vitórias diárias, usando inimigos normalizados no nível 5.
- XP é creditada uma vez ao concluir a batalha. `battle.rewards` contém `gold`, `xp` (soma por participante), `items`, `defeated` (id/espécie/nível/XP de cada abate) e `xp_by_creature` (XP realmente aceita por exemplar, com limite de nível 20).
- Moedas têm precisão de 0,001. Somas e descontos convertem o saldo para milésimos inteiros, calculam nesse formato e expõem número de até três casas na API/SQLite. Saldos legados mantêm o valor, arredondado para essa precisão; não há reset de perfil.
- Balanceamento inicial: 30 moedas de partida. Tempo na expedição não concede moedas nem XP; apenas inimigos abatidos geram esses prêmios. Cada abate inicial rende aproximadamente 0,220–0,240 moedas; chefe tem multiplicador de moeda por abate. Duelo elegível rende 0,250 por inimigo derrotado. Custos de aprimoramento/expansão permanecem; são valores iniciais sujeitos a playtest.

## Jornada com desgaste e retorno
- HP de cada exemplar persiste em `expedition.hp`, salvo no servidor a cada turno. Entre encontros não existe cura automática; subir de nível ou aprimorar não ressuscita nem preenche HP. Novos membros entram com HP máximo uma vez e ficam registrados por ID, mesmo ao trocar a formação.
- Uma nova expedição prepara a equipe com HP completo. Trocar rota encerra a anterior com resumo; treino e PvP usam combatentes isolados e não alteram o HP nem os totais da jornada. Combates fora de expedição podem preparar HP completo.
- Quando todos os combatentes caem, a expedição termina. Retornar por pausa ou retirada também encerra; os abates realizados são contabilizados antes do resumo. Recursos continuam no inventário/baú pendente e não são concedidos uma segunda vez pelo resumo.
- `last_expedition_summary` persiste com ID, região/nome, início/fim, duração em segundos e milissegundos, resultado (`defeat`, `returned` ou `changed_route`), moedas, XP realmente recebida somada entre participantes, XP de inimigos (`enemy_xp`), XP por exemplar, materiais, abates e batalhas. Repetir a conclusão ou a coleta não duplica valores.
- Migração preserva perfis e batalhas existentes. Um wipe antigo já premiado encerra a rota sem pagar novamente; totais históricos anteriores ao novo registro não são reconstruídos por estimativa.
