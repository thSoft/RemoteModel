module RemoteModel where

import Signal (..)
import Signal
import Maybe (..)
import Maybe
import List (..)
import List
import Dict (..)
import Json.Decode (..)
import Json.Decode as Decode
import Graphics.Element (..)
import Graphics.Element as Element
import Graphics.Input (..)
import Graphics.Input.Field (..)
import Graphics.Input.Field as Field
import Text (..)
import Cache (..)
import Cache

main : Signal Element
main = Signal.map3 view writerCache bookCache bookUrlContent

-- Model

type alias Writer = {
  name: String
}

writerCache : Signal (Cache Writer)
writerCache = writerFeed |> Cache.create identity

port writerFeed : Signal (Cache.Update Writer)

type alias Book = {
  title: String,
  authors: List (Reference Writer)
}

bookCache : Signal (Cache Book)
bookCache = bookFeed |> Cache.create decodeBook

port bookFeed : Signal (Cache.Update Value)

decodeBook : Value -> Book
decodeBook value =
  let decoder =
        object2 Book
          ("title" := string)
          ("authors" := list reference |> fallback [])
      failedBook message =
        { 
          title = "Can't decode book: " ++ message,
          authors = []
        }
  in value |> decodeValue decoder |> or failedBook

fallback : a -> Decoder a -> Decoder a
fallback defaultValue decoder = Decode.oneOf [decoder, succeed defaultValue]

or : (x -> a) -> Result x a -> a
or makeBadResult result =
  case result of
    Err error -> error |> makeBadResult
    Ok goodResult -> goodResult

bookUrlContent : Signal Content
bookUrlContent = bookUrlContentChannel |> subscribe

-- View

view : Cache Writer -> Cache Book -> Content -> Element
view writerCache bookCache bookUrlContent =
  let urlField = field Field.defaultStyle (bookUrlContentChannel |> send) "Book URL" bookUrlContent
      url = bookUrlContent.string
      book = bookCache |> get url |> Maybe.map (viewBook writerCache) |> withDefault (loading "book" url)
  in [urlField, book] |> flow down

loading : String -> String -> Element
loading entity url = ("[" ++ entity ++ "@" ++ url ++ "]") |> plainText

viewBook : Cache Writer -> Book -> Element
viewBook writerCache book =
  let titleView = book.title |> fromString |> bold |> leftAligned
      authors = book.authors
      by = if authors |> isEmpty then Element.empty else " by:" |> plainText
      header = [titleView, by] |> flow right
      authorsView = authors |> List.map (\reference -> writerCache |> reference.lookup |> Maybe.map viewWriter |> withDefault (loading "writer" reference.url))
  in header :: authorsView |> flow down

viewWriter : Writer -> Element
viewWriter writer = writer.name |> plainText

-- Input

bookUrlContentChannel : Channel Content
bookUrlContentChannel = channel noContent

port bookUrls : Signal (List String)
port bookUrls = Signal.map collectBookUrls bookUrlContent

collectBookUrls : Content -> List String
collectBookUrls bookUrlContent = [bookUrlContent.string]

port writerUrls : Signal (List String)
port writerUrls = Signal.map2 collectWriterUrls bookUrlContent bookCache

collectWriterUrls : Content -> Cache Book -> List String
collectWriterUrls bookUrlContent bookCache =
  bookCache
  |> get bookUrlContent.string
  |> Maybe.map (.authors >> List.map .url)
  |> withDefault []