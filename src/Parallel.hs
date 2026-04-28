module Parallel
  ( parallelMap
  , parallelMapReduceMaybe
  ) where

import Control.Concurrent (forkIO, getNumCapabilities)
import Control.Concurrent.Chan (newChan, readChan, writeChan)
import Control.Monad (forM_, replicateM)
import Data.List (sortOn)

parallelMap :: Int -> (a -> b) -> [a] -> IO [b]
parallelMap requestedWorkers f xs = do
  capabilities <- getNumCapabilities
  let desired = if requestedWorkers <= 0 then capabilities else requestedWorkers
      workers = max 1 (min desired (length xs))
  jobs <- newChan
  results <- newChan
  forM_ (zip [0..] xs) $ writeChan jobs . Just
  forM_ [1..workers] $ const (writeChan jobs Nothing)
  forM_ [1..workers] $ const $ forkIO $ worker jobs results
  received <- replicateM (length xs) (readChan results)
  pure $ map snd $ sortOn fst received
  where
    worker jobs results = do
      nextJob <- readChan jobs
      case nextJob of
        Nothing -> pure ()
        Just (index, value) -> do
          writeChan results (index, f value)
          worker jobs results

parallelMapReduceMaybe :: Int -> (a -> Maybe b) -> (b -> b -> b) -> [a] -> IO (Maybe b)
parallelMapReduceMaybe requestedWorkers f combine xs = do
  capabilities <- getNumCapabilities
  let desired = if requestedWorkers <= 0 then capabilities else requestedWorkers
      workers = max 1 desired
  jobs <- newChan
  results <- newChan
  _ <- forkIO $ do
    mapM_ (writeChan jobs . Just) xs
    forM_ [1..workers] $ const (writeChan jobs Nothing)
  forM_ [1..workers] $ const $ forkIO $ worker jobs results Nothing
  partials <- replicateM workers (readChan results)
  pure $ foldBest (catMaybesSimple partials)
  where
    worker jobs results currentBest = do
      nextJob <- readChan jobs
      case nextJob of
        Nothing -> writeChan results currentBest
        Just value -> do
          let updated = mergeMaybe currentBest (f value)
          worker jobs results updated
    mergeMaybe Nothing next = next
    mergeMaybe current Nothing = current
    mergeMaybe (Just a) (Just b) = Just (combine a b)
    foldBest [] = Nothing
    foldBest (best:rest) = Just (foldl combine best rest)
    catMaybesSimple [] = []
    catMaybesSimple (Nothing:rest) = catMaybesSimple rest
    catMaybesSimple (Just value:rest) = value : catMaybesSimple rest
