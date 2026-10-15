# TaskMon — versão local 0.2

Jogo nativo de criaturas: expedições AFK com o jogo aberto, equipe de até três companheiros, combate tático, materiais e aprimoramentos temporizados. Godot 4.7.2 + servidor TypeScript/Node 24 + SQLite.

**Continuar na cloud:** leia [docs/CLOUD_HANDOFF.md](docs/CLOUD_HANDOFF.md). Este checkpoint inclui as novas peças e rigs de quinze criaturas, ainda em integração; não equivale a animação final aprovada. A memória de regras e arte acompanha o código.

## Jogar no Windows

No pacote `TaskMon-MVP-Windows-x64.zip`, extraia tudo para uma pasta gravável e abra `Iniciar-TaskMon.bat`. O runtime Node acompanha o pacote. Para o projeto local de desenvolvimento, o atalho **TaskMon** da Área de Trabalho inicia o Docker e o cliente.

- Escolha uma criatura e seu nome.
- **Explorar** inicia a rota; **Auto** permite encontros automáticos na janela normal. O rodapé também pode combater automaticamente.
- **Mapas** mostra imagem, dificuldade em estrelas e GS recomendado. Chefes abrem as próximas regiões.
- A **mochila** abre o inventário; a **estrela** abre a coleção; o **troféu** abre o perfil e as conquistas.
- Nos cards, o ícone de melhoria abre atributos, passiva, ativa, materiais e prazo de aprimoramento.
- O botão de expandir no rodapé ou **Escape** restaura a janela.
- Passe o mouse nos ícones para ver sua função. Foco de teclado e estados de espera estão disponíveis.

## Progressão

**XP, moedas e materiais vêm exclusivamente dos inimigos abatidos em combate. A viagem exige o cliente aberto; tempo parado não concede XP nem moedas.** O servidor recebe sinais de presença, com tolerância de oito segundos para atrasos de rede. Ao fechar o cliente, o período offline é descartado. Não há compra de XP.

O nível da criatura (1–20) vem dos inimigos abatidos. XP é creditada uma vez ao concluir a batalha, apenas aos participantes; reservas e treino não recebem XP. A curva inicial considera nível e força dos inimigos e será balanceada com testes. Moedas usam precisão de três casas decimais, calculadas em milésimos inteiros no servidor. O aprimoramento é uma progressão separada (0–10), paga com materiais de abates e moedas. Cada grau acrescenta 4 pontos percentuais ao bônus de atributos, 1 ponto percentual à passiva e 3 pontos percentuais ao poder da ativa. O prazo é `60 × grau-alvo²` segundos: de 1 a 100 minutos. Os materiais são consumidos uma vez ao iniciar. A fila fica salva e conclui mesmo após fechar o jogo; até lá, a criatura mantém o grau anterior.

O inventário começa com quatro espaços para tipos de materiais; quantidades do mesmo material empilham. O botão **+2** compra espaços com moedas, até 20. Se não houver espaço para um novo tipo, o loot fica no baú de resgate. Nada é descartado por falta de espaço.

Vitórias PvE fornecem essência e material regional; chefes também dão núcleos e selos. A arena assíncrona oferece materiais nas primeiras cinco vitórias de cada dia UTC. O treino não dá loot. O GS soma o poder da equipe equipada; composição, habilidades e recargas continuam importantes. Na arena, atributos e aprimoramentos são normalizados.

## Arte e movimento

A versão ativa usa os cenários ilustrados em alta resolução, um por região, com terreno detalhado e paralaxe. O experimento de cenário inteiramente procedural foi rejeitado e não é usado pelo cliente.

Os atlas de criaturas são texturas com transparência, animadas por um rig de malha ponderada: articulação de membros, apoio/retorno dos pés, cauda, orelhas, asas, idle e preparação de ataques. Projéteis, cura, escudos, aparição e desaparecimento são efeitos nativos independentes. Isso não equivale a um conjunto completo de animações desenhadas quadro a quadro. A evolução futura está documentada em `docs/CREATURE_MOTION.md`.

A memória visual está em `docs/ASSET_REGISTRY.md`. Reutilize sempre os assets canônicos dos itens e espécies. Não gere versões contraditórias do mesmo item.

## Desenvolvimento local

Na raiz do projeto:

```powershell
docker compose up --build -d
docker compose --profile tools run --build --rm test
```

Abra `project.godot` no Godot 4.7.2 e execute com **F5**. O cliente conecta em `http://127.0.0.1:8787`. O servidor deve permanecer em loopback. Para verificar tipos: `npm ci --prefix server` e `npm run typecheck --prefix server`.

Testes: `tests/server.test.ts` cobre economia, autenticação, idempotência e persistência; `tests/ui_smoke.gd` usa servidor de desenvolvimento e sessão separada; `tests/visual_review.gd` usa fixtures visuais para rever os atlas, telas e efeitos. Fixtures não são contas do usuário. O cenário procedural tem teste próprio apenas como experimento.

Para exportar, instale os templates oficiais 4.7.2, verifique o runtime Windows Node 24, defina `GODOT_BIN` e `NODE_WINDOWS_EXE` e execute `python tools/build_windows.py`. O script cria ZIP Windows e ZIP de código sem banco, credenciais, logs ou caches.

## Progresso e backup

No Docker, o banco está no volume `game_brumora-data`. **Não use `docker compose down -v`.** O nome legado do volume e o banco `brumora.sqlite` foram preservados para manter progresso. Com Node direto, os dados ficam em `server/data`.

O cliente mantém a pasta legada `%APPDATA%/Godot/app_userdata/Brumora — MVP/connection.cfg`, mesmo com a marca TaskMon. Ela contém chaves de sessão; não compartilhe. Pare o servidor antes de fazer backup do banco. Um backup local anterior à atualização foi salvo fora do repositório.

## Escopo atual

Seis espécies de coleção, nove inimigos/chefes, três regiões, equipe, XP, materiais, inventário, aprimoramentos com tempo, GS, perfil, conquistas, arena assíncrona e rodapé. PvP ao vivo, lojas Steam/mobile, evoluções com novas formas, animações desenhadas completas e conteúdo de longa duração continuam sendo etapas futuras. Esta é uma base jogável em desenvolvimento.



A vida da equipe é preservada entre encontros da mesma expedição. Wipe ou retorno encerra a jornada e mostra um resumo de duração, batalhas, abates e ganhos. Iniciar uma nova jornada restaura a equipe uma vez. A viagem usa nome/nível e inspeção por olho junto da criatura, sem os cards inferiores. Velocidade visual e passadas compartilham os parâmetros travel_speed/world_speed_multiplier no inspetor Godot.
