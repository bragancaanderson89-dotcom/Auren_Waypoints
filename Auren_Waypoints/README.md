# Auren_Waypoints · Editor 2.3.1

GPS 3D com setas sobre a rota nativa, desaparecimento gradual ao passar, assistência de faixa e editor visual. Recurso independente de framework. O visualizador inclui Three.js localmente e funciona sem CDN, serviços externos ou downloads durante o jogo.

## Instalação e uso

Mantenha `ensure Auren_Waypoints` no `server.cfg`. Depois de copiar esta atualização, execute `refresh` e `restart Auren_Waypoints` no console do servidor. Marque um waypoint e entre em um veículo terrestre. `/gps3d` abre o editor; ESC fecha o diálogo atual e depois o editor.

As opções atuais são persistidas por jogador em KVP `settings:v2`. Preferências antigas de `settings:v1` são migradas automaticamente: cor, tamanho e demais ajustes anteriores são preservados. Use **Restaurar** para experimentar os novos valores padrão.

## Fluidez e posicionamento

- A fase de espaçamento é ancorada em pontos da rota no mundo, para as setas não serem arrastadas junto do carro a cada amostragem.
- A rota é amostrada a cada 2 metros e recebe uma curva B-spline cúbica. Cada seta utiliza a posição e a tangente dessa mesma curva, evitando quinas e angulações independentes nos pontos do GPS. A suavização preserva o corredor da via, altura, cruzamentos e retornos; coordenadas laterais isoladas inconsistentes são filtradas. Uma direção corrigida também atualiza a malha quando o centro permanece parado.
- O efeito de passar pelo carro usa distância longitudinal, curva suave e filtro temporal. Uma seta já ultrapassada mantém seu desaparecimento durante a troca de amostras.
- Setas que saem da amostragem são mantidas até completar sua dissolução. Novas setas entram gradualmente, inclusive durante mudanças de estilo e rota.
- Falhas completas breves de amostragem preservam a última rota válida por 650 ms. Rota inválida nunca é substituída por uma linha reta atravessando prédios.
- A assistência de faixa estima a posição lateral do veículo em relação ao traçado do GPS, suaviza o deslocamento e mantém o último valor em cruzamentos, ré ou desalinhamento. A estimativa é aplicada ao longo das curvas.
- O editor oferece deslocamento manual de -3 a +3 metros, além da correção automática limitada a 8 metros. Valores positivos deslocam para a direita no sentido da rota.
- A faixa é uma estimativa: o native não fornece os limites/polígonos de cada faixa. A posição depende do traçado nativo e do mapa; vias modificadas ou muito largas podem exigir ajuste manual.
- A consulta de solo respeita diferenças de altura para evitar saltos para baixo de pontes ou para cima de túneis. Não há garantia de alinhamento perfeito em estradas com inclinação lateral intensa ou colisão personalizada.

## Editor

O painel mantém a rota funcionando durante os ajustes e oferece:

- Temas Escuro, Branco e Cinza, com seleção no cabeçalho e preferência salva no dispositivo. O tema do painel é independente das cores da rota e do marcador.
- Três abas simples: Visual, Efeitos e Ajustes. Largura/comprimento, desaparecimento, posição e marcador ficam em seções expansíveis.
- Seis formatos: Chevron, Dupla, Direcional, Diamante, Barras e Futurista.
- Quatro presets: Aurora, Neon, Cyber e Essencial.
- Duas cores, degradê, tamanho, largura, comprimento, espaçamento e opacidade.
- Brilho, pulsação, fluxo de luz, rastros, partículas e anel de chegada.
- Velocidade dos efeitos, suavidade de transição e distâncias de dissolução perto do carro e no horizonte.
- Marcadores Farol, Minimalista e Órbita, com tamanho ajustável e movimento interpolado na interface.
- Porsche 992 GT3 RS 2024 do ZIP fornecido pelo usuário, com todas as peças, pintura, texturas, interior e quatro rodas separadas para animação. O modelo anterior foi substituído.
- **Rota 3D**: estrada curva, asfalto, marcações, guard rails, carro, sombras, setas e marcador compartilham uma única cena e câmera de perspectiva. Cor, formato, tamanho, largura/comprimento, deslocamento, opacidade e efeitos são aplicados nessa cena.
- **Carro 3D**: vista isolada do mesmo veículo. Ambos os modos permitem arrastar para girar e rolar para aproximar; o botão ↺ restaura a câmera. A prévia não cria veículos ou entidades no GTA.
- Dependências locais incluídas no `app.js`; o GLB comprimido é carregado da NUI somente ao abrir o editor. Não há CDN nem serviços externos. Imagens renderizadas do mesmo modelo e da estrada mantêm uma prévia estática quando WebGL não inicia.
- Pausa da prévia, desfazer/refazer e restauração do padrão.
- Até oito estilos pessoais por dispositivo, armazenados no navegador NUI. Usar um nome existente substitui o estilo de mesmo nome.
- Importação/exportação em JSON. A exportação abre um campo para copiar; a importação valida opções, cores e limites numéricos.

Os perfis são locais ao dispositivo/NUI; as opções ativas são locais ao jogador via KVP. As três abas são navegáveis com setas do teclado. Ctrl+Z/Ctrl+Y atuam no histórico quando o foco não está em um campo de texto.

O painel usa fundos opacos para manter a legibilidade sobre o jogo. A área fora do painel e o marcador continuam transparentes. A segunda cor aparece somente com Degradê ativo. Esta versão preserva as opções anteriores, a assistência de faixa e a dissolução gradual.

## Desempenho

| Qualidade | Máximo de setas ativas | Efeitos |
| --- | ---: | --- |
| Leve | 24 | Corpo da seta, degradê, pulsação e fluxo; sem halos, rastro e partículas |
| Equilibrada | 42 | Uma camada de halo, rastro e partículas opcionais |
| Ultra | 64 | Segunda camada de halo e demais efeitos opcionais |

O limite também respeita `maximumChevrons` em `config.lua`. As setas em dissolução possuem um orçamento separado de até o mesmo limite. A amostragem de GPS ocorre a cada 90 ms e é dividida entre frames; a renderização ocorre a cada frame. A projeção do marcador envia mensagens a aproximadamente 30 Hz e a NUI interpola em `requestAnimationFrame`.

O alcance padrão é 240 metros e o editor permite de 80 a 400 metros. Alcance maior, espaçamento menor e Ultra aumentam o custo. Não são criados veículos, NPCs, entidades persistentes, objetos de mapa ou fontes de luz dinâmica.

O canvas da NUI permanece transparente. O preview só anima enquanto o editor está aberto. Para testar a interface no navegador fora do jogo, sirva a pasta `web` por HTTP local e abra `index.html?preview=1`; a abertura direta via `file://` pode bloquear a leitura do GLB. Sem o parâmetro, a página permanece oculta.

O modelo fornecido tinha 96.986.628 bytes e 1.721.938 triângulos. A versão para a prévia possui 9.373.856 bytes (aproximadamente 90% menor) e 280.236 triângulos, preservando todas as peças, materiais e texturas. A malha usa compressão Draco, redução de geometria, resolução de texturas apropriada ao editor e quatro pivôs independentes de rodas.

As setas e seus efeitos usam instâncias agrupadas. O renderizador utiliza um único contexto WebGL, limita a resolução de pixels e não redesenha uma prévia pausada quando nada muda. Sombras estáticas são atualizadas ao trocar de vista. Não carrega o GLB enquanto o editor está fechado e reutiliza o veículo ao reabrir.

Three.js r160 mantém os canais UV adicionais do modelo e é incluído localmente sob MIT (`web/vendor/THREE-LICENSE.txt`), em um bundle construído a partir da distribuição ES Modules. Não utiliza o build UMD obsoleto. O decodificador Draco possui seus avisos e licença em `web/vendor/draco`. Créditos e a licença declarada do modelo fornecido, **CC-BY-NC-SA-4.0**, estão preservados em `web/models/MODEL-CREDITS.txt` e nos metadados do GLB; essa licença também identifica a adaptação da malha. Autor declarado: vecarz. As imagens de reserva foram renderizadas a partir desse modelo.

Na primeira abertura, o painel aparece antes da inicialização do WebGL. A imagem local permanece visível com indicação de progresso enquanto cada material é preparado em uma tarefa separada. A compilação usa `compileAsync` e a extensão `KHR_parallel_shader_compile` quando disponível; as variantes com e sem sombras são preparadas antes de mostrar o 3D. Os reflexos originais usam um atlas local de aproximadamente 40 KB, evitando gerar o ambiente por PMREM em cada cliente. Fechar o editor suspende as próximas etapas; reabrir retoma o trabalho e reutiliza o veículo carregado. O tempo de preparação e eventuais pausas do driver dependem da GPU/CEF.

## Integração

Exports de cliente preservados:

```lua
exports.Auren_Waypoints:OpenSettings()
exports.Auren_Waypoints:SetDestination(vec3(2555.0, 329.0, 108.0), 'BASE PRF')
exports.Auren_Waypoints:ClearDestination()
exports.Auren_Waypoints:SetVisible(false)
exports.Auren_Waypoints:SetVisible(true)
local settings = exports.Auren_Waypoints:GetSettings()
```

`SetDestination` cria um blip próprio com rota. `ClearDestination` remove somente esse blip e preserva o waypoint manual. A chegada limpa o destino criado por export; o waypoint manual continua gerenciado pelo GTA. `SetVisible(false)` oculta imediatamente, para outras interfaces poderem controlar a visibilidade.

Mantém o comando e exports usados pelo adaptador previamente instalado em `pickle_waypoints`. Esta atualização não modifica outros recursos nem instala esse adaptador. O recurso oculta a rota durante pausa, seleção de personagem, outras telas com foco NUI, morte, telas apagadas e aeronaves/embarcações.

## Validação

A atualização foi verificada com Lua 5.4 e natives simulados: sanitização das opções, geometrias e orientação dos triângulos, rampas, fase ancorada, continuidade de transparência, filtro de viradas isoladas, dissolução ao passar, orçamento de saída, acompanhamento de faixa, cruzamentos, falha temporária do GPS, troca de estilo, remoção do waypoint e pausa. A interface foi exercitada em Chromium, incluindo os três temas e sua persistência, independência entre tema e cor da rota, seções expansíveis, visibilidade da segunda cor, renderização do carro em 3D, presets, histórico, estilos locais, importação/exportação, layout em 720p e tela estreita, marcador e estado oculto inicial.

Também foram verificadas continuidade da tangente nos pontos da spline, curva de rodovia, rejeição de um ponto lateral incorreto, cruzamento de 90 graus, retorno, rampa e correção de orientação sem mudança de posição.

A cena completa foi exercitada em WebGL 1: GLB/Draco com quatro rodas, rotação, zoom, restauração da câmera, temas, efeitos ao vivo, desligamento das setas e deslocamento lateral. A troca repetida dos seis formatos não acumulou geometrias na GPU; pausar ou fechar suspendeu o redesenho; reabrir não solicitou o modelo novamente. Os testes locais não registraram erros gráficos nem requisições externas. O modo sem WebGL manteve a prévia e os controles ativos.

A correção de abertura também foi exercitada com mudanças de tema, preset e visualização durante a preparação dos materiais, fechamento antes da conclusão e retomada ao reabrir. O aviso sobre `build/three.js`/`build/three.min.js` deixou de ocorrer. O GLB completo e suas texturas permanecem idênticos à versão 2.3.

Esses testes não substituem a confirmação visual dentro do FiveM. Depois do restart, conferir: rodovia em cada faixa, troca de faixa, curvas fechadas, cruzamentos, pontes/túneis, ré, movimento em alta velocidade, novo waypoint, remoção, chegada, pausa, reconexão e exports. Verificar custo com `resmon 1` na configuração gráfica usada pelo servidor.

Referências dos natives:

- [GET_POS_ALONG_GPS_TYPE_ROUTE](https://github.com/citizenfx/natives/blob/master/PATHFIND/GetPosAlongGpsTypeRoute.md): slot 0 para waypoint manual e slot 1 para destino roteado. Compatível com o alias antigo `GET_GPS_WAYPOINT_ROUTE_END`.
- [DRAW_POLY](https://github.com/citizenfx/natives/blob/master/GRAPHICS/DrawPoly.md): malhas com orientação dos triângulos para cima da via.
