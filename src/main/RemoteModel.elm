module RemoteModel where

import Signal (..)
import Signal
import Maybe (..)
import Maybe
import Result (..)
import Result
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
import ExternalStorage.Cache (Cache)
import ExternalStorage.Cache as Cache
import ExternalStorage.Reference (Reference)
import ExternalStorage.Reference as Reference

main : Signal Element
main = Signal.map3 view bookUrlContent cache model

-- Model

model : Signal (Reference Book)
model = Signal.map (Reference.create bookDecoder) bookUrl

type alias Writer = {
  name: String
}

type alias Book = {
  title: String,
  authors: List (Reference Writer)
}

bookDecoder : Decoder Book
bookDecoder =
  object2 Book
    ("title" := string)
    ("authors" := list (Reference.decoder writerDecoder) |> fallback [])

fallback : a -> Decoder a -> Decoder a
fallback defaultValue decoder = Decode.oneOf [decoder, succeed defaultValue]

writerDecoder : Decoder Writer
writerDecoder = 
  object1 Writer
    ("name" := string)

-- Cache

cache : Signal Cache
cache = feed |> Cache.create

port feed : Signal Cache.Update

port urls : Signal (List String)
port urls = Signal.map2 (::) bookUrl writerUrls

bookUrl : Signal String
bookUrl = Signal.map .string bookUrlContent

writerUrls : Signal (List String)
writerUrls = Signal.map2 collectWriterUrls cache model

collectWriterUrls : Cache -> Reference Book -> List String
collectWriterUrls cache bookReference =
  bookReference.get cache |> toMaybe |> Maybe.map (\book -> book.authors |> List.map .url) |> withDefault []

-- Input

bookUrlContent : Signal Content
bookUrlContent = bookUrlContentChannel |> subscribe

bookUrlContentChannel : Channel Content
bookUrlContentChannel = channel noContent

-- View

view : Content -> Cache -> Reference Book -> Element
view bookUrlContent cache bookReference =
  let urlField = field Field.defaultStyle (bookUrlContentChannel |> send) "Book URL" bookUrlContent
      bookView = bookReference |> viewReference viewBook cache
  in [urlField, bookView] |> flow down

viewReference : (Cache -> a -> Element) -> Cache -> Reference a -> Element
viewReference viewValue cache reference = reference.get cache |> Result.map (viewValue cache) |> or (viewError reference.url)

or : (x -> a) -> Result x a -> a
or makeBadResult result =
  case result of
    Err error -> error |> makeBadResult
    Ok goodResult -> goodResult

viewError : String -> Reference.Error -> Element
viewError url error =
  let text = 
        case error of
          Reference.NotFound -> "[Loading " ++ url ++ "]"
          Reference.DecodingFailed message -> "[Can't decode " ++ url ++ ": " ++ message ++ "]"
  in text |> plainText

viewBook : Cache -> Book -> Element
viewBook cache book =
  let titleView = book.title |> fromString |> bold |> leftAligned
      authors = book.authors
      by = if authors |> isEmpty then Element.empty else " by:" |> plainText
      header = [titleView, by] |> flow right
      authorsView = authors |> List.map (viewReference viewWriter cache)
  in header :: authorsView |> flow down

viewWriter : Cache -> Writer -> Element
viewWriter _ writer = writer.name |> plainText