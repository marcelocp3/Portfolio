# Projeto 2 - Programacao Funcional

Otimizador de carteiras em Haskell para o Projeto 2 da disciplina de Programacao Funcional.

O programa avalia carteiras long-only com 25 ou mais ativos das 30 acoes do Dow Jones, sorteando pesos viaveis com soma 1 e limite de 20% por ativo. Para cada carteira simulada, calcula retorno anualizado, volatilidade anualizada e Sharpe Ratio. A avaliacao das combinacoes e distribuida em paralelo, e as funcoes de calculo financeiro e simulacao de pesos sao puras.

## Escopo implementado

- Linguagem funcional: Haskell.
- Dados de entrada por CSV com precos diarios.
- Conversao de precos para retornos diarios simples.
- Combinatoria para carteiras com 25 ou mais ativos: `sum (30 choose k)` para `k = 25..30`, totalizando 174.437 combinacoes.
- Simulacao deterministica de pesos long-only.
- Restricao de concentracao: peso maximo de 20% por ativo.
- Calculo de retorno anualizado, volatilidade anualizada e Sharpe Ratio.
- Execucao paralela das combinacoes com `Control.Concurrent`.
- CLI configuravel para testes pequenos e execucao completa.

Os itens opcionais da rubrica para A+ nao foram implementados: API sob demanda, teste fora da amostra no primeiro trimestre de 2025 e comparacao formal de tempo com e sem paralelismo.

## Requisitos

- GHC 9.x
- `cabal-install`

Nao e necessario `stack` nem pacotes externos alem da biblioteca `base`.

## Formato dos dados

O repositorio inclui `data/dow30_prices_2025H2.csv` com precos diarios de fechamento de 01/07/2025 a 31/12/2025.

Formato esperado:

```csv
Date,AAPL,AMGN,AMZN,AXP,BA,CAT,CRM,CSCO,CVX,DIS,GS,HD,HON,IBM,JNJ,JPM,KO,MCD,MMM,MRK,MSFT,NKE,NVDA,PG,SHW,TRV,UNH,V,VZ,WMT
2025-07-01,210.10,285.40,...
2025-07-02,211.30,286.10,...
```

O CSV deve conter:

- primeira coluna chamada `Date`;
- uma coluna para cada uma das 30 acoes do Dow Jones;
- precos ajustados ou precos de fechamento consistentes para todos os ativos;
- linhas ordenadas por data crescente.

O arquivo `data/sample_prices.csv` e apenas um conjunto pequeno para verificar compilacao e execucao. A base principal da entrega e `data/dow30_prices_2025H2.csv`.

O arquivo real pode ser gerado com:

```bash
python3 scripts/fetch_dow_data.py
```

O script consulta o endpoint publico `https://www.pocketportfolio.app/api/tickers/{TICKER}/json`, usa o campo `close` e gera `data/dow30_prices_2025H2.csv`.
Os metadados da coleta ficam em `data/dow30_prices_2025H2.source.txt`.

## Como compilar

```bash
cabal build
```

O executavel fica no diretorio de build do Cabal. Para descobrir o caminho exato:

```bash
cabal list-bin portfolio
```

Tambem e possivel compilar e executar em um unico comando com `cabal run`.
O arquivo `.cabal` ja ativa `-O2`, `-threaded` e `-rtsopts`, portanto o executavel aceita opcoes de RTS como `+RTS -N`.

Em alguns ambientes Linux, se o linker reclamar de `libgmp.so`, instale o pacote de desenvolvimento da GMP. Em Debian/Ubuntu:

```bash
sudo apt install libgmp-dev
```

## Como testar rapidamente

```bash
cabal run portfolio -- --input data/sample_prices.csv --min-assets 25 --sims 1000 --workers 4 --limit-combinations 20 +RTS -N4
```

Se preferir executar o binario ja compilado:

```bash
$(cabal list-bin portfolio) --input data/sample_prices.csv --min-assets 25 --sims 1000 --workers 4 --limit-combinations 20 +RTS -N4
```

## Como executar o projeto completo

Depois de preencher `data/dow30_prices_2025H2.csv`:

```bash
cabal run portfolio -- --input data/dow30_prices_2025H2.csv --min-assets 25 --sims 1000000 --workers 8 +RTS -N8
```

Observacao: a execucao completa continua pesada, mas o aviso do professor reduz a combinatoria para 174.437 conjuntos de ativos. Cada conjunto ainda recebe 1 milhao de simulacoes por padrao. Para validar a logica antes de rodar tudo, use `--limit-combinations`.

Exemplo:

```bash
cabal run portfolio -- --input data/dow30_prices_2025H2.csv --min-assets 25 --sims 10000 --workers 4 --limit-combinations 1000 +RTS -N4
```

## Paralelismo com `+RTS -N`

O programa tem duas configuracoes relacionadas a paralelismo:

- `--workers N`: quantidade de threads de trabalho criadas pelo programa.
- `+RTS -Nn`: quantidade de capacidades do runtime Haskell, isto e, quantas threads Haskell podem executar em paralelo.

Para melhor aproveitamento da CPU, use valores alinhados:

```bash
cabal run portfolio -- --workers 8 +RTS -N8
```

Tambem e possivel deixar o RTS usar todos os nucleos detectados:

```bash
cabal run portfolio -- --workers 0 +RTS -N
```

Use `+RTS -N4`, `+RTS -N8` etc. para fixar um numero. A forma correta inclui o hifen antes de `N`; `+RTS N` nao ativa o paralelismo do RTS.

## Opcoes da CLI

```text
--input PATH              CSV Date,TICKER1,... com precos diarios
--min-assets N           quantidade minima de ativos por carteira (padrao: 25)
--choose N               alias legado de --min-assets
--sims N                  simulacoes por combinacao (padrao: 1000000)
--workers N               threads de trabalho (padrao: autodetectar)
--limit-combinations N    limita combinacoes para testes
--max-weight X            peso maximo por ativo (padrao: 0.20)
--risk-free X             taxa livre de risco anual (padrao: 0.0)
--seed N                  semente deterministica
```

## Organizacao

- `app/Main.hs`: leitura de argumentos, execucao e exibicao do resultado.
- `src/DataLoader.hs`: parser CSV e conversao de precos para retornos.
- `src/Stats.hs`: funcoes puras de estatistica financeira.
- `src/Combinations.hs`: geracao funcional das combinacoes.
- `src/Simulation.hs`: simulacao pura de pesos e avaliacao das carteiras.
- `src/Parallel.hs`: distribuicao paralela das combinacoes.

## Saida

A saida mostra a melhor carteira encontrada dentro dos parametros da execucao:

```text
Melhor carteira encontrada:
Sharpe anualizado: ...
Retorno anualizado: ...
Volatilidade anualizada: ...
Pesos:
AAPL: ...
...
```

Exemplo de teste controlado mais robusto:

```bash
cabal run portfolio -- --input data/dow30_prices_2025H2.csv --min-assets 25 --sims 10000 --workers 4 --limit-combinations 1000 +RTS -N4
```

```text
Ativos no CSV: 30
Retornos diarios calculados: 127
Tamanho das carteiras: 25 a 30 ativos
Combinacoes avaliadas nesta execucao: 1000
Simulacoes por combinacao: 10000
Workers: 4

Melhor carteira encontrada:
Sharpe anualizado: 3.414630
Retorno anualizado: 0.295667
Volatilidade anualizada: 0.086588
Pesos:
AAPL: 0.0629
AMGN: 0.0436
AMZN: 0.0063
AXP: 0.0377
BA: 0.0258
CAT: 0.1013
CRM: 0.0389
CSCO: 0.0209
CVX: 0.0916
DIS: 0.0277
GS: 0.0695
HD: 0.0022
HON: 0.0030
IBM: 0.0440
JNJ: 0.0962
JPM: 0.0199
KO: 0.0600
MCD: 0.0722
MMM: 0.0053
MRK: 0.0281
MSFT: 0.0229
NVDA: 0.0260
PG: 0.0121
UNH: 0.0056
WMT: 0.0762
```
