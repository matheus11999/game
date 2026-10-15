# Registro canônico de arte — TaskMon

Este arquivo é a memória persistente de arte do projeto. Consultar ANTES de gerar imagens. Um item deve sempre reutilizar seu asset canônico; não regenerar o mesmo item em estilos diferentes. Atualizar este registro somente quando uma substituição for aprovada ou explicitamente solicitada.

- Referência de mundo: assets/worlds.png (3 regiões; preservar paleta e arquitetura).
- Referência de criaturas: assets/creatures-detailed.png. Substituição solicitada nesta revisão: assets/creatures-taskmon.png (seis espécies, 3 colunas por 2 linhas, transparência real).
- Inimigos: assets/enemies.png; índices em assets/enemies.json. Não misturar espécies de coleção com inimigos.
- Ícones canônicos: assets/icons/*.svg. Sistema vetorial de traço dourado 32×32, contorno 2px; estender o sistema, não gerar versões bitmap do mesmo ícone.
- Materiais: assets/materials.json associa IDs estáveis aos ícones e cores. essence=spark; fibre=leaf; pearl=orb; shard=crystal; core=core; sigil=shield. A imagem de um material é SEMPRE esse ícone com essa cor.
- Categorias: Atacante=sword; Tank=shield; Suporte=heart.
- Atributos: vida=heart, ataque=sword, defesa=shield, velocidade=boot. Números ao lado dos ícones; nomes completos em tooltips.
- Novas imagens devem conservar silhueta, expressão, cor de material e orientação da espécie original. Sprites em três quartos; transparência; corpo inteiro; sem chão pintado na célula. Manter os arquivos anteriores como referência.
- Não chamar animação de quadros desenhados quando for deformação, deslocamento, partículas ou efeito de shader.

Registro das espécies: Fagulim=raposa âmbar/cauda de brasa; Musgudo=tartaruga jardim verde/rochas; Lunélia=mariposa lavanda/lua; Marulito=axolote turquesa/guelras lilases; Pedrume=golem pedra violeta/cristais; Nimbico=coruja creme/asas azul-esverdeadas.

## Decisão vigente: cenário ilustrado
O usuário rejeitou o cenário totalmente procedural. Manter os PNGs regionais de alta resolução e o chão detalhado alinhado. scripts/procedural_world.gd é experimento desativado; não usar como direção visual atual.
TaskMon-Interface.ttf / TaskMon-Interface-OFL.txt são a tipografia de UI. Cinzel somente marca/títulos. Reutilizar os SVG canônicos dos materiais. A mudança de fonte não autoriza redesenhar itens existentes.

## Fagulim — postura quadrúpede
assets/animations/ember-locomotion.png é a folha canônica 3×2: em pé, passo A, passagem, passo B, levantar/sentar, piscar em pé. Gerada com skill imagegen embutida, referência creatures-taskmon.png; prompt: preservar raposa âmbar, orelhas escuras, peito creme e cauda de fogo, quatro patas, mesma câmera e escala, seis poses, fundo transparente. Pose sentada original só em repouso. Não regenerar esse mesmo ciclo com outra identidade. assets/animations/ember-attack.png mantém quatro poses de ataque.


Ciclo vigente Fagulim: assets/animations/ember-locomotion-v2.png, 4×3, doze poses: 0 em pé; 1–8 passos sequenciais; 9 levantar/sentar; 10 piscar; 11 dano. Folha anterior de seis poses preservada como referência. Tool embutida imagegen, prompt: ampliar a folha canônica para oito fases de caminhada quadrúpede mantendo identidade, câmera e alpha; incluir transição, blink e dano. Runtime usa doze quadros por segundo nos oito passos e rig contínuo nas demais espécies.


## Vocabulário de recompensas e inspeção — vetores canônicos
- gold/coin = assets/icons/coin.svg: moeda dourada com relevo de folha, duas bordas e luz creme. O mesmo SVG deve ser reutilizado no HUD, ganhos transitórios e resumos. Não usar orb como moeda nova; orb continua material Pérola de maré.
- xp = assets/icons/xp.svg: cristal verde/lavanda com folha clara. Reutilizar em ganhos de experiência e resumo de expedição. Não substituir materiais existentes por esse símbolo.
- eye = assets/icons/eye.svg: olho dourado/verde para abrir detalhes da criatura no mundo. Uso estável em todos os controles de inspeção.
Os três SVGs são arte vetorial original de 32×32, sem geração raster. Folhagem das molduras é desenho geométrico determinístico em scripts/menu_chrome.gd, com três cantos espelhados e paleta dourado/verde; manter a composição consistente entre menus.


Correção final do movimento: o ciclo rápido da raposa foi rejeitado. A locomoção ativa usa o quadro quadrúpede 0 de ember-locomotion-v2.png com rig contínuo de quatro apoios a 0,90 Hz; a referência de oito quadros permanece arquivada na folha. Postura de levantar/sentar usa quadro9, danoquadro11, olhos pelo rig calibrado equadrosstandblink. Não reativar ciclo de corrida automaticamente.


## Molduras botânicas vetoriais reutilizáveis
- assets/ui/hero-leaf.svg: hero de criaturas e prévia regional dos resumos, contorno curvo e folhas de canto.
- assets/ui/stat-leaf.svg: medalhões horizontais para atributos, métricas e recompensas.
- assets/ui/gear-leaf.svg: emblema GS botânico, substitui moldura de degraus; nomes/valores são texto de runtime.
- assets/ui/progress-vine.svg e progress-satin.svg: trilho de vinha e preenchimento acetinado da Descoberta. Reutilizar esses vetores; progresso vem de estado e interpolação, não de arte diferente para cada valor.
## Peças autorais — revisão de animação de 15 de outubro

As quinze espécies possuem folhas próprias `assets/rigs/{id}-parts.png`. Elas são partes anatômicas redesenhadas, com superfícies ocultas e sobreposição, não recortes das criaturas completas. As folhas originais são preservadas como referência de identidade e retratos. Prompts integrais em `docs/ART_PROMPTS_PARTS.md`.

Montagem nativa: `scripts/creature_rig.gd`, `scripts/creature_rig_pool.gd`. Coordenadas/pivôs por espécie em `rig-metadata.json` (Fagulim), `rig-species.json` (demais iniciais e Espinbroto), `rig-enemies.json` (oito inimigos restantes). O layout lógico é 4×3, mas dimensões e limites de partes variam; reutilizar as janelas explícitas do metadata. Não assumir células quadradas nem produzir versões alternativas do mesmo monstro sem consultar esta memória.

Esta decisão substitui as recomendações anteriores de rig sobre o PNG completo. A existência da folha e dos ossos não significa aprovação artística: verificar encaixe, volume, passos e transições no Godot.

## Substituição solicitada: Fagulim monstro de brasa e folhas (15/10/2026)

O usuário rejeitou a raposa comum e solicitou seu redesenho. **Nova referência canônica de Fagulim: `assets/ember-taskmon.png`**, monstro quadrúpede âmbar/creme, placas de folhas jade/carbonizadas com veios incandescentes, orelhas em folha e cauda enrolada de semente flamejante. `assets/rigs/ember-parts.png` foi redesenhado a partir desse conceito com as doze partes e quatro expressões da cabeça. Manter os mesmos materiais e face entre retratos e animação; não usar mais o Fagulim comum do atlas em produção. A aprovação artística final depende da avaliação do usuário.

Esta seção substitui as instruções anteriores sobre a identidade de Fagulim e o uso de ember-locomotion-v2.png/ember-attack.png. Esses arquivos e o Fagulim no atlas antigo são referências históricas; não reativar seu caminho de animação. As outras catorze espécies preservam identidade. Backend ativo: creature_rig_pool.gd + creature_rig.gd, integrado ao main.gd. Orientação da arte vem de faces_left no metadata, não do atlas legado.
