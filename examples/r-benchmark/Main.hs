{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}

module Main where

import Choreography.Network.HttpInstrumented ( InstrumentedHttpConfig(..) )

import Choreography
import RestrictedChoreography

import Control.Monad (replicateM_)
import Data.Proxy (Proxy(..))
import System.Environment (getArgs)
import System.Exit (die)
import Text.Read (readMaybe)

alice :: Proxy "alice"
alice = Proxy

bob :: Proxy "bob"
bob = Proxy

-- Original HasChor: global broadcast.
benchmarkOriginal :: Int -> Choreo IO ()
benchmarkOriginal rounds = do
  decision <- locally alice (\_ -> pure True)

  replicateM_ rounds $
    cond (alice, decision) $ \choice -> do
      _ <- locally bob (\_ -> pure choice)
      pure ()

-- Selective broadcasting: only Alice and Bob.
benchmarkSelective :: Int -> Choreo IO ()
benchmarkSelective rounds = do
  decision <- locally alice (\_ -> pure True)

  replicateM_ rounds $
    condSelective
      (Proxy @'["alice", "bob"])
      (alice, decision) $ \choice -> do
        _ <- locallyR bob (\_ -> pure choice)
        pure ()

-- Select benchmark from command-line argument.
selectBenchmark :: String -> Maybe (Int -> Choreo IO ())
selectBenchmark "original"  = Just benchmarkOriginal
selectBenchmark "selective" = Just benchmarkSelective
selectBenchmark _           = Nothing


roleNames :: Int -> [String]
roleNames n =
  ["alice", "bob"] ++
  ["rol-" ++ show i | i <- [3 .. n]]

config :: Int -> HttpConfig
config n =
  mkHttpConfig $
    zipWith
      (\role port -> (role, ("127.0.0.1", port)))
      (roleNames n)
      [4242..]


main :: IO ()
main = do
  args <- getArgs

  case args of
    [mode, roundsArg, numRolesArg, role]
      | Just benchmark <- selectBenchmark mode
      , Just rounds <- readMaybe roundsArg
      , Just numRoles <- readMaybe numRolesArg
      , rounds > 0
      , numRoles >= 2
      , numRoles <= 100
      , role `elem` roleNames numRoles -> do
          putStrLn $
            "Benchmark: " ++ mode
            ++ " | Rounds: " ++ show rounds
            ++ " | Roles: " ++ show numRoles
            ++ " | Running as: " ++ role
          runChoreography (InstrumentedHttpConfig (config numRoles)) (benchmark rounds) role

    _ ->
      die "Usage: r-benchmark <original|selective> <rounds> <numRoles> <role>"

