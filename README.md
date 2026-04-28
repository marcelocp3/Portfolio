# Projeto 2 - Programacao Funcional

Otimizador de carteiras em Haskell para o Projeto 2 da disciplina de Programacao Funcional.

O programa avalia carteiras long-only escolhendo 20 das 30 acoes do Dow Jones, sorteando pesos viaveis com soma 1 e limite de 20% por ativo. Para cada carteira simulada, calcula retorno anualizado, volatilidade anualizada e Sharpe Ratio. A avaliacao das combinacoes e distribuida em paralelo, e as funcoes de calculo financeiro e simulacao de pesos sao puras.

## Escopo implementado

- Linguagem funcional: Haskell.
- Dados de entrada por CSV com precos diarios.
- Conversao de precos para retornos diarios simples.
- Combinatoria `30 choose 20`.
- Simulacao deterministica de pesos long-only.
- Restricao de concentracao: peso maximo de 20% por ativo.
- Calculo de retorno anualizado, volatilidade anualizada e Sharpe Ratio.
- Execucao paralela das combinacoes com `Control.Concurrent`.
- CLI configuravel para testes pequenos e execucao completa.

Os itens opcionais da rubrica para A+ nao foram implementados: API sob demanda, teste fora da amostra no primeiro trimestre de 2025 e comparacao formal de tempo com e sem paralelismo.

## Requisitos

- GHC 9.x
- `make` opcional

Nao e necessario `cabal`, `stack` nem pacotes externos.

## Formato dos dados

Crie o arquivo `data/dow30_prices_2025H2.csv` com precos diarios de 01/07/2025 a 31/12/2025.

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

O arquivo `data/sample_prices.csv` e apenas um conjunto pequeno para verificar compilacao e execucao. Ele nao substitui os dados reais exigidos pela entrega.

## Como compilar

```bash
make build
```

Comando equivalente sem `make`:

```bash
ghc -O2 -threaded -rtsopts -isrc app/Main.hs -o portfolio
```

Em alguns ambientes Linux, o GHC encontra `libgmp.so.10`, mas nao encontra o symlink de desenvolvimento `libgmp.so`. O `Makefile` cria um symlink local ignorado pelo Git quando isso acontece.

## Como testar rapidamente

```bash
make run-sample
```

Ou:

```bash
./portfolio --input data/sample_prices.csv --choose 20 --sims 1000 --workers 4 --limit-combinations 20 +RTS -N4
```

## Como executar o projeto completo

Depois de preencher `data/dow30_prices_2025H2.csv`:

```bash
./portfolio --input data/dow30_prices_2025H2.csv --choose 20 --sims 1000000 --workers 8 +RTS -N8
```

Observacao: a execucao completa e muito pesada. O enunciado estima aproximadamente 30 milhoes de combinacoes, cada uma com 1 milhao de simulacoes. Para validar a logica antes de rodar tudo, use `--limit-combinations`.

Exemplo:

```bash
./portfolio --input data/dow30_prices_2025H2.csv --choose 20 --sims 10000 --workers 8 --limit-combinations 100 +RTS -N8
```

## Opcoes da CLI

```text
--input PATH              CSV Date,TICKER1,... com precos diarios
--choose N                quantidade de ativos por carteira (padrao: 20)
--sims N                  simulacoes por combinacao (padrao: 1000000)
--workers N               threads de trabalho (padrao: 1)
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

A saida mostra a melhor carteira encontrada na execucao:

```text
Melhor carteira encontrada:
Sharpe anualizado: ...
Retorno anualizado: ...
Volatilidade anualizada: ...
Pesos:
AAPL: ...
...
```
