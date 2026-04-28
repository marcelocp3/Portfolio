module Stats
  ( annualTradingDays
  , dot
  , mean
  , covarianceMatrix
  , portfolioReturns
  , portfolioAnnualReturn
  , portfolioAnnualVolatility
  , sharpe
  ) where

annualTradingDays :: Double
annualTradingDays = 252.0

dot :: [Double] -> [Double] -> Double
dot xs ys = sum (zipWith (*) xs ys)

mean :: [Double] -> Double
mean [] = 0.0
mean xs = sum xs / fromIntegral (length xs)

sampleCovariance :: [Double] -> [Double] -> Double
sampleCovariance xs ys
  | n <= 1 = 0.0
  | otherwise = sum (zipWith centeredProduct xs ys) / fromIntegral (n - 1)
  where
    n = min (length xs) (length ys)
    mx = mean xs
    my = mean ys
    centeredProduct x y = (x - mx) * (y - my)

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

covarianceMatrix :: [[Double]] -> [[Double]]
covarianceMatrix rows =
  [ [ sampleCovariance colA colB | colB <- cols ] | colA <- cols ]
  where
    cols = transposeMatrix rows

portfolioReturns :: [[Double]] -> [Double] -> [Double]
portfolioReturns rows ws = map (`dot` ws) rows

portfolioAnnualReturn :: [[Double]] -> [Double] -> Double
portfolioAnnualReturn rows ws = mean (portfolioReturns rows ws) * annualTradingDays

portfolioAnnualVolatility :: [[Double]] -> [Double] -> Double
portfolioAnnualVolatility rows ws = sqrt variance * sqrt annualTradingDays
  where
    cov = covarianceMatrix rows
    variance = max 0.0 (dot ws (map (`dot` ws) cov))

sharpe :: Double -> Double -> Double -> Double
sharpe riskFree ret vol
  | vol <= 0.0 = negate (1 / 0)
  | otherwise = (ret - riskFree) / vol
