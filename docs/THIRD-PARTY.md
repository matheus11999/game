# Dependências e arte

- Godot Engine 4.7.2, licença MIT. Texto em `Godot-LICENSE.txt`; licenças dos componentes incluídos: https://godotengine.org/license/ e https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt .
- Node.js 24.19.0: licenças do runtime e componentes em `Node-LICENSE.txt`, extraído do arquivo oficial Windows.
- TypeScript e @types/node são ferramentas de desenvolvimento, não incluídas como dependências de execução no pacote Windows.
- Os primeiros atlas pequenos, tiles e props foram desenhados especificamente para este projeto por código em `tools/make_art.py`; preservados como estudos.
- A direção visual, atlas detalhado de criaturas, inimigos e cenários regionais foram gerados com a ferramenta de geração de imagens nesta sessão e são usados no cliente. Movimentos e efeitos são animados por código; as poses ilustradas não constituem ciclos completos desenhados quadro a quadro.
- Pixelify Sans e Cinzel Decorative usam SIL Open Font License; arquivos em `assets/fonts/Pixelify-OFL.txt` e `assets/fonts/Cinzel-OFL.txt`.
- Os dois efeitos sonoros foram sintetizados especificamente para este projeto. Não foram baixados assets ou sons de jogos concorrentes.

Hashes oficiais dos templates Godot e do runtime Node foram conferidos antes do empacotamento. A marca Brumora e seu domínio ainda não foram validados.
