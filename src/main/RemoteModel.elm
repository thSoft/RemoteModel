module RemoteModel where

import Signal exposing (..)
import Signal
import Maybe exposing (..)
import Maybe
import Result exposing (..)
import Result
import List exposing (..)
import List
import Dict exposing (..)
import Json.Decode exposing (..)
import Json.Decode as Decode
import Graphics.Element exposing (..)
import Graphics.Element as Element
import Graphics.Input exposing (..)
import Graphics.Input.Field exposing (..)
import Graphics.Input.Field as Field
import Text exposing (..)
import ExternalStorage.Cache as Cache
import ExternalStorage.Cache exposing (..)
import ExternalStorage.Reference as Reference
import ExternalStorage.Reference exposing (..)

main : Signal Element
main = Signal.map2 view bookUrlContent model

-- Model

model : Signal (Reference Book)
model =
  let load bookUrl cache = Reference.create (bookDecoder cache) bookUrl cache
  in Signal.map2 load bookUrl cache

type alias Writer = {
  name: String
}

type alias Book = {
  title: String,
  authors: List (Reference Writer)
}

bookDecoder : Cache -> Decoder Book
bookDecoder cache =
  object2 Book
    ("title" := string)
    ("authors" := list (Reference.decoder writerDecoder cache))

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
writerUrls = Signal.map collectWriterUrls model

collectWriterUrls : Reference Book -> List String
collectWriterUrls bookReference =
  bookReference.get |> toMaybe |> Maybe.map (\book -> book.authors |> List.map .url) |> withDefault []

-- Input

bookUrlContent : Signal Content
bookUrlContent = bookUrlContentMailbox.signal

bookUrlContentMailbox : Mailbox Content
bookUrlContentMailbox = mailbox noContent

-- View

view : Content -> Reference Book -> Element
view bookUrlContent bookReference =
  let urlField = field Field.defaultStyle (bookUrlContentMailbox.address |> message) "Book URL" bookUrlContent
      bookView = bookReference |> viewReference viewBook
  in [urlField, bookView] |> flow down

viewReference : (a -> Element) -> Reference a -> Element
viewReference viewValue reference = reference.get |> Result.map viewValue |> or (viewError reference.url)

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
  in text |> fromString |> leftAligned

viewBook : Book -> Element
viewBook book =
  let titleView = book.title |> fromString |> bold |> leftAligned
      authors = book.authors
      by = if authors |> isEmpty then Element.empty else " by:" |> fromString |> leftAligned
      header = [titleView, by] |> flow right
      authorsView = authors |> List.map (viewReference viewWriter)
  in header :: authorsView |> flow down

viewWriter : Writer -> Element
viewWriter writer = writer.name |> fromString |> leftAligned
