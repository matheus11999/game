# Brumora — MVP 0.1

Jogo nativo de criaturas em pixel art, expedições AFK e intervenção tática. Windows é o primeiro alvo. Cliente Godot 4.7.2 + GDScript; servidor Node.js 24 + TypeScript; persistência SQLite local.

## Testar no Windows

1. Extraia **toda** a pasta do ZIP `Brumora-MVP-Windows-x64.zip` para uma pasta gravável, como Documentos. Não execute de dentro do ZIP.
2. Abra `Iniciar-Brumora.bat`. O runtime Node está incluído: não precisa instalar Godot, Node ou abrir navegador.
3. Digite um nome, escolha Fagulim (ataque), Musgudo (tanque) ou Lunélia (cura).
4. Clique **Partir em expedição**. A cada 20 segundos recebe moedas/XP; a cada 60 segundos encontra outra criatura. Há três vagas na equipe.
5. Use **Intervir na rota**, **Habilidade**, **Proteger** ou **Auto** para testar combate. Vença chefes para abrir as outras regiões.
6. Use **Conexão → Criar outra caravana** para testar um segundo jogador. Você poderá alternar entre as caravanas salvas e desafiar a primeira na Arena.

O launcher encerra o servidor que ele próprio iniciou quando o jogo fecha. Recompensas AFK serão calculadas na próxima abertura, por até 8 horas. Para manter o servidor independente e testar várias janelas, execute `Iniciar-Servidor.bat` primeiro e deixe sua janela aberta. Depois abra o jogo pelo launcher; ele reutiliza o servidor existente. Ctrl+C na janela do servidor encerra esse processo.

O pacote é um MVP ainda sem assinatura digital. A validação de Windows nativo está pendente; o aplicativo foi exportado na nuvem e seus fluxos foram testados no Godot/Linux. Os executáveis exigem Windows x64 compatível com Godot 4.6 e suporte OpenGL 3.3.

## O que está implementado

- Seis espécies originais, três iniciais e equipe de até três membros.
- Vida, ataque, defesa, velocidade; indivíduos 0–15 por atributo; quatro raridades; aparência luminosa cosmética.
- Níveis 1–20, XP e treino por moedas obtidas no jogo.
- Habilidades de dano, cura e escudo, recargas, crítico e iniciativa por velocidade.
- Três cenários detalhados, paralaxe, marcos de viagem, caravana em movimento, criaturas detalhadas e efeitos sonoros próprios.
- Exploração AFK, retorno após reinício e limite de coleção de 80 criaturas.
- Nove inimigos/chefes com arte própria e efeitos distintos; PvE manual/automático e desbloqueio de rotas.
- Modo rodapé com batalhas automáticas, avanço após vitória e retomada da viagem.
- Contas locais persistentes, troca de caravanas, duelos assíncronos entre contas, ranking e Hall de exploradores.
- Servidor autoritativo, autenticação por chave de sessão e ações idempotentes.

## Limites desta versão

Não há PvP ao vivo, amigos/convites Steam, temporadas, evolução visual, negociação, publicação nas lojas ou builds mobile. O mapa é uma rota lateral automática, não um mundo controlável com teclado. Os atlas detalhados têm poses ilustradas; seus movimentos, respiração e efeitos são animados no cliente. Ciclos completos com desenhos diferentes de caminhada/ataque permanecem uma evolução artística futura. O servidor local é de protótipo: o dono do computador controla arquivos e relógio. Ele não deve ser exposto diretamente à Internet.

O jogo compartilha projeto e dados para futuros builds mobile, mas interfaces touch, ciclo de vida, assinaturas, plugins das lojas e testes em aparelhos ainda serão necessários. Para iOS, é necessário Mac com Xcode.

## Dados e recuperação

- Servidor: `server/data/brumora.sqlite`, `brumora.sqlite-wal` e `brumora.sqlite-shm` quando presentes.
- Cliente: `%APPDATA%/Godot/app_userdata/Brumora — MVP/connection.cfg` guarda as chaves de acesso às caravanas. Não compartilhe esse arquivo.
- Para backup, encerre servidor e jogo e copie `server/data` e `connection.cfg`. O ZIP distribuído não contém contas de teste, banco, chaves ou logs.
- Se aparecer sem conexão, confirme que o servidor está rodando e o endereço em **Conexão** é `http://127.0.0.1:8787`.
- Se outro serviço ocupa a porta, encerre o serviço conflitante ou inicie o servidor com `BRUMORA_PORT` e altere a URL no cliente.

## Desenvolvimento

### Servidor com Docker Desktop

Na raiz deste repositório, usando containers Linux:

```sh
docker compose up --build -d
docker compose logs -f server
```

Testes do servidor sem instalar Node no host:

```sh
docker compose --profile tools run --build --rm test
```

Abra `project.godot` no Godot **4.7.2** e pressione **F6** na cena `main.tscn` ou **F5** para o projeto. O cliente usa `http://127.0.0.1:8787`. Não é necessário instalar Node no Windows quando o servidor roda no Docker. O volume `brumora-data` guarda o progresso. `docker compose down` para o servidor preserva o volume; não use `down -v` se quiser manter os dados.

O Docker executa o servidor; o jogo e o editor Godot continuam nativos no Windows. A execução Docker deve ser validada localmente se o ambiente de nuvem não oferecer daemon Docker.

Para a próxima IA, leia primeiro `AGENTS.md`, `docs/LOCAL_HANDOFF.md`, `docs/ART_DIRECTION.md` e `docs/VALIDACAO.md`. As decisões de arte e o estado real de implementação estão persistidos nesses arquivos.

### Servidor sem Docker

Abra `project.godot` com Godot 4.7.2. No terminal, dentro de `server`:

```sh
npm ci
npm test
npm run typecheck
npm start
```

O runtime precisa ser Node 24 ou superior, com suporte nativo a TypeScript e `node:sqlite`. Nenhuma dependência npm é necessária para executar o servidor; as dependências fixadas no lockfile são apenas para verificação estática.

Para recriar os atlas: Python 3 + Pillow, `python tools/make_art.py`. Para exportar: templates oficiais Godot 4.7.2 instalados, runtime Windows Node verificado e `NODE_WINDOWS_EXE` definido; execute `python tools/build_windows.py`. Consulte `docs/THIRD-PARTY.md` para licenças.

O teste `tests/ui_smoke.gd` usa a instância local de servidor, cria uma conta de teste e verifica fluxos do cliente. Ele deve ser rodado numa base de desenvolvimento, não numa base de produção. Capturas vão para `user://test-captures`; a variável `BRUMORA_CAPTURE_DIR` permite escolher outra pasta.

Planejamento completo em `docs/PLANO.md`; evidências e limitações em `docs/VALIDACAO.md`.
