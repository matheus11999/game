# Continuar Brumora no Windows com Codex e Godot

## Abrir a entrega

O ZIP Windows é o jogo pronto para testar: extraia tudo numa pasta gravável, por exemplo `Documentos\Brumora`. Abra `Iniciar-Brumora.bat`. Não abra o jogo diretamente antes de iniciar o servidor. O runtime Node do servidor acompanha esse pacote; não é necessário instalar npm para jogar.

Para testar duas contas ao mesmo tempo, feche a janela iniciada automaticamente, abra `Iniciar-Servidor.bat` e depois execute `Iniciar-Brumora.bat` duas vezes. Registre contas com nomes diferentes. O servidor manual continua aberto até você encerrá-lo. Os duelos desta versão são contra a defesa salva da outra conta, sem controle simultâneo dos dois jogadores.

O servidor escuta somente `127.0.0.1:8787`: os dois clientes precisam estar nesse mesmo computador. Conectar outro computador ou publicar online é uma próxima etapa, com configuração própria.

## Abrir o código no Godot 4.7.2

Se estiver continuando pelo Git, clone `https://github.com/matheus11999/game.git` e abra essa pasta como projeto local no Codex. O ramo de entrega é informado no resultado desta tarefa; use esse ramo antes de importar no Godot.

### Servidor com seu Docker

No terminal, na raiz do repositório:

```powershell
docker compose config --quiet
docker compose up --build -d
docker compose logs -f server
```

Docker Desktop deve estar usando containers Linux. O servidor fica em `http://127.0.0.1:8787`, e o progresso no volume nomeado `brumora-data`. Para parar sem perder dados: `docker compose down`. Não use `docker compose down -v` para um progresso que deseja preservar.

Para executar os testes do servidor usando Docker:

```powershell
docker compose --profile tools run --build --rm test
```

O cliente e o editor Godot rodam diretamente no Windows. Não é necessário instalar Node no PC para o servidor com Docker.

Extraia o ZIP de código numa outra pasta. No Godot, clique em Importar e selecione `project.godot`. Aguarde a importação dos assets e abra `main.tscn`. O botão Executar projeto inicia o cliente; para login e batalhas, o servidor precisa estar aberto.

Para usar o servidor da pasta de código, instale Node.js 24 LTS de fonte oficial e, no terminal aberto nessa pasta, execute:

```powershell
node server/index.ts
```

Você também pode manter o servidor do pacote Windows aberto enquanto executa o cliente pelo editor. Nesse caso, os dados pertencem à pasta do pacote, não à pasta de código. Não execute dois servidores na mesma porta.

## Dar contexto ao Codex local

Abra a pasta do código como projeto no aplicativo ou CLI do Codex. Peça que leia primeiro:

- `AGENTS.md`: decisões persistentes e limites de edição.
- `docs/ART_DIRECTION.md`: estilo aprovado, identidade das criaturas e regras de animação.
- `docs/PLANO.md`: sistemas e próximos marcos.
- `docs/VALIDACAO.md`: evidências e testes ainda pendentes.

Prompt inicial sugerido:

> Continue o projeto Brumora nesta pasta. Estou no Windows com Godot 4.7.2 e tenho Docker Desktop; use Docker Compose para o servidor local. Leia AGENTS.md e os documentos indicados antes de editar. Preserve as criaturas detalhadas, cenários com paralaxe, inimigos próprios e interface de aventura. Use o CLI oficial do Godot para importar e testar. Primeiro verifique o estado atual e os logs; não recrie o projeto nem apague meu progresso. O servidor usa Node 24 no container; execute docker compose up --build -d, confira a saúde e confirme a conexão antes de testar as batalhas. Não inicie outro servidor na porta 8787.

A sessão da nuvem não controla automaticamente o Godot aberto no computador. O Codex local pode trabalhar nos arquivos dessa pasta e usar o CLI instalado. Para verificação visual, será preciso abrir o jogo localmente e inspecionar as telas e animações; uma verificação headless não comprova aparência ou desempenho.

## Preservar progresso

Com Node direto ou o pacote Windows, as contas e o progresso ficam em `server/data` na pasta do servidor. Faça uma cópia dessa pasta com o servidor encerrado antes de substituir uma versão. Com Docker Compose, o progresso fica no volume nomeado `brumora-data` (o Docker pode prefixar o nome com o projeto), montado em `/app/server/data`; copiar a pasta de código não copia esse volume. Pare o serviço antes de fazer backup do volume pelo Docker Desktop ou por uma ferramenta de backup de volumes. `docker compose down` preserva o volume; `docker compose down -v` o apaga. Não envie esse banco ou logs como parte de uma distribuição pública. A conexão salva pelo cliente contém sessão e deve permanecer local.

Teste escolha inicial, movimento e leitura das criaturas, ataques de cada papel, cura, escudo, inimigos das três regiões, mapa, paralaxe, modo rodapé, retomada AFK e duelos entre contas. Anote resolução, escala do Windows, GPU e o problema observado. Consulte `docs/VALIDACAO.md` para distinguir resultados da nuvem dos testes nativos no Windows.
