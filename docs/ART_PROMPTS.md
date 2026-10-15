# TaskMon — registro de produção de imagens desta revisão

Ferramenta: imagegen embutida, modo de edição com referências locais; fundo transparente solicitado. Saídas finais copiadas para o repositório, sem apagar as referências. PNGs são arte de referência e poses; o rig produz a locomoção contínua final.

## Folha canônica quadrúpede

Arquivo: `assets/animations/ember-locomotion-v2.png` (1536×1024, RGBA, 4×3). Referência: `assets/animations/ember-locomotion.png`. A folha anterior deriva da raposa em `assets/creatures-taskmon.png`.

Prompt final enviado:

> Edit the referenced amber fire fox locomotion spritesheet to a MORE COMPLETE ANIMATION SPRITESHEET. Preserve exact fox identity and crisp detailed pixel-art style, orange quadruped, cream chest/muzzle, black lower legs, huge dark brown ears, flame tail. Transparent alpha. NEW STRICT GRID 4 COLUMNS x3ROWS =12 equally sized cells, consistent camera facing RIGHT three-quarter side view, same scale/head/body/ground baseline in each frame. All whole bodies have generous transparent margins, no touching neighboring cells. Frame0 row1col1 neutral STANDING ON FOUR PAWS. Frames1 through8 (remaining row1 plus row2 plus row3col1): EIGHT DISTINCT SEQUENTIAL PHASES of a natural quadruped WALK CYCLE, legs change genuinely each frame, rear end raised, belly off ground, never seated during walking, alternating support/swing, restrained torso movement, continuous flame tail. Frame9 row3col2: rise/sit intermediate crouch with hindquarters halfway lowered and front legs planted. Frame10 row3col3: neutral standing EYES CLOSED blink. Frame11 row3col4: standing recoiling from damage, eyes wince, head back, paws grounded. Exact equal cell layout, no letters/numbers/lines, no backdrop or floor or glow field. This is a game production motion sheet to replace only the six frame walking sheet. Every animation frame is the SAME CHARACTER. No attack flame balls.

## Decisão de integração

O usuário rejeitou a aparência acelerada do flipbook. O quadro 0 recebe agora rig quadrúpede contínuo, quatro apoios, velocidade ligada ao terreno e cadência base de 0,90 Hz. Os demais quadros ficam preservados; as poses de transição e dano continuam disponíveis. Não descrever os oito quadros arquivados como ciclo de caminhada ativo.

Moeda, XP, inspeção e molduras de folhagem são SVGs desenhados em código, seguindo o sistema vetorial existente. Seus caminhos e papéis estão no ASSET_REGISTRY.md; não foram regenerados como imagens raster.
