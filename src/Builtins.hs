module Builtins where

import Prelude hiding (lookup)
import Data.Map (lookup, Map, empty, fromList)
import Control.Monad.Trans (MonadIO(liftIO), MonadTrans(lift))
import Control.Monad.Except (MonadError(throwError))
import Control.Monad.Reader (MonadReader(ask))
import System.Random (Random(randomRIO, randomIO))

import qualified AbsGrammar as AST
import Types (showType, Value(..), Interp, Store, FuncBody(BuiltIn))
import Text.Read (readMaybe)


paramList :: Int -> [String]
paramList n = ("p" ++) . show <$> [1 .. n]


getParams :: Int -> Interp [Value]
getParams n = do
  let ps = paramList n
  env <- lift ask
  getPIter env ps
 where
  getPIter :: Store -> [String] -> Interp [Value]
  getPIter _     []       = return []
  getPIter store (p : ps) = do
    case lookup p store of
      Nothing -> throwError "Failed to fetch argument for builtin."
      Just v  -> do
        rest <- getPIter store ps
        return $ v : rest


builtinEnv :: Store
builtinEnv = fromList
  [ ("floor"   , Lambda (paramList 1) (BuiltIn bFloor, empty))
  , ("ceil"    , Lambda (paramList 1) (BuiltIn bCeil, empty))
  , ("round"   , Lambda (paramList 1) (BuiltIn bRound, empty))
  , ("parseint", Lambda (paramList 1) (BuiltIn bParseInt, empty))
  , ("parsedbl", Lambda (paramList 1) (BuiltIn bParseDouble, empty))
  , ("tostr"   , Lambda (paramList 1) (BuiltIn bStr, empty))
  , ("rand"    , Lambda (paramList 0) (BuiltIn bRand, empty))
  , ("randint" , Lambda (paramList 2) (BuiltIn bRandint, empty))
  , ("head"    , Lambda (paramList 1) (BuiltIn bHead, empty))
  , ("tail"    , Lambda (paramList 1) (BuiltIn bTail, empty))
  , ("length"  , Lambda (paramList 1) (BuiltIn bLength, empty))
  , ("print"   , Lambda (paramList 1) (BuiltIn bPrint, empty))
  , ("println" , Lambda (paramList 1) (BuiltIn bPrintln, empty))
  , ("readln"  , Lambda (paramList 0) (BuiltIn bReadln, empty))
  ]



-- DOUBLE TO INT CONVERSIONS

-- | Convert a double d to closest integer i, where i <= d
bFloor :: Interp Value
bFloor = do
  [p] <- getParams 1
  case p of
    Double f -> return $ Int (floor f)
    Int    i -> return $ Int i
    v        -> throwError $ "Cannot evaluate \"floor\" for type " ++ showType v



-- | Convert a double d to closest integer i, where i >= d
bCeil :: Interp Value
bCeil = do
  [p] <- getParams 1
  case p of
    Double f -> return $ Int (ceiling f)
    Int    i -> return $ Int i
    v        -> throwError $ "Cannot evaluate \"ceil\" for type " ++ showType v


-- | Convert a double to closest integer 
bRound :: Interp Value
bRound = do
  [p] <- getParams 1
  case p of
    Double f -> return $ Int (round f)
    Int    i -> return $ Int i
    v        -> throwError $ "Cannot evaluate \"round\" for type " ++ showType v



-- PARSING VALUES FROM STRINGS

-- | Extract an integer value from a string, return void on failure.
bParseInt :: Interp Value
bParseInt = do
  [p] <- getParams 1
  case p of
    String s -> case readMaybe s :: Maybe Integer of
      Just i  -> return $ Int i
      Nothing -> return Void
    v -> throwError $ "Cannot parse integer from type " ++ showType v


-- | Extract a floating-point value from a string, return void on failure.
bParseDouble :: Interp Value
bParseDouble = do
  [p] <- getParams 1
  case p of
    String s -> case readMaybe s :: Maybe Double of
      Just d  -> return $ Double d
      Nothing -> return Void
    v -> throwError $ "Cannot parse double from type " ++ showType v



-- WRITING VALUES TO STRINGS

-- | Convert a value to its string representation.
bStr :: Interp Value
bStr = do
  [p] <- getParams 1
  return $ String (show p)



-- RANDOM NUMBER GENERATION

-- | Generate a random double in the range [0,1)
bRand :: Interp Value
bRand = do
  r <- liftIO (randomIO :: IO Double)
  return $ Double r


-- | Take two integers and generate a random in the range between them
bRandint :: Interp Value
bRandint = do
  [lo, hi] <- getParams 2
  case lo of
    Int i -> case hi of
      Int j -> if i <= j
        then do
          r <- liftIO $ randomRIO (i, j)
          return $ Int r
        else do
          r <- liftIO $ randomRIO (j, i)
          return $ Int r
      _ -> throwError "Cannot evaluate \"randint\" with non-integer arguments."
    _ -> throwError "Cannot evaluate \"randint\" with non-integer arguments."



-- LIST OPERATIONS

-- | Get the first element of a list.
bHead :: Interp Value
bHead = do
  [p] <- getParams 1
  case p of
    List [] -> throwError "Cannot evaluate head of empty list."
    List (x : xs) -> return x
    _ -> throwError "Cannot evaluate head of something that's not a list."


-- | Get a list excluding its first element.
bTail :: Interp Value
bTail = do
  [p] <- getParams 1
  case p of
    List [] -> throwError "Cannot evaluate tail of empty list."
    List (x : xs) -> return $ List xs
    _ -> throwError "Cannot evaluate tail of something that's not a list."


-- | Count the number of elements in a list.
bLength :: Interp Value
bLength = do
  [p] <- getParams 1
  case p of
    List l -> return $ Int (toInteger $ length l)
    _      -> throwError "Cannot evaluate tail of something that's not a list."



-- | IO 

-- | Print a value to stdout (no trailing newline).
bPrint :: Interp Value
bPrint = do
  [p] <- getParams 1
  liftIO $ putStr $ show p
  return Void


-- | Print a value to stdout, followed by a newline.
bPrintln :: Interp Value
bPrintln = do
  [p] <- getParams 1
  liftIO $ print p
  return Void


-- | Read a line of input from stdin, return the line as a string.
bReadln :: Interp Value
bReadln = do
  line <- liftIO getLine
  return $ String line
