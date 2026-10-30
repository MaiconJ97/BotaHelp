# BotaHelp

[Español](README.md) | Português (Brasil)

BotaHelp reúne rotinas AutoLISP para gerar manobras BOTA e concordâncias
segmentadas no Autodesk AutoCAD e no Civil 3D. O código está em
[`bota_help.lsp`](bota_help.lsp).

A manobra BOTA é um giro de uma máquina de pulverização cujo objetivo é
cobrir todo o talhão sem deixar áreas sem pulverizar. O traçado considera
o raio de giro e a largura do implemento. No BOTA3, o fillet que conecta
o giro à linha guia deve manter essa cobertura também no espaço intermediário
da conexão.

## Demonstração

https://github.com/user-attachments/assets/1eb176cd-32e1-4d61-b700-52f162321f60

## Instalação

Escolha como deseja usar o BotaHelp:

| Forma de uso | Comando de carregamento | Arquivo |
| --- | --- | --- |
| Ribbon completo, com botões, configuração, ajuda e comandos | `NETLOAD` | A DLL disponível em [Releases](https://github.com/MaiconJ97/BotaHelp/releases/latest). |
| Somente os comandos, sem a guia Ribbon | `APPLOAD` | `bota_help.lsp`. |

### Ribbon completo

1. Baixe [BotaHelp-1.0.25.dll](https://github.com/MaiconJ97/BotaHelp/releases/download/v1.0.25/BotaHelp-1.0.25.dll)
   e salve em uma pasta permanente onde você tenha permissão de escrita.
2. No Civil 3D/AutoCAD 2026 (x64, .NET 8), execute `NETLOAD` e selecione essa DLL.
3. Abra a guia **BotaHelp** para usar os botões. Se o Ribbon estiver oculto,
   digite `BOTAHELP`.

A DLL inclui o código AutoLISP e os comandos. Para essa opção, basta carregar
a DLL. Se for substituir uma versão já carregada, feche o Civil 3D/AutoCAD
e abra novamente antes de carregar a nova versão.

### Somente os comandos

1. No AutoCAD ou no Civil 3D, execute `APPLOAD`.
2. Carregue `bota_help.lsp`.
3. Digite `BOTAH` para abrir a ajuda resumida ou `BOTAC` para configurar
   os valores antes de executar uma manobra.

Essa opção permite executar os comandos pelo nome e não cria a guia Ribbon.

### Compilar a DLL (opcional)

Você também pode gerar a DLL a partir do código-fonte. No PowerShell,
na raiz do repositório:

```powershell
.\ribbon\build.ps1
```

Para compilar, é necessário ter um SDK .NET 8, Node.js e as bibliotecas
do AutoCAD 2026 instaladas. O script executa as verificações e gera
`dist/BotaHelp.dll`, que deve ser carregada com `NETLOAD`. Acrescente
`-SkipChecks` para compilar sem executar as verificações. Os arquivos compilados
são gerados no seu computador; as DLLs para download são distribuídas em
Releases. As [instruções da DLL](ribbon/README.md), em espanhol, explicam
a compilação e o carregamento.

Os comandos trabalham no plano XY e geram polilinhas abertas. Trabalhe
com cópias das entidades originais enquanto confere cada manobra.

## Comandos

| Comando | Uso |
| --- | --- |
| `BOTA` | Manobra segmentada manual. Selecione a cabeceira e depois o ponto/vértice que o círculo externo do implemento deve tocar. |
| `BOTA2` (`B2`) | Manobra definida por uma cabeceira e uma linha guia. O primeiro clique na cabeceira define o lado do giro; o clique na guia define a referência do offset oposto. |
| `BOTAM` (BotaM) | Manobra do BOTA2 com um ponto adicional para indicar manualmente o lado do giro. |
| `BOTA3` (`B3`) | Variante do `BOTA2` que acrescenta uma concordância (fillet) automática até a linha guia. |
| `BOTAFILLET` (`BOTAF`, `BF`) | Cria uma concordância segmentada e tangente entre uma cabeceira e uma linha, sem gerar offsets BOTA. |
| `BOTAC` | Abre a configuração dos parâmetros. |
| `BOTAH` | Abre a ajuda resumida no AutoCAD/Civil 3D. |

## Seleção e lado da manobra

Para executar `BOTA2` e `BOTA3`, faça duas seleções:

1. Clique na cabeceira perto da área de trabalho. Esse clique define o lado
   em que a manobra será gerada.
2. Clique na linha guia. Esse clique define a referência da guia; o offset
   é calculado no lado contrário ao definido para a cabeceira.

No `BOTA3`, quando a guia vai e volta ou tem várias passadas próximas,
o clique identifica a passada que deve receber a conexão. A busca do fillet
e do cruzamento com a cabeceira fica limitada a esse trecho contínuo. Se a
concordância não couber ali, a rotina cancela sem conectar à passada vizinha.

O `BOTA3` não mede nem limita o ângulo entre a cabeceira e a guia. A conexão
é calculada quando a geometria permite usar os raios configurados.

Para escolher o lado dos offsets e o sentido inicial do giro, a rotina usa
os mesmos critérios do `BOTA2` e os pontos completos dos dois cliques.
A busca da manobra se concentra no cruzamento escolhido, mesmo ao rotacionar
o desenho ou inverter o sentido de criação das polilinhas.

No `BOTAFILLET`, o clique na cabeceira seleciona o trecho que receberá
a concordância, e o clique na linha seleciona seu braço. Se as entidades
se cruzarem, a rotina as corta na interseção, conserva os trechos selecionados
e os une em uma única polilinha contínua.

## Parâmetros

Configure os valores com `BOTAC`. Os desenhos da mesma instância do
Civil 3D/AutoCAD compartilham a última alteração válida que você confirmar.
Ao abrir `BOTAC` ou executar um comando BOTA em outro desenho, a rotina
recupera esses valores, inclusive nos desenhos abertos depois durante a sessão.
Todas as opções do `BOTAC` e o fator da reta do `BOTA3` são compartilhados.
O BotaHelp define os valores iniciais no primeiro carregamento e recupera
a configuração compartilhada ao ser recarregado. As manobras já desenhadas
mantêm sua geometria. A sincronização termina ao fechar a instância e não
se estende a outras instâncias.

Use os perfis para salvar ou transferir valores entre sessões. Na mesma janela,
**Salvar arquivo** exporta todos os parâmetros para um perfil `.txt`,
e **Carregar arquivo** recupera um perfil salvo. A rotina valida o arquivo
antes de alterar a configuração e não executa código AutoLISP ao carregá-lo.
Você também pode ajustar os valores durante cada comando.

| Parâmetro | Aplica-se a | Valor inicial | Descrição |
| --- | --- | ---: | --- |
| Raio de giro | `BOTA`, `BOTA2`, `BOTA3` | 10 m | Raio interno de giro da máquina. |
| Implemento | `BOTA`, `BOTA2`, `BOTA3` | 36.578 m | Largura total do implemento. O raio externo é `raio de giro + implemento / 2`. |
| Distância máx. entre vértices do círculo | `BOTA`, `BOTA2`, `BOTA3` | 0.9 m | Separação máxima entre os vértices do círculo da manobra. |
| Cortar círculo interno | `BOTA`, `BOTA2` | Ativado | Remove dois segmentos junto à tangência. Quando desativado, conserva o círculo completo, aberto na tangência. |
| Segurança da linha guia | `BOTA2`, `BOTA3` | 0.2 m | Distância adicional aplicada ao offset da guia. |
| Raio do fillet | `BOTA3` | 30 m | Raio da concordância entre a manobra e a guia. |
| Distância máx. entre vértices do fillet | `BOTA3` | 1.5 m | Separação máxima entre os vértices do fillet do `BOTA3`. |
| Controlar distância entre vértices | `BOTA3` | Ativado | Redistribui os vértices do percurso e verifica as separações mínima e máxima. |
| Comprimento adicional na entrada e na saída | `BOTA3` | 5 m | Comprimento sobre a cabeceira antes do giro e sobre a guia depois do fillet. Aceita zero. |
| Distância máx. entre vértices no percurso | `BOTA3` | 1.5 m | Separação máxima ao longo da polilinha dentro do trecho controlado. Deve ser positiva. |
| Distância mín. entre vértices no percurso | `BOTA3` | 0.8 m | Separação mínima no mesmo trecho. Deve estar entre zero e o máximo; zero mantém apenas o controle do máximo. |
| Raio da concordância | `BOTAFILLET` | 10 m | Raio usado pelo `BOTAFILLET` no modo configurado. |
| Distância máx. entre vértices | `BOTAFILLET` | 1.5 m | Separação máxima entre os vértices da concordância no modo configurado. |

A opção **Conectar a cabeceira** do `BOTAC` une o trecho da manobra BOTA
à cabeceira quando a geometria permite. No `BOTA` e no `BOTA2`, desativar
**Cortar circulo interno** conserva os dois segmentos que normalmente seriam
removidos. O círculo fica completo e aberto, com as duas extremidades
na tangência; o fluxo de BREAK e JOIN é mantido.

No `BOTA3`, a opção `L` define o comprimento desejado da reta entre o giro
e o fillet como um fator do raio de giro. O valor inicial é `0.75`: com um
raio de 10 m, a reta desejada mede 7.5 m. Se não couber, a rotina pode usar
uma reta menor. Os valores escolhidos durante a sessão são mantidos;
para experimentar esse ajuste em uma sessão aberta, digite `L` e `0.75`.

## Distância entre vértices do BOTA3

No `BOTAC`, ative **Controlar distancia entre vertices de BOTA3** e defina
**Distancia Min. Vertices no percurso (m)** e
**Distancia Max. Vertices no percurso (m)**. Os valores iniciais são
0.8 m e 1.5 m. A distância é medida ao longo da polilinha entre vértices
consecutivos; em um arco, vale seu comprimento, não a corda entre as extremidades.

O controle abrange o giro, a reta intermediária e o fillet, incluindo suas
uniões. **Extensao antes/depois da manobra (m)** acrescenta um trecho sobre
a cabeceira antes da entrada e sobre a guia depois da saída, com 5 m por
extremidade como valor inicial. Se faltar comprimento, a rotina usa o que
estiver disponível sem prolongar as entidades. Fora desse intervalo,
os vértices são mantidos.

Com um mínimo maior que zero, essa faixa tem prioridade sobre os máximos
individuais do círculo e do fillet no BOTA3. A rotina distribui os vértices
do giro entre suas tangências e redistribui os trechos retos ou os arcos
da mesma circunferência. Conserva as quinas e as variações de largura;
não remove um vértice se isso alterar a forma. Se um trecho não admitir
uma divisão dentro da faixa, seus vértices são mantidos e o processamento
continua nos demais. Por exemplo, uma reta de 1.51 m entre pontos obrigatórios
fica sem densificação com um mínimo de 0.8 m e um máximo de 1.5 m.

Antes de substituir os originais, a rotina verifica os dois limites nos
trechos ajustados, com uma tolerância numérica de 0.000001 m. Ao concluir,
a linha de comando informa quantos trechos ficaram sem densificação e suas
distâncias inicial e final a partir do início da polilinha resultante.
Esses trechos podem manter separações menores que o mínimo ou maiores que
o máximo. Um erro ao processar a geometria ou gravar o resultado ainda
cancela a manobra e preserva os originais.

Ao desativar a opção, o controle é ignorado e os valores ficam salvos.
Um mínimo de zero mantém a densificação anterior: acrescenta vértices para
respeitar o máximo e conserva os existentes, mesmo que estejam mais próximos.
Os perfis salvam o mínimo, o máximo e as extensões. Perfis e sessões anteriores
mantêm seu máximo e usam zero como mínimo; se também não tinham opções
de densificação, usam o controle ativado, 5 m de extensão e 1 m de máximo.
Para aplicar a nova faixa em uma sessão existente, confirme 0.8 m e 1.5 m
no `BOTAC`. Carregue o arquivo `bota_help.lsp` ou uma DLL recompilada.

## Opções durante o comando

| Comando | Enter | `R` | `C` | `B` | `A` |
| --- | --- | --- | --- | --- | --- |
| `BOTA` | Usa os valores atuais. | Altera apenas o raio de giro. | Ajusta raio, implemento e vértices. | Não se aplica. | Não se aplica. |
| `BOTA2` | Usa os valores atuais. | Altera apenas o raio de giro. | Ajusta os parâmetros gerais, incluindo a segurança. | Não se aplica. | Não se aplica. |
| `BOTA3` | Usa os valores atuais. | Solicita primeiro o raio de giro e depois o raio do fillet. | Ajusta os parâmetros gerais. | Ajusta o raio e os vértices do fillet. | Não se aplica. |
| `BOTAFILLET` | Usa o raio configurado. | Altera apenas o raio da concordância. | Não se aplica. | Ajusta o raio e a distância máxima entre vértices. | Seleciona o raio e a distância entre vértices pelo ângulo. |

## BOTAFILLET automático por ângulo

Com `A`, o `BOTAFILLET` calcula o ângulo interno entre os braços definidos
pelos dois cliques e procura uma faixa configurada. Se o ângulo não pertencer
a nenhuma faixa, a rotina mantém a geometria.

Configuração inicial:

| Ângulo interno | Raio | Dist. entre vértices |
| --- | ---: | ---: |
| 87 a menos de 90 graus | 10 m | 0.7 m |
| 90 a menos de 120 graus | 12.5 m | 1.0 m |
| 120 a menos de 135 graus | 15 m | 1.2 m |
| 135 a 180 graus | 18 m | 1.2 m |

As quatro faixas podem ser alteradas no `BOTAC`. Devem estar entre 0 e 180
graus, sem sobreposição, com raio e distância entre vértices maiores que zero.

Para encontrar a concordância, o `BOTAFILLET` analisa os segmentos consecutivos
da cabeceira e da guia dentro de uma janela radial definida pelo raio da
concordância. Assim, consegue conservar e avaliar polilinhas com vértices
próximos, por exemplo a cada 0.5 m, sem escolher um trecho distante.

## Requisitos e limites

- Selecione entidades que o AutoCAD consiga tratar como curvas e que tenham
  geometria válida perto dos cliques.
- No `BOTAFILLET`, a cabeceira e a linha precisam se cruzar para que o corte
  ocorra nessa interseção. Se não houver cruzamento, a referência será o ponto
  escolhido na cabeceira, mas pode não existir uma solução tangente válida.
- A rotina rejeita um raio grande demais, um trecho insuficiente ou uma
  geometria que provoque cruzamentos na concordância, evitando alterar
  a cabeceira de forma incorreta.
- O `BOTA2` exige uma interseção real ou uma ponta da guia apoiada na cabeceira.
  Antes de calcular os offsets, cria uma cópia temporária da guia e mantém
  uma janela de `0.2 x implemento` no lado oposto ao clique e `1.5 x implemento`
  em direção ao clique. Apenas esse trecho isolado recebe o offset;
  a guia original é preservada. Antes de qualquer offset, o BOTA2 também usa
  uma cópia temporária da cabeceira com `2 x implemento` para cada lado da
  interseção. A cabeceira original só é cortada na tangência final do círculo.
  Para resolver essa tangência, o BOTA2 usa o centro mais próximo do cruzamento
  de referência dos offsets e aceita uma correção máxima de `0.05 m` por
  imprecisão numérica. O centro final é reprojetado à distância exata do
  raio interno em relação à cabeceira. Se os offsets não se cruzarem de fato,
  a última verificação usa uma extensão virtual de até `1 m`, sem modificar
  nenhuma entidade.
- O `BOTA3` limita a cabeceira e a guia a uma área de trabalho local de pelo
  menos 50 m a partir do clique na cabeceira.
- Confira visualmente o resultado antes de continuar o traçado. As verificações
  automatizadas locais não substituem a validação funcional no Civil 3D.

## Arquivos do repositório

- `bota_help.lsp`: arquivo principal para carregar com `APPLOAD`.
- `ribbon/`: código do complemento .NET e instruções de compilação.
- `tests/`: verificações automatizadas e casos para executar no Civil 3D.
- `tools/ribbon-preview/`: ferramenta para gerar prévias dos ícones.
- `dist/`: saída local da compilação, ignorada pelo Git junto com os arquivos
  `.fas`, `.vlx` e `.prv`, logs e backups.

As versões anteriores do código estão no histórico do Git.

## Licença

Este projeto é distribuído sob a [licença MIT](LICENSE).
Copyright (c) 2026 Maicon Marcarini.
