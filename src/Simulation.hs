module Simulation
  ( SimulationConfig(..)
  , evaluatePortfolio
  , evaluateCombination
  , simulateWeights
  ) where

import Data.Bits (Bits(xor), shiftR, (.&.))
import Data.List (foldl', maximumBy)
import Data.Ord (comparing)
import Stats
import Types (EvaluatedPortfolio(..), Ticker)

data SimulationConfig = SimulationConfig
  { simulationsPerCombination :: Int
  , maxWeight :: Double
  , riskFreeRate :: Double
  , baseSeed :: Int
  } deriving (Eq, Show)

evaluateCombination
  :: SimulationConfig
  -> [[Double]]
  -> [Ticker]
  -> [Int]
  -> [Ticker]
  -> Maybe EvaluatedPortfolio
evaluateCombination config allReturns _ selectedIndexes selectedSymbols =
  bestMaybe evaluated
  where
    selectedReturns = projectColumns selectedIndexes allReturns
    meanReturns = map mean (transposeMatrix selectedReturns)
    covariance = covarianceMatrix selectedReturns
    evaluated =
      [ evaluatePortfolioFromStats (riskFreeRate config) meanReturns covariance selectedSymbols ws
      | ws <- take (simulationsPerCombination config)
            (simulateWeights (baseSeed config + seedFromIndexes selectedIndexes)
                             (length selectedIndexes)
                             (maxWeight config))
      ]

evaluatePortfolio
  :: Double
  -> [[Double]]
  -> [Ticker]
  -> [Double]
  -> EvaluatedPortfolio
evaluatePortfolio riskFree rows symbols ws =
  EvaluatedPortfolio symbols ws ret vol (sharpe riskFree ret vol)
  where
    ret = portfolioAnnualReturn rows ws
    vol = portfolioAnnualVolatility rows ws

evaluatePortfolioFromStats
  :: Double
  -> [Double]
  -> [[Double]]
  -> [Ticker]
  -> [Double]
  -> EvaluatedPortfolio
evaluatePortfolioFromStats riskFree meanReturns covariance symbols ws =
  EvaluatedPortfolio symbols ws ret vol (sharpe riskFree ret vol)
  where
    ret = dot meanReturns ws * annualTradingDays
    variance = max 0.0 (dot ws (map (`dot` ws) covariance))
    vol = sqrt variance * sqrt annualTradingDays

simulateWeights :: Int -> Int -> Double -> [[Double]]
simulateWeights seed n limit =
  filter validWeightVector $ map normalize chunks
  where
    randoms = lcgStream (fromIntegral (max 1 seed))
    chunks = chunk n randoms
    normalize xs =
      let adjusted = map (\x -> 0.001 + x) xs
          total = sum adjusted
      in map (/ total) adjusted
    validWeightVector ws =
      length ws == n
      && all (>= 0.0) ws
      && all (<= limit) ws
      && abs (sum ws - 1.0) < 1.0e-9

projectColumns :: [Int] -> [[Double]] -> [[Double]]
projectColumns indexes = map (\row -> map (row !!) indexes)

transposeMatrix :: [[a]] -> [[a]]
transposeMatrix [] = []
transposeMatrix ([]:_) = []
transposeMatrix rows
  | any null rows = []
  | otherwise = map first rows : transposeMatrix (map rest rows)
  where
    first (x:_) = x
    first [] = error "unreachable empty row in transposeMatrix"
    rest (_:xs) = xs
    rest [] = []

bestMaybe :: [EvaluatedPortfolio] -> Maybe EvaluatedPortfolio
bestMaybe [] = Nothing
bestMaybe xs = Just $ maximumBy (comparing sharpeRatio) xs

seedFromIndexes :: [Int] -> Int
seedFromIndexes = foldl' (\acc x -> acc * 131 + x + 17) 23

chunk :: Int -> [a] -> [[a]]
chunk n xs =
  let (prefix, suffix) = splitAt n xs
  in if length prefix < n then [] else prefix : chunk n suffix

lcgStream :: Integer -> [Double]
lcgStream seed = map toUnit (drop 1 (iterate next seed))
  where
    modulus = 2147483648
    next x = (1103515245 * x + 12345) `mod` modulus
    toUnit x = fromIntegral (x `xor` (x `shiftR` 11) .&. 2147483647) / fromIntegral modulus
