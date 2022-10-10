{-# LANGUAGE ScopedTypeVariables #-}

module Test.HSpec.MarkdownFormatterSpec where

import Data.List (isInfixOf)
import Hydra.Prelude
import System.Directory (createDirectoryIfMissing)
import System.FilePath (splitFileName, (</>))
import Test.Hspec.Core.Format (Event (..), Format, FormatConfig)
import Test.Hspec.Core.Runner (
  Config (..),
  Summary (..),
  defaultConfig,
  hspecWith,
  hspecWithResult,
 )
import Test.Hspec.MarkdownFormatter
import Test.Hydra.Prelude
import Test.QuickCheck (Positive (..), Small (..), counterexample, forAll, frequency, property, vectorOf)
import Test.QuickCheck.Monadic (assert, forAllM, monadic, monadicIO, monitor, run)

testSpec :: Spec
testSpec =
  describe "Some Spec" $
    describe "Sub Spec" $ do
      it "does one thing" $ True `shouldBe` True
      it "does two things" $ True `shouldBe` True

spec :: Spec
spec =
  around (withTempDir "foo") $ do
    it "generates markdown content to file when running spec" $ \tmpDir ->
      property $
        monadicIO $
          forAllM (genDescribe 3) $ \aSpecTree -> do
            content <- run $ do
              let markdownFile = tmpDir </> "result.md"
              summary <-
                hspecWithResult
                  defaultConfig
                    { configIgnoreConfigFile = True -- Needed to ensure we don't mess up this run with our default config
                    , configFormat = Just (markdownFormatter markdownFile)
                    }
                  (toSpec aSpecTree)
              readFile markdownFile
            monitor (counterexample content)
            assert $ all (`isInfixOf` content) $ listLabels aSpecTree

listLabels :: TestTree -> [String]
listLabels = go []
 where
  go acc (Describe s tts) = foldMap (go (s : acc)) tts
  go acc (It s) = s : acc

toSpec :: TestTree -> Spec
toSpec (Describe s tts) =
  describe s $ forM_ tts toSpec
toSpec (It s) =
  it s $ True `shouldBe` True

data TestTree
  = Describe String [TestTree]
  | It String
  deriving (Eq, Show)

genDescribe :: Int -> Gen TestTree
genDescribe maxDepth = do
  (Positive (Small n)) <- arbitrary
  Describe <$> someLabel <*> vectorOf n (genSpecTree (maxDepth - 1))

genSpecTree :: Int -> Gen TestTree
genSpecTree 0 = It <$> someLabel
genSpecTree maxDepth =
  frequency
    [ (5, It <$> someLabel)
    ,
      ( 1
      , genDescribe maxDepth
      )
    ]

someLabel :: Gen String
someLabel = do
  Positive (n :: Int) <- arbitrary
  pure $ "test-" <> show n
