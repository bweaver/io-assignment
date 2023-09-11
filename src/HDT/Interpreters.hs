
module HDT.Interpreters
    ( 
      delay
    , broadcast  
    , receive 
    , ping
    , pong 
    , loggingQueue
    , sharedChan
    , runPingAndPong
    ) where 

import Control.Concurrent.STM
import Control.Concurrent
import Control.Monad -- hiding (forever)
import DATA.SharedData (PingPong(..))


type SharedChannel = TChan PingPong
type LoggingQueue  = TChan String


loggingQueue :: IO(LoggingQueue)
loggingQueue = do
    queue <- newTChanIO
    forkIO . forever $ atomically (readTChan queue) >>= putStrLn
    return queue

sharedChan :: IO LoggingQueue
sharedChan = atomically newTChan

sequentialLog :: String -> LoggingQueue -> IO ()
sequentialLog msg loggingQueue = atomically $ writeTChan loggingQueue msg  

runPingAndPong :: [SharedChannel -> LoggingQueue -> Int -> IO ()] -> IO ()
runPingAndPong list  = do  

          sharedChan <- atomically $ newTChan
          loggingQueue <- loggingQueue


  --        let list = [ping, pong]
          let zList = zip [1..(length list + 1)] list
          forM_ zList (\(n, task) -> (item (task sharedChan loggingQueue)  n)) 
          
    where 
    item the_task id = forkIO ((do { (the_task id )}))

receive :: SharedChannel -> STM PingPong
receive sc = do 
  status <- tryReadTChan sc
  case status of
    Nothing -> retry
    Just msg -> return msg


ping :: SharedChannel -> LoggingQueue -> Int -> IO ()
ping sc lq idOfThread = delay >> broadcast Ping sc >> sequentialLog (show Ping) lq >> go
  where go = do 
           msg <- atomically $ receive sc 
           case msg of 
             Ping -> (atomically $ unGetTChan sc Ping) >> go
             Pong -> 
               ping sc lq idOfThread 

delay :: IO ()
delay = threadDelay (10^6)

broadcast :: PingPong -> SharedChannel -> IO ()
broadcast msg sc = 
  atomically $ writeTChan sc msg 

pong :: SharedChannel -> LoggingQueue -> Int -> IO ()
pong sc lq idOfThread =  do 
         msg <- atomically $ receive sc
         case msg of   
           Ping ->  
             delay >> broadcast Pong sc >> sequentialLog (show Pong) lq>> pong sc lq idOfThread 
                      
           Pong ->  
             (atomically $ unGetTChan sc Pong) >> pong sc lq idOfThread