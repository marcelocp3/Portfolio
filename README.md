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


O arquivo real pode ser gerado com:

```bash
python3 scripts/fetch_dow_data.py
```

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
