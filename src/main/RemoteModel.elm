module RemoteModel where

import Signal (..)
import Signal
import Maybe (..)
import List (..)
import List
import Json.Decode (..)
import Graphics.Element (..)
import Graphics.Element as Element
import Graphics.Input (..)
import Graphics.Input.Field (..)
import Graphics.Input.Field as Field
import Text (..)
import Cache (..)

main : Signal Element
main = Signal.map3 view writerCache bookCache bookUrlContent

-- Model

type alias Writer = {
  name: String
}

writerCache : Signal (Cache Writer)
writerCache = writerFeed |> loadCache identity

port writerFeed : Signal (Entry Writer)

type alias Book = {
  title: String,
  authors: Maybe (List String)
}

bookCache : Signal (Cache Book)
bookCache = bookFeed |> loadCache makeBook

port bookFeed : Signal (Entry Value)

makeBook : Value -> Book
makeBook value =
  let decoder =
        object2 Book
          ("title" := string)
          (maybe ("authors" := list string))
      failedBook message =
        { 
          title = "Can't decode book: " ++ message,
          authors = Nothing
        }
  in value |> decodeValue decoder |> or failedBook

or : (x -> a) -> Result x a -> a
or makeBadResult result =
  case result of
    Err error -> error |> makeBadResult
    Ok goodResult -> goodResult

maybeList : (a -> Maybe (List b)) -> a -> List b
maybeList accessor object = object |> accessor |> withDefault []

bookUrlContent : Signal Content
bookUrlContent = bookUrlContentChannel |> subscribe

-- View

view : Cache Writer -> Cache Book -> Content -> Element
view writerCache bookCache bookUrlContent =
  let urlField = field Field.defaultStyle (bookUrlContentChannel |> send) "Book URL" bookUrlContent
      book = findAndViewBook writerCache bookCache bookUrlContent.string
  in [urlField, book] |> flow down

loading : String -> String -> Element
loading entity url = ("[" ++ entity ++ "@" ++ url ++ "]") |> plainText

findAndViewBook : Cache Writer -> Cache Book -> String -> Element
findAndViewBook writerCache bookCache url = findAndMap (viewBook writerCache) (loading "book" url) bookCache url

viewBook : Cache Writer -> Book -> Element
viewBook writerCache book =
  let titleView = book.title |> fromString |> bold |> leftAligned
      authors = book |> maybeList .authors
      by = if authors |> isEmpty then Element.empty else " by:" |> plainText
      header = [titleView, by] |> flow right
      authorsView = authors |> List.map (findAndViewWriter writerCache)
  in header :: authorsView |> flow down

findAndViewWriter : Cache Writer -> String -> Element
findAndViewWriter writerCache url = findAndMap viewWriter (loading "writer" url) writerCache url

viewWriter : Writer -> Element
viewWriter writer = writer.name |> plainText

-- Input

bookUrlContentChannel : Channel Content
bookUrlContentChannel = channel noContent

port bookUrls : Signal (List String)
port bookUrls = bookUrlContent |> Signal.map makeBookUrls

makeBookUrls : Content -> List String
makeBookUrls bookUrlContent = [bookUrlContent.string]

port writerUrls : Signal (List String)
port writerUrls = Signal.map2 collectWriterUrls bookUrlContent bookCache

collectWriterUrls : Content -> Cache Book -> List String
collectWriterUrls bookUrlContent bookCache = findAndMap (maybeList .authors) [] bookCache bookUrlContent.string