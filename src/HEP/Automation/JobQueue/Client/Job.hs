{-# LANGUAGE OverloadedStrings #-}

module HEP.Automation.JobQueue.Client.Job where

import System.FilePath

import Network.HTTP.Types hiding (statusCode)
import Network.HTTP.Enumerator
import qualified Data.ByteString.Lazy.Char8 as C
import qualified Data.ByteString.Char8 as SC

import HEP.Automation.JobQueue.Config
import HEP.Automation.JobQueue.JobQueue
import HEP.Automation.JobQueue.JobJson

import HEP.Storage.WebDAV.Type

import Data.Aeson.Types
import Data.Aeson.Encode

type Url = String 

jobqueueGet :: Url -> JobNumber -> IO () 
jobqueueGet url jid = do 
  putStrLn "get" 
  manager <- newManager
  requestget <- parseUrl (SC.pack (url </> "job" </> (show jid)))
  let requestgetjson = requestget { 
        requestHeaders = [ ("Accept", "application/json; charset=utf-8") ] 
      }
  r <- httpLbs requestgetjson manager 
  putStrLn $ show r 

jobqueuePut :: Url -> JobInfo -> IO (Maybe JobInfo)
jobqueuePut url jinfo = do 
  putStrLn "put" 
  manager <- newManager 
  requesttemp <- parseUrl (SC.pack (url </> "job" 
                                        </> show (jobinfo_id jinfo)))
  let myrequestbody = RequestBodyLBS . encode . toAeson $ jinfo
  let requestput = requesttemp { 
                     method = methodPut, 
                     requestHeaders = [ ("Content-Type", "text/plain") 
                                      , ("Accept", "application/json; charset=utf-8")], 
                     requestBody = myrequestbody 
                   } 
  r <- httpLbs requestput manager 
  putStrLn $ show r 
  return (Just jinfo)

jobqueueList :: Url -> IO () 
jobqueueList url = do 
  putStrLn "list"
  manager <- newManager 
  requestget <- parseUrl (SC.pack (url </> "queuelist"))
  let requestgetjson = requestget { 
        requestHeaders = [ ("Accept", "application/json; charset=utf-8") ] 
      }
  r <- httpLbs requestgetjson manager 
  putStrLn $ show r 

jobqueueUnassigned :: Url -> IO () 
jobqueueUnassigned url = do 
  putStrLn "jobs unassigned:"
  manager <- newManager 
  requestget <- parseUrl (SC.pack (url </> "queuelist/unassigned"))
  let requestgetjson = requestget { 
        requestHeaders = [ ("Accept", "application/json; charset=utf-8") ] 
      }
  r <- httpLbs requestgetjson manager 
  putStrLn $ show r 

jobqueueInprogress :: Url -> IO ()
jobqueueInprogress url = do 
  putStrLn "jobs in progress:"
  manager <- newManager 
  requestget <- parseUrl (SC.pack (url </> "queuelist/inprogress"))
  let requestgetjson = requestget { 
        requestHeaders = [ ("Accept", "application/json; charset=utf-8") ] 
      }
  r <- httpLbs requestgetjson manager 
  putStrLn $ show r 

jobqueueFinished :: Url -> IO ()
jobqueueFinished url = do 
  putStrLn "jobs finished:"
  manager <- newManager 
  requestget <- parseUrl (SC.pack (url </> "queuelist/finished"))
  let requestgetjson = requestget { 
        requestHeaders = [ ("Accept", "application/json; charset=utf-8") ] 
      }
  r <- httpLbs requestgetjson manager 
  putStrLn $ show r 

jobqueueAssign :: Url -> ClientConfiguration -> IO (Maybe JobInfo) 
jobqueueAssign url cc = do 
  putStrLn $ "Assign request of job "
  manager <- newManager 
  requesttemp <- parseUrl (SC.pack (url </> "assign"))
  let ccjson = encode $ toAeson cc
      myrequestbody = RequestBodyLBS ccjson 
      requestpost = requesttemp { 
                      method = methodPost, 
                      requestHeaders = [ ("Content-Type", "text/plain") 
                                       , ("Accept", "application/json; charset=utf-8")], 
                      requestBody = myrequestbody } 
  r <- httpLbs requestpost manager 
  let result = ( parseJson  . SC.concat . C.toChunks .  responseBody ) r :: Maybe (Either String JobInfo) 
  case result of 
    Just (Right jinfo) -> do return (Just jinfo)

    Just (Left msg)    -> do putStrLn "Error message from server" 
                             putStrLn msg
                             return Nothing
    Nothing            -> do putStrLn "Parsing failed"
                             return Nothing 


confirmAssignment :: Url -> JobInfo -> IO (Maybe JobInfo)
confirmAssignment url jinfo = do  
  putStrLn "try confirmation"
  putStrLn (show jinfo)
  case jobinfo_status jinfo of 
    Unassigned -> do 
      let newjob = jinfo { jobinfo_status = Assigned } 
      jobqueuePut url newjob 
    _ -> return Nothing 

backToUnassigned :: Url -> JobInfo -> IO (Maybe JobInfo)
backToUnassigned url jinfo = changeStatus url jinfo Unassigned 

changeStatus :: Url -> JobInfo -> JobStatus -> IO (Maybe JobInfo)
changeStatus url jinfo status = do 
  let newjob = jinfo { jobinfo_status = status } 
  jobqueuePut url newjob

getWebDAVInfo :: Url -> IO (Maybe WebDAVServer)
getWebDAVInfo url = do 
  r <- getJsonFromServer url "config/webdav" 
  case r of 
    Nothing -> return Nothing
    Just value -> do 
      let c = fromAeson value :: Maybe WebDAVServer
      return c


getJsonFromServer :: Url -> String -> IO (Maybe Value)
getJsonFromServer url api = do 
  manager <- newManager
  requestget <- parseUrl (SC.pack (url </> api))
  let requestgetjson = requestget { 
        requestHeaders = [ ("Accept", "application/json; charset=utf-8") ] 
      } 
  r <- httpLbs requestgetjson manager 
  if statusCode r == 200 
    then return . parseJson . SC.concat . C.toChunks . responseBody $ r
    else return Nothing


