{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE TypeOperators #-}

module Main where

import Choreography.Location (type (@))
import Data.Proxy
import RestrictedChoreography
import Choreography (runChoreography)
import Choreography.Choreo
import Choreography.Location
import Choreography.Network.Http
import System.Environment (getArgs)
import System.Exit (die)


-- Locations

alice :: Proxy "alice"
alice = Proxy
bob :: Proxy "bob"
bob = Proxy
charlie :: Proxy "charlie"
charlie = Proxy


-- Sending message: positive test (should compile and run successfully)

validComm :: RestrictedChoreo '["alice", "bob"] IO
                          (Int @ "bob")
validComm = do
  x <- locallyR alice (\_ -> pure (42 :: Int))
  commR (alice, x) bob


-- Sending message: negative test (should fail to compile)

-- invalidComm :: RestrictedChoreo '["alice", "bob"] IO
--                             (Int @ "charlie")
-- invalidComm = do
--   x <- locallyR alice (\_ -> pure (42 :: Int))
--   commR (alice, x) charlie


-- Conditional: positive test (should compile and run successfully)

validCond :: RestrictedChoreo '["alice", "bob"] IO ()
validCond = do
  decision <- locallyR alice (\_ -> pure True)

  condR (alice, decision) $ \choice ->
    if choice
      then do
        x <- locallyR alice (\_ -> pure (42 :: Int))
        _ <- commR (alice, x) bob
        pure ()
      else
        pure ()


-- Conditional: negative test (should fail to compile)

-- invalidCond :: RestrictedChoreo '["alice", "bob"] IO ()
-- invalidCond = do
--   decision <- locallyR alice (\_ -> pure True)

--   condR (alice, decision) $ \choice ->
--     if choice
--       then do
--         x <- locallyR alice (\_ -> pure (42 :: Int))
--         _ <- commR (alice, x) charlie
--         pure ()
--       else
--         pure ()


-- Coerce: negative test (should fail to compile)

-- badCoerce
--   :: RestrictedChoreo '["alice", "bob"] IO ()
--   -> RestrictedChoreo '["alice"] IO ()
-- badCoerce = coerce


demo :: Choreo IO ()
demo = do
  decision <- locally alice (\_ -> pure True)

  condSelective
    (Proxy @'["alice", "bob"])
    (alice, decision) $ \choice -> do

      if choice
        then do
          -- First message from Alice to Bob.
          x <- locallyR alice (\_ -> pure (42 :: Int))
          y <- commR (alice, x) bob

          -- Second decision, by Bob.
          secondDecision <- locallyR bob $ \un ->
            pure (un y > 10)

          -- Nested restricted conditional.
          condR (bob, secondDecision) $ \secondChoice ->
            if secondChoice
              then do
                _ <- locallyR bob $ \_ -> do
                  putStrLn "Bob: second condition is True"
                  pure ()
                pure ()
              else pure ()

        else pure ()

  -- Charlie does not participate in any conditionals.
  _ <- locally charlie $ \_ -> do
    putStrLn "Charlie: finishing"
    pure ()

  pure ()


-- main :: IO ()
-- main = runChoreo demo

main :: IO ()
main = do
  args <- getArgs
  case args of
    [loc] | loc `elem` ["alice", "bob", "charlie"] ->
      runChoreography cfg demo loc

    _ -> die "Use: r-test alice|bob|charlie"
  where
    cfg = mkHttpConfig
      [ ("alice",   ("127.0.0.1", 4242))
      , ("bob",     ("127.0.0.1", 4343))
      , ("charlie", ("127.0.0.1", 4444))
      ]


