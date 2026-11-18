{-# LANGUAGE GADTs     #-}

module Choreography.Network.HttpInstrumented
  ( runNetworkHttpInstrumented
  , InstrumentedHttpConfig(..)
  ) where


import Choreography.Network.Http
  ( API
  , HttpConfig(..)
  , RecvChans
  , locs
  , mkRecvChans
  )
import Choreography.Location
import Choreography.Network hiding (run)
import Control.Concurrent
import Control.Concurrent.Chan
import Control.Monad.Freer
import Control.Monad.IO.Class
import Data.HashMap.Strict ((!))
import Data.IORef
import Data.Proxy
import Network.HTTP.Client
  ( Manager
  , defaultManagerSettings
  , newManager
  )
import Network.Wai.Handler.Warp (run)
import Servant.API hiding (Host)
import Servant.Client
import Servant.Server



runNetworkHttpInstrumented :: MonadIO m => HttpConfig -> LocTm -> Network m a -> m a
runNetworkHttpInstrumented cfg self prog = do
  mgr <- liftIO $ newManager defaultManagerSettings
  chans <- liftIO $ mkRecvChans cfg

  -- Count successful HTTP sends.
  sentCount <- liftIO $ newIORef 0

  recvT <- liftIO $ forkIO (recvThread cfg chans)

  result <- runNetworkMain sentCount mgr chans prog

  liftIO $ threadDelay 1000000
  liftIO $ killThread recvT

  -- Print the total number of sent messages.
  total <- liftIO $ readIORef sentCount
  liftIO $ putStrLn $
    "[Network] " ++ self ++ ": " ++ show total ++ " messages sent"

  return result
  where
    runNetworkMain :: MonadIO m => IORef Int -> Manager -> RecvChans -> Network m a -> m a
    runNetworkMain sentCount mgr chans = interpFreer handler
      where
        handler :: MonadIO m => NetworkSig m a -> m a
        handler (Run m)    = m
        handler (Send a l) = liftIO $ do
          res <- runClientM (send self $ show a) (mkClientEnv mgr (locToUrl cfg ! l))
          case res of
            Left err ->
              putStrLn $ "Error : " ++ show err
            Right _ ->
              modifyIORef' sentCount (+1)
        handler (Recv l)   = liftIO $ read <$> readChan (chans ! l)
        handler (BCast a)  = mapM_ handler $ fmap (Send a) (filter (/= self) (locs cfg))

    api :: Proxy API
    api = Proxy

    send :: LocTm -> String -> ClientM NoContent
    send = client api

    server :: RecvChans -> Server API
    server chans = handler
      where
        handler :: LocTm -> String -> Handler NoContent
        handler rmt msg = do
          liftIO $ writeChan (chans ! rmt) msg
          return NoContent

    recvThread :: HttpConfig -> RecvChans -> IO ()
    recvThread cfg chans = run (baseUrlPort $ locToUrl cfg ! self ) (serve api $ server chans)



newtype InstrumentedHttpConfig = InstrumentedHttpConfig HttpConfig

instance Backend InstrumentedHttpConfig where
  runNetwork (InstrumentedHttpConfig cfg)  =  runNetworkHttpInstrumented cfg
