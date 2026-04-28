module DataLoader
  ( loadMarketData
  , parsePriceCsv
  , priceRowsToMarketData
  ) where

import Data.Char (isSpace)
import Types (MarketData(..), PriceRow(..), Ticker)

loadMarketData :: FilePath -> IO (Either String MarketData)
loadMarketData path = do
  content <- readFile path
  pure $ do
    (headers, rows) <- parsePriceCsv content
    priceRowsToMarketData headers rows

parsePriceCsv :: String -> Either String ([Ticker], [PriceRow])
parsePriceCsv content =
  case filter (not . null) (lines content) of
    [] -> Left "CSV vazio."
    headerLine:body -> do
      headers <- parseHeader headerLine
      rows <- traverse (parseRow (length headers)) body
      pure (headers, rows)

parseHeader :: String -> Either String [Ticker]
parseHeader line =
  case splitComma line of
    "Date":symbols
      | null symbols -> Left "Cabecalho deve conter pelo menos um ticker."
      | otherwise -> Right symbols
    _ -> Left "Cabecalho esperado: Date,TICKER1,TICKER2,..."

parseRow :: Int -> String -> Either String PriceRow
parseRow expectedPrices line =
  case splitComma line of
    [] -> Left "Linha vazia."
    d:values
      | length values /= expectedPrices ->
          Left $ "Linha " ++ d ++ " tem " ++ show (length values)
              ++ " precos; esperado " ++ show expectedPrices ++ "."
      | otherwise -> PriceRow d <$> traverse readDouble values

readDouble :: String -> Either String Double
readDouble value =
  case reads value of
    [(number, rest)] | all isSpace rest -> Right number
    _ -> Left $ "Numero invalido no CSV: " ++ value

splitComma :: String -> [String]
splitComma [] = [""]
splitComma (',':xs) = "" : splitComma xs
splitComma (x:xs) =
  case splitComma xs of
    [] -> [[x]]
    y:ys -> (x:y) : ys

priceRowsToMarketData :: [Ticker] -> [PriceRow] -> Either String MarketData
priceRowsToMarketData headers rows
  | length rows < 2 = Left "Sao necessarias pelo menos duas datas de preco."
  | any ((/= length headers) . length . prices) rows =
      Left "Todas as linhas devem ter o mesmo numero de precos do cabecalho."
  | otherwise = Right $ MarketData headers (dailyReturns rows)

dailyReturns :: [PriceRow] -> [[Double]]
dailyReturns rows = zipWith rowReturns (map prices rows) (map prices (drop 1 rows))

rowReturns :: [Double] -> [Double] -> [Double]
rowReturns previous current = zipWith simpleReturn previous current

simpleReturn :: Double -> Double -> Double
simpleReturn previous current
  | previous == 0.0 = 0.0
  | otherwise = current / previous - 1.0
