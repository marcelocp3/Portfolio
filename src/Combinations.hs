module Combinations
  ( choose
  , indexedChoose
  ) where

choose :: Int -> [a] -> [[a]]
choose 0 _ = [[]]
choose _ [] = []
choose k (x:xs)
  | k < 0 = []
  | otherwise = map (x :) (choose (k - 1) xs) ++ choose k xs

indexedChoose :: Int -> [a] -> [([Int], [a])]
indexedChoose k xs =
  [ (map fst selected, map snd selected)
  | selected <- choose k (zip [0..] xs)
  ]
