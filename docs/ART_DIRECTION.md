# TaskMon — direção de arte vigente

## Escolha final do usuário

Manter a fantasia ilustrada detalhada dos cenários antigos, agora com um PNG de alta resolução por região. O experimento de terreno totalmente procedural foi explicitamente rejeitado por parecer feio e conter objetos flutuantes. NÃO reativar esse renderer sem novo pedido.

A interface deve ser de jogo de aventura, discreta e legível: mundo em destaque, ícones com tooltips, cards de criaturas, HUD própria de combate e estados claros. Não usar textos redundantes em todos os botões nem ornamentos grossos repetidos. TaskMon-Interface (Alegreya Sans SC Medium) em controles e textos; Cinzel na marca e títulos. Pixelify permanece no repositório como estudo anterior.

## Assets canônicos

Consultar sempre docs/ASSET_REGISTRY.md e assets/art-manifest.json antes de gerar ou trocar imagens. Os IDs dos materiais são estáveis; reutilizar o mesmo ícone, cor e arquivo para cada item. A memória visual pertence ao repositório.

- assets/creatures-taskmon.png: seis espécies, 3 colunas por 2 linhas, transparência. assets/creatures-detailed.png é a referência anterior preservada.
- assets/enemies.png: nove inimigos, com recortes por linhas específicos e atlas indexado por enemies.json.
- assets/world-forest.png, assets/world-coast.png, assets/world-ruins.png: três panoramas independentes de alta resolução. assets/worlds.png é referência/legado.
- assets/ground-taskmon.png: chão detalhado por região, contato alinhado com pés e sombras.
- assets/icons/*.svg: sistema consistente de traço dourado, incluindo atributos e materiais.
- assets/audio/*: sons originais por espécie e ação; gerador determinístico em tools/make_audio.mjs.

## Identidades

Fagulim: raposa âmbar, orelhas escuras, peito creme e cauda de brasa. Musgudo: tartaruga verde, jardim e rochas no casco, massa protetora. Lunélia: mariposa lavanda, antenas e asas lunares. Marulito: axolote turquesa, guelras lilases. Pedrume: golem compacto de pedra violeta e ametistas. Nimbico: coruja creme com asas azul-esverdeadas.

Preservar silhueta, cores dos materiais, expressão e escala relativa. Sprites devem ter corpo inteiro em três quartos, transparência e margem para não invadir células vizinhas. Não pintar chão nem fundos opacos nas células.

## Movimento e efeitos

Rig de malha com pesos anatômicos e IK de membros em scripts/creature_motion.gd. Apoio e retorno dos pés separados, cabeça/corpo coerentes, partes secundárias articuladas, voo e idle por espécie. Não deformar o torso inteiro como borracha. Durante ataque: preparação, emissão, projétil com trajetória própria, impacto e recuperação. Danos, sons, HP e morte devem seguir o momento do impacto. Aparição e desaparecimento não reiniciam a cada turno: a identidade de batalha é estável.

O rig não cria poses laterais inexistentes no atlas. Para animação final, usar partes desenhadas separadas ou sequências de poses aprovadas; manter o rig como complemento, sem alegar que a arte estática contém quadros que não existem.

## Verificação

Conferir transparência, corte de atlas, contato no chão, escala, contraste, tipografia, clipping e ausência de sprites no combate/rodapé. Capturar telas reais no Godot. O alvo é 60 FPS; medições devem citar hardware e cena, sem prometer desempenho em outras máquinas.

## HUD pixelado — revisão de combate
Título da exploração sem painel: Cinzel dourado com contorno escuro e sublinhado curto. Comandos de combate exclusivamente por ícones centralizados, com tooltip. Botões usam SVG vetorial suave com cantos discretamente arredondados, filete fino e estados coerentes; ícones sem texto são centralizados nos dois eixos. A textura dos botões usa filtro linear para evitar serrilhado. HP com cantos pixelados, brilho superior, marcas de segmentos e trilha de dano; GS com emblema e valor destacado. Escudo envolve o corpo; cura usa fluxos ascendentes sem cruzes repetidas.


## Cartas e leitura — refinamento atual
Slots da equipe são clicáveis por inteiro: retrato, nome, categoria, nível e XP. Atributos, GS, passiva, ativa e aprimoramento ficam na ficha vertical compacta. TaskMon-Interface (Alegreya Sans SC Medium) é herdada pela janela, diálogos, tooltips e campos de texto, sem fallback do sistema; Cinzel fica nos títulos. Botões nativos e seus estados preservam o mesmo desenho vetorial e foco de teclado.

## Menus finais e carta ilustrada
Menus compartilham scripts/menu_chrome.gd: superfície escura em camadas discretas, ilustração regional de baixa opacidade, cabeçalho Cinzel, botão de fechar por ícone realmente centralizado e conteúdo com margens reservadas. A ficha tem retrato central ambientado, emblema GS, atributos alinhados e custos junto da ação. O inventário é compacto, sem lista repetida dos materiais; nomes e origens ficam em tooltips. Barra Descoberta combina progresso, distância e estado em uma placa baixa sem ornamentos extras.

## Fantasia botânica coesa e resumos
Molduras compartilham ramos e folhas discretos nos cantos, desenhados manualmente em vetor, com superfícies verde-azul profundas e acentos dourados envelhecidos. A ilustração regional continua de baixa opacidade atrás do conteúdo; retratos e resultados usam a mesma moldura e hierarquia. Moeda com folha em relevo e XP cristal/folha são símbolos canônicos próprios. O resumo de expedição reúne prévia regional, tempo, abates, batalhas e ganhos em blocos iconográficos, preservando números recebidos do servidor; derrota apresenta retorno/reagrupamento, sem descartar ganhos guardados.


## Jornada e tipografia atuais
TaskMon-Interface.ttf (Alegreya Sans SC Medium licenciada) é a fonte ativa de corpo, controles e números. Cinzel para títulos. Nenhuma Arial ou fallback de sistema. Durante exploração, cenário amplo substitui cards inferiores; nomes/níveis e olhos de inspeção acompanham as criaturas. Encontro mantém o cenário, aproxima a câmera e para a equipe. A fonte e molduras com folhagem são parte do padrão compartilhado, inclusive resumo de expedição e feedback de ganhos.


## Crítica recebida e revisão botânica de composição
O usuário rejeitou as versões anteriores da ficha, resumo e emblema GS por parecerem caixas básicas com texto sobre fundo. Essa rejeição não equivale a aprovação da versão seguinte. A nova composição usa hero ilustrado com moldura curva de folhas, atributos em quatro medalhões flutuantes, GS com emblema botânico sem degraus pixelados, e leitura compacta em duas colunas. Resumos reaproveitam os mesmos medalhões e molduras; a barra Descoberta usa arte vetorial de vinha e tecido acetinado com valor contínuo fornecido pelo cliente. Conferir capturas reais e aguardar avaliação do usuário; não inflar notas nem declarar qualidade final sem evidência.
