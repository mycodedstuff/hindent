{-# LANGUAGE OverloadedStrings #-}

-- | Test the pretty printer.

module Main where

import           Data.Algorithm.Diff
import           Data.Algorithm.DiffOutput
import qualified Data.ByteString as S
import           Data.ByteString.Lazy (ByteString)
import qualified Data.ByteString.Lazy as L
import qualified Data.ByteString.Lazy.Builder as L
import qualified Data.ByteString.Lazy.Char8 as L8
import qualified Data.ByteString.Lazy.UTF8 as LUTF8
import qualified Data.ByteString.UTF8 as UTF8
import           Data.Function
import           Data.Monoid
import           HIndent
import           HIndent.Types
import           Markdone
import           Test.Hspec

-- | Main benchmarks.
main :: IO ()
main = do
    bytes <- S.readFile "TESTS.md"
    forest <- parse (tokenize bytes)
    hspec (toSpec forest)

-- -- | Convert the Markdone document to Spec benchmarks.
toSpec :: [Markdone] -> Spec
toSpec = go
  where
    go (Section name children:next) = do
        describe (UTF8.toString name) (go children)
        go next
    go (PlainText desc:CodeFence lang code:next) =
      if lang == "haskell"
        then do
          it
            (UTF8.toString desc)
            (shouldBeReadable
               (either
                  (("-- " <>) . L8.pack)
                  L.toLazyByteString
                  (reformat
                     HIndent.Types.defaultConfig {configTrailingNewline = False}
                     (Just defaultExtensions)
                     code))
               (L.fromStrict code))
          go next
        else go next
    go (PlainText {}:next) = go next
    go (CodeFence {}:next) = go next
    go [] = return ()

-- | Version of 'shouldBe' that prints strings in a readable way,
-- better for our use-case.
shouldBeReadable :: ByteString -> ByteString -> Expectation
shouldBeReadable x y = shouldBe (Readable x (Just (diff y x))) (Readable y Nothing)

-- | Prints a string without quoting and escaping.
data Readable = Readable
  { readableString :: ByteString
  , readableDiff :: (Maybe String)
  }
instance Eq Readable where
  (==) = on (==) readableString
instance Show Readable where
  show (Readable x d') =
    "\n" ++
    LUTF8.toString x ++
    (case d' of
       Just d -> "\nThe diff:\n" ++ d
       Nothing -> "")

-- | A diff display.
diff :: ByteString -> ByteString -> String
diff x y = ppDiff (on (getGroupedDiff) (lines . LUTF8.toString) x y)
