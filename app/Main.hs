module Main where

import Combinations (indexedChoose)
import Control.Concurrent (setNumCapabilities)
import Data.List (intercalate)
import DataLoader (loadMarketData)
import GHC.Conc (getNumProcessors)
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
  case parseOptions defaultOptions args >>= validateOptions of
    Left err -> putStrLn err >> putStrLn usage
    Right options -> run options

run :: Options -> IO ()
run options = do
  loaded <- loadMarketData (inputPath options)
  case loaded of
    Left err -> putStrLn $ "Erro ao ler dados: " ++ err
    Right market -> do
      case validateMarketOptions options market of
        Left err -> putStrLn err
        Right () -> do
          workerCount <- configureWorkers (workers options)
          let combos = maybe id take (limitCombinations options)
                     $ indexedChoose (assetsToChoose options) (tickers market)
              config = SimulationConfig
                { simulationsPerCombination = simulations options
                , maxWeight = maximumWeight options
                , riskFreeRate = riskFree options
                , baseSeed = seed options
                }
              evaluate (indexes, symbols) =
                evaluateCombination config (returnsMatrix market) (tickers market) indexes symbols
              combineBest a b =
                if sharpeRatio a >= sharpeRatio b then a else b
          putStrLn $ "Ativos no CSV: " ++ show (length (tickers market))
          putStrLn $ "Retornos diarios calculados: " ++ show (length (returnsMatrix market))
          putStrLn $ "Combinacoes avaliadas nesta execucao: " ++ combinationMessage options (length (tickers market))
          putStrLn $ "Simulacoes por combinacao: " ++ show (simulations options)
          putStrLn $ "Workers: " ++ show workerCount
          result <- parallelMapReduceMaybe workerCount evaluate combineBest combos
          printBest result

configureWorkers :: Int -> IO Int
configureWorkers requested
  | requested > 0 = do
      setNumCapabilities requested
      pure requested
  | otherwise = do
      processors <- getNumProcessors
      let detected = max 1 processors
      setNumCapabilities detected
      pure detected

validateOptions :: Options -> Either String Options
validateOptions options
  | assetsToChoose options <= 0 =
      Left "--choose deve ser maior que zero."
  | simulations options <= 0 =
      Left "--sims deve ser maior que zero."
  | workers options < 0 =
      Left "--workers deve ser zero para autodetectar ou maior que zero."
  | maybe False (<= 0) (limitCombinations options) =
      Left "--limit-combinations deve ser maior que zero."
  | maximumWeight options <= 0.0 || maximumWeight options > 1.0 =
      Left "--max-weight deve estar no intervalo (0, 1]."
  | otherwise = Right options

validateMarketOptions :: Options -> MarketData -> Either String ()
validateMarketOptions options market
  | assetsToChoose options > assetCount =
      Left $ "--choose seleciona " ++ show (assetsToChoose options)
          ++ " ativos, mas o CSV tem apenas " ++ show assetCount ++ "."
  | feasibleCapacity + tolerance < 1.0 =
      Left $ "Restricoes inviaveis: " ++ show (assetsToChoose options)
          ++ " ativos com peso maximo " ++ printf "%.4f" (maximumWeight options)
          ++ " somam no maximo " ++ printf "%.4f" feasibleCapacity ++ "."
  | otherwise = Right ()
  where
    assetCount = length (tickers market)
    feasibleCapacity = fromIntegral (assetsToChoose options) * maximumWeight options
    tolerance = 1.0e-9

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
  , "  --workers N               threads de trabalho (padrao: autodetectar)"
  , "  --limit-combinations N    limita combinacoes para testes"
  , "  --max-weight X            peso maximo por ativo (padrao: 0.20)"
  , "  --risk-free X             taxa livre de risco anual (padrao: 0.0)"
  , "  --seed N                  semente deterministica"
  ]
