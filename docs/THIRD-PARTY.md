# Dependências, arte e licenças

- Godot Engine 4.7.2, MIT. Textos em Godot-LICENSE.txt e Godot-COPYRIGHT.txt. Templates Windows oficiais verificados por SHA-256: f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011 (arquivo TPZ).
- Node.js 24.19.0, runtime Windows x64 oficial. ZIP verificado contra SHASUMS256.txt de nodejs.org: 57f71ab3652e797d84acddc79c81cc9ff1c6ddb2a1974cdb83f00fee9bff4c73. Licença e componentes em Node-LICENSE.txt.
- TypeScript e @types/node são ferramentas de desenvolvimento, não dependências de execução do pacote.
- Inter (UI), Pixelify Sans (legado) e Cinzel Decorative (marca/títulos) usam SIL Open Font License. Licenças em assets/fonts/*OFL*.txt. Inter foi obtida do repositório oficial google/fonts (ofl/inter).
- Atlas ilustrados e cenários foram gerados para o projeto com ImageGen, preservando as identidades definidas em ART_DIRECTION.md e ASSET_REGISTRY.md. Os primeiros atlas pequenos são estudos de tools/make_art.py.
- Os movimentos atuais usam malha ponderada e IK procedural, efeitos nativos e poses específicas quando disponibilizadas. Não equivalem a ciclos completos desenhados à mão para todas as espécies.
- Os 45 efeitos sonoros por espécie/ação são síntese original determinística em tools/make_audio.mjs; nenhum sample de jogos concorrentes foi baixado.
- Ícones SVG e skins da UI foram escritos para este projeto.

A marca TaskMon e disponibilidade de domínio não foram verificadas. Não há publicação em lojas nesta entrega.

Alegreya Sans SC Medium: Google Fonts / Huerta Tipográfica, SIL OFL, arquivo local assets/fonts/TaskMon-Interface.ttf; licença TaskMon-Interface-OFL.txt. Fonte upstream https://github.com/google/fonts/tree/main/ofl/alegreyasanssc ; SHA256 532c7dc4bc0fe8109d2c5f17829d9985597aacb86e8001023e045d4ee00f356a. Nome interno/licença de autoria preservados; o nome local identifica seu papel na interface.
