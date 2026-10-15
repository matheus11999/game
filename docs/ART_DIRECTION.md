# Brumora — direção de arte persistente

## Preferência do usuário

O jogo deve ter criaturas estilizadas e detalhadas, mantendo consistência entre espécies e animações. A primeira apresentação foi rejeitada por parecer simples e semelhante a um site/painel. A interface deve parecer um jogo de aventura: mundo ocupando a tela, tipografia própria, ornamentação discreta e HUD contextual. Não voltar à apresentação de dashboard.

## Referências internas

- `docs/art-direction.png`: conceito original do mundo e das seis criaturas.
- `assets/creatures-detailed.png`: atlas transparente detalhado, três colunas por duas linhas. Ordem: Fagulim, Musgudo, Lunélia; Marulito, Pedrume, Nimbico.
- `assets/worlds.png`: cenários regionais empilhados em três faixas: Prado das Lanternas, Costa de Vidro, Ruínas do Luar.
- `assets/enemies.png`: nove inimigos e chefes; atlas em três colunas e três linhas, indexado por `assets/enemies.json`.
- `assets/creatures.png`: primeiros sprites pequenos, preservados como estudo/protótipo; não são a direção final.

## Regras visuais

Paleta: azul-marinho nos contornos e sombras, verde-menta nos materiais do bosque, âmbar nas brasas e destaques, lavanda no luar/cristal, creme nas luzes. Cada criatura tem uma cor dominante e 3–4 níveis de valor por material. Evitar degradês fotográficos, assets de estilos misturados e elementos de franquias existentes.

Fagulim: raposa âmbar, orelhas escuras e cauda de brasa. Musgudo: tartaruga arredondada, casco com jardim e rochas; massa corporal protetora. Lunélia: mariposa lavanda, antenas e asas amplas, brilho de cura. Marulito: axolote turquesa com guelras lilases. Pedrume: golem compacto de pedra violeta com cristais. Nimbico: coruja creme com asas azul-esverdeadas.

Sprites devem ter fundo transparente, margens suficientes, expressão legível em escala de jogo e corpo completo dentro da célula do atlas. Não introduzir chão, texto, sombra de fundo pintada ou outro personagem na célula. Manter uma vista de três quartos consistente. Referenciar a imagem original ao gerar novas poses.

## Interface

O cenário tem prioridade. Controles se apresentam como placas, runas, emblemas e barras de combate. Usar Cinzel Decorative para a marca e Pixelify Sans para a interface. Preferir bordas angulares e detalhes em ouro envelhecido a cartões arredondados de aplicativos web. Textos de infraestrutura ficam no diálogo de conexão, não dominam o fluxo de jogo.

## Animação

Movimentos suaves: flutuação, respiração e deslocamento; ataques com avanço e retorno; dano com recuo breve; números que sobem e desaparecem; cura com partículas verdes; escudo com arco azul e pulso; barras de vida interpoladas. Meta de atualização 60 FPS quando visível, reduzida ao minimizar. O atlas detalhado inicial contém poses estáticas; animação de partes e ciclos completos de poses é uma evolução artística posterior. Não afirmar que contém quadros de caminhada ou ataque que não foram produzidos.

## Revisão

Conferir o asset em tamanho real e dentro do jogo; verificar transparência, enquadramento, silhuetas, escala, paleta, legibilidade, clipping e uso em combate/rodapé. Capturar telas reais após mudanças. Esta documentação e `AGENTS.md` preservam as decisões para futuras tarefas; não dependem de memória externa do chat.
