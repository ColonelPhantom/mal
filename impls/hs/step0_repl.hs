#!/usr/bin/env runghc

import qualified System.Console.Haskeline as Hl

lRead :: String -> String
lRead = id

lEval :: String -> String
lEval = id

lPrint :: String -> String
lPrint = id

rep :: String -> String
rep = lPrint . lEval . lRead

mainLoop :: Hl.InputT IO ()
mainLoop = do
    input <- Hl.getInputLine "user> " 
    case input of
      Nothing -> return ()
      Just s -> do
        Hl.outputStrLn (rep s)
        mainLoop


main :: IO ()
main = Hl.runInputT Hl.defaultSettings mainLoop