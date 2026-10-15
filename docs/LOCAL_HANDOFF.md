# TaskMon — continuar no Godot local

O projeto está em D:\APPS\game, com Godot 4.7.2 aberto para edição. Use F5 para executar. O atalho TaskMon na Área de Trabalho abre o cliente e inicia/reutiliza o servidor Docker.

Leia AGENTS.md, docs/ART_DIRECTION.md, docs/ASSET_REGISTRY.md, docs/TASKMON_PLANO.md e docs/CREATURE_MOTION.md antes de alterar o jogo.

Estado atual:
- Marca TaskMon; saves, banco e volume legados preservados.
- Cenários ILUSTRADOS em PNG separados em alta resolução. O usuário rejeitou os cenários inteiramente procedurais; não reativar scripts/procedural_world.gd sem novo pedido.
- Rig de malha ponderada em scripts/creature_motion.gd; render dos cenários em scripts/world_painter.gd; combate em scripts/combat_effects.gd.
- UI TaskMon-Interface (Alegreya Sans SC Medium) com ícones e tooltips; Cinzel para marca e títulos.
- XP só por jogo aberto e conectado. Não comprar XP. Aprimoramento com materiais e prazo salvo no servidor.
- Inventário 4 espaços iniciais, empilhamento e baú sem descarte; expansão por moedas.
- GS, perfil, conquistas e prévia de mapas.
- Arena é assíncrona, com poder normalizado. Não anunciar multiplayer ao vivo.

Servidor: docker compose up --build -d. Verificação: docker compose --profile tools run --build --rm test. Typecheck: npm run typecheck --prefix server.

Progresso Docker: volume game_brumora-data, banco brumora.sqlite. Sessão do cliente: %APPDATA%/Godot/app_userdata/Brumora — MVP/connection.cfg. Não renomear esses locais sem migração. Não apagar perfis, bancos ou volume. Dados de testes/capturas/backup não pertencem ao pacote distribuído.

A fonte PNG não impede animações fluidas; a limitação atual é a pose única de cada espécie. Melhorar animação final com partes desenhadas separadas, pivôs e ciclos específicos, preservando a silhueta canônica. Não prometer quadros desenhados inexistentes.

## Entrada no jogo integrado ao editor
No painel de execução do Godot, mantenha **Entrada** ativada na barra superior (tooltip: **Permitir envio de entradas para o jogo**). Se esse controle do editor estiver desligado, mouse e teclado não chegam ao cliente. O Windows local foi verificado com clique real na mochila após ativar Entrada; slots da equipe também foram testados com eventos de mouse roteados pelo viewport, abrindo a ficha inteira.

Economia vigente: XP somente por inimigos abatidos, creditada ao concluir a batalha; não há XP de ticks nem treino. Moedas até três casas decimais, exibição com vírgula; backup do SQLite preservado em antes-economia-abates-20261014, além do backup inicial anterior à primeira atualização.
