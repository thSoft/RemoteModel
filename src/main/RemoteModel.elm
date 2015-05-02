module RemoteModel where

import Signal exposing (..)
import Maybe exposing (..)
import Result exposing (..)
import List exposing (..)
import Json.Decode exposing (..)
import Graphics.Element exposing (..)
import Graphics.Element as Element
import Graphics.Input.Field exposing (..)
import Graphics.Input.Field as Field
import Text exposing (..)
import ExternalStorage.Cache exposing (..)
import ExternalStorage.Cache as Cache
import ExternalStorage.Reference exposing (..)
import ExternalStorage.Reference as Reference

main : Signal Element
main = Signal.map2 view bookUrlContentMailbox.signal model

-- Model

model : Signal (Reference Book)
model =
  let load bookUrl cache = Reference.create (bookDecoder cache) bookUrl cache
  in Signal.map2 load bookUrl cache

type alias Book = {
  title: String,
  authors: List (Reference Writer)
}

type alias Writer = {
  name: String
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
bookUrl = Signal.map .string bookUrlContentMailbox.signal

writerUrls : Signal (List String)
writerUrls = Signal.map collectWriterUrls model

collectWriterUrls : Reference Book -> List String
collectWriterUrls bookReference =
  bookReference.get |> toMaybe |> Maybe.map (\book -> book.authors |> List.map .url) |> withDefault []

-- Input

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
