module Main where

import Combinations (indexedChoose)
import Data.List (intercalate)
import DataLoader (loadMarketData)
import Parallel (parallelMapReduceMaybe)
import Simulation
import System.Environment (getArgs)
import Text.Printf (printf)
import Types

data Options = Options
  { inputPath :: FilePath
  , assetsToChoose :: Int
  , simulations :: Int
  , workers :: Int
  , limitCombinations :: Maybe Int
  , maximumWeight :: Double
  , riskFree :: Double
  , seed :: Int
  } deriving (Eq, Show)

defaultOptions :: Options
defaultOptions = Options
  { inputPath = "data/dow30_prices_2025H2.csv"
  , assetsToChoose = 20
  , simulations = 1000000
  , workers = 0
  , limitCombinations = Nothing
  , maximumWeight = 0.20
  , riskFree = 0.0
  , seed = 20260701
  }

main :: IO ()
main = do
  args <- getArgs
  case parseOptions defaultOptions args of
    Left err -> putStrLn err >> putStrLn usage
    Right options -> run options

run :: Options -> IO ()
run options = do
  loaded <- loadMarketData (inputPath options)
  case loaded of
    Left err -> putStrLn $ "Erro ao ler dados: " ++ err
    Right market -> do
      let combos = maybe id take (limitCombinations options)
                 $ indexedChoose (assetsToChoose options) (tickers market)
          config = SimulationConfig
            { simulationsPerCombination = simulations options
            , maxWeight = maximumWeight options
            , riskFreeRate = riskFree options
            , baseSeed = seed options
            }
          workerCount = if workers options <= 0 then 1 else workers options
          evaluate (indexes, symbols) =
            evaluateCombination config (returnsMatrix market) (tickers market) indexes symbols
          combineBest a b =
            if sharpeRatio a >= sharpeRatio b then a else b
      putStrLn $ "Ativos no CSV: " ++ show (length (tickers market))
      putStrLn $ "Retornos diarios calculados: " ++ show (length (returnsMatrix market))
      putStrLn $ "Combinacoes avaliadas nesta execucao: " ++ combinationMessage options (length (tickers market))
      putStrLn $ "Simulacoes por combinacao: " ++ show (simulations options)
      result <- parallelMapReduceMaybe workerCount evaluate combineBest combos
      printBest result

printBest :: Maybe EvaluatedPortfolio -> IO ()
printBest Nothing = putStrLn "Nenhuma carteira viavel foi encontrada."
printBest (Just best) = do
  putStrLn "\nMelhor carteira encontrada:"
  putStrLn $ "Sharpe anualizado: " ++ printf "%.6f" (sharpeRatio best)
  putStrLn $ "Retorno anualizado: " ++ printf "%.6f" (annualReturn best)
  putStrLn $ "Volatilidade anualizada: " ++ printf "%.6f" (annualVolatility best)
  putStrLn "Pesos:"
  mapM_ putStrLn (zipWith formatWeight (selectedTickers best) (weights best))

formatWeight :: String -> Double -> String
formatWeight ticker weight = ticker ++ ": " ++ printf "%.4f" weight

combinationMessage :: Options -> Int -> String
combinationMessage options assetCount =
  case limitCombinations options of
    Just n -> show (min (fromIntegral n) (combinationCount assetCount (assetsToChoose options)))
    Nothing -> show (combinationCount assetCount (assetsToChoose options))

combinationCount :: Int -> Int -> Integer
combinationCount n k
  | k < 0 || k > n = 0
  | otherwise = product [fromIntegral (n - r + 1) | r <- [1..k']]
              `div` product [1..fromIntegral k']
  where
    k' = min k (n - k)

parseOptions :: Options -> [String] -> Either String Options
parseOptions opts [] = Right opts
parseOptions opts ("--input":value:rest) =
  parseOptions opts { inputPath = value } rest
parseOptions opts ("--choose":value:rest) =
  parseInt "--choose" value >>= \n -> parseOptions opts { assetsToChoose = n } rest
parseOptions opts ("--sims":value:rest) =
  parseInt "--sims" value >>= \n -> parseOptions opts { simulations = n } rest
parseOptions opts ("--workers":value:rest) =
  parseInt "--workers" value >>= \n -> parseOptions opts { workers = n } rest
parseOptions opts ("--limit-combinations":value:rest) =
  parseInt "--limit-combinations" value >>= \n ->
    parseOptions opts { limitCombinations = Just n } rest
parseOptions opts ("--max-weight":value:rest) =
  parseDouble "--max-weight" value >>= \n -> parseOptions opts { maximumWeight = n } rest
parseOptions opts ("--risk-free":value:rest) =
  parseDouble "--risk-free" value >>= \n -> parseOptions opts { riskFree = n } rest
parseOptions opts ("--seed":value:rest) =
  parseInt "--seed" value >>= \n -> parseOptions opts { seed = n } rest
parseOptions _ (flag:_) = Left $ "Argumento desconhecido ou sem valor: " ++ flag

parseInt :: String -> String -> Either String Int
parseInt flag value =
  case reads value of
    [(n, "")] -> Right n
    _ -> Left $ flag ++ " espera um inteiro, recebeu: " ++ value

parseDouble :: String -> String -> Either String Double
parseDouble flag value =
  case reads value of
    [(n, "")] -> Right n
    _ -> Left $ flag ++ " espera um numero, recebeu: " ++ value

usage :: String
usage = intercalate "\n"
  [ "Uso:"
  , "  ./portfolio --input data/dow30_prices_2025H2.csv --workers 8"
  , ""
  , "Opcoes:"
  , "  --input PATH              CSV Date,TICKER1,... com precos diarios"
  , "  --choose N                quantidade de ativos por carteira (padrao: 20)"
  , "  --sims N                  simulacoes por combinacao (padrao: 1000000)"
  , "  --workers N               threads de trabalho (padrao: 1)"
  , "  --limit-combinations N    limita combinacoes para testes"
  , "  --max-weight X            peso maximo por ativo (padrao: 0.20)"
  , "  --risk-free X             taxa livre de risco anual (padrao: 0.0)"
  , "  --seed N                  semente deterministica"
  ]
