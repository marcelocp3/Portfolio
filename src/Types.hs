module Types
  ( Ticker
  , PriceRow(..)
  , MarketData(..)
  , EvaluatedPortfolio(..)
  ) where

type Ticker = String

data PriceRow = PriceRow
  { priceDate :: String
  , prices :: [Double]
  } deriving (Eq, Show)

data MarketData = MarketData
  { tickers :: [Ticker]
  , returnsMatrix :: [[Double]]
  } deriving (Eq, Show)

data EvaluatedPortfolio = EvaluatedPortfolio
  { selectedTickers :: [Ticker]
  , weights :: [Double]
  , annualReturn :: Double
  , annualVolatility :: Double
  , sharpeRatio :: Double
  } deriving (Eq, Show)
