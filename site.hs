--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import Hakyll

import Control.Applicative
import Control.Monad
import Data.List
import Data.Monoid
import Text.Pandoc
--------------------------------------------------------------------------------

itemsPerPage :: Integral a => a
itemsPerPage = 3

main :: IO ()
main = hakyll $ do -- {
  match "images/*" $ do -- {
    route   idRoute
    compile copyFileCompiler -- }

  match "css/*" $ do -- {
    route   idRoute
    compile compressCssCompiler -- }

  match "posts/*" $ do -- {
    route $ setExtension "html"
    compile $ withPandocOptions pandocCompilerWith -- {
      >>= loadAndApplyTemplate "templates/post.html"    postContext
      >>= absolutizeAnchors
      >>= saveSnapshot "post"
      >>= loadAndApplyTemplate "templates/postpage.html" postContext
      >>= loadAndApplyTemplate "templates/default.html" postContext
      >>= relativizeUrls -- }}

  match "meta/info/*" $ do -- {
    route $ -- {
      gsubRoute "^meta/info/" (const "")  `composeRoutes`
      setExtension "html" -- }
    compile $ withPandocOptions pandocCompilerWith -- {
      >>= loadAndApplyTemplate "templates/default.html" worldContext
      >>= relativizeUrls -- }}


  match "meta/*" $ do -- {
    route $ -- {
      gsubRoute "^meta/" (const "")  `composeRoutes`
      setExtension "html" -- }
    compile $ do -- {
      let -- {{
          getAllPosts = do -- {
            posts <- loadAllSnapshots "posts/*" "post"
            recentFirst posts -- }
          getRecent = take itemsPerPage <$> getAllPosts
          indexContext = -- {
            listField "allposts" postContext getAllPosts  <>
            listField "pageposts" postContext getRecent <>
            constField "nextpage" "2" <>
            worldContext -- }}}
      getResourceBody -- {
        >>= applyAsTemplate indexContext
        >>= return . withPandocOptions renderPandocWith
        >>= loadAndApplyTemplate "templates/default.html" indexContext
        >>= relativizeUrls -- }}}

  paginate itemsPerPage $ \maxPage page xs -> do -- {
    create [fromFilePath $ "page" ++ show page ++ ".html"] $ do -- {
      route idRoute
      compile $ do -- {
        let -- {{
            snaps = mapM (`loadSnapshot` "post") xs
            title = "Page " ++ show page ++ " of " ++ show maxPage
            prev 1 = Nothing
            prev n = Just $ -- {
              constField "prevpage" (show (n-1)) <>
              listField "headpages" worldContext -- {
                (mapM (makeItem . show) [1..n-2]) -- }}
            next n -- {
              | n == maxPage = Nothing
              | True = Just $ -- {
                constField "nextpage" (show (n+1)) <>
                listField "tailpages" worldContext -- {
                  (mapM (makeItem . show) [n+2..maxPage]) -- }}}
            pagesContext = -- {
              constField "thispage" (show page) <>
              prev page <?>
              next page <?>
              listField "pageposts" postContext snaps <>
              constField "title" title <>
              constField "suppresstitle" "true" <>
              worldContext -- }}}
        makeItem "" -- {
          >>= loadAndApplyTemplate "templates/pages.html" pagesContext
          >>= loadAndApplyTemplate "templates/default.html" pagesContext
          >>= relativizeUrls -- }}}}

  match "templates/*" $ compile templateCompiler -- }


--------------------------------------------------------------------------------
absolutizeAnchors :: Item String -> Compiler (Item String)
absolutizeAnchors item = aaWith <$> getRoute (itemIdentifier item)-- {
  where aaWith Nothing = item -- {{{
        aaWith (Just ru) = withUrls (aaEach ru) <$> item
        aaEach r p@('#':_) = '/' : r ++ p -- assumes relativizeUrls
        aaEach _ p = p -- }}}}

maypend :: Monoid a => Maybe a -> a -> a
maypend Nothing b = b
maypend (Just a) b = a <> b

(<?>) :: Monoid a => Maybe a -> a -> a
(<?>) = maypend
infixr 6 `maypend`, <?>

paginate :: Int -> (Int -> Int -> [Identifier] -> Rules a) -> Rules ()
paginate per go = do -- {{
    posts <- reverse . sort <$> getMatches "posts/*"
    let -- {{
        poparts = parts posts
        maxPage = length poparts -- }}
    zipWithM_ (go maxPage) [1..] poparts -- }
  where parts = takeWhile (not . null) -- {{{{{{
              . map (take per)
              . zipWith drop [0,per..]
              . repeat -- }}}}}}}

worldContext :: Context String
worldContext = -- {
  constField "site" "The Cat in no Hat" <>
  defaultContext -- }

postContext :: Context String
postContext = -- {
  dateField "date" "%e %B %Y" <>
  worldContext -- }

withPandocOptions :: (ReaderOptions -> WriterOptions -> a) -> a
withPandocOptions f = f readerOptions writerOptions -- {
  where readerOptions = defaultHakyllReaderOptions -- {{{
        writerOptions = defaultHakyllWriterOptions -- {
          { writerHtml5 = True } -- }}}}}
