{-# LANGUAGE OverloadedStrings #-}
module Demo where

-- Haskell preview example.
label :: String
label = "peek"

main :: IO ()
main = putStrLn ("hello, " ++ label)
