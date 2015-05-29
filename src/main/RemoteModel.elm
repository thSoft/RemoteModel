module RemoteModel where

import Signal exposing (..)
import Json.Decode exposing (..)
import Graphics.Element as Element exposing (..)
import Graphics.Input.Field as Field exposing (..)
import Text exposing (..)
import ExternalStorage.Cache as Cache exposing (..)
import ExternalStorage.Loader exposing (..)

main : Signal Element
main = Signal.map2 view bookUrlContentMailbox.signal model

-- Model

model : Signal (Result Error (Remote Book))
model = Signal.map2 loadBook cache bookUrl

loadBook : Cache -> String -> Result Error (Remote Book)
loadBook cache url = load cache rawBookDecoder parseBook url

type alias Book = {
  title: String,
  author: Remote Writer
}

rawBookDecoder : Decoder RawBook
rawBookDecoder =
  object2 RawBook
    ("title" := string)
    ("author" := string)

parseBook : Cache -> RawBook -> Result Error Book
parseBook cache rawBook =
  let authorResult = rawBook.author |> loadWriter cache
  in
    authorResult |> Result.map (\author ->
      {
        title = rawBook.title,
        author = author
      }
    )

type alias RawBook = {
  title: String, -- XXX extract common fields when https://github.com/elm-lang/elm-compiler/issues/917 is fixed
  author: String
}

loadWriter : Cache -> String -> Result Error (Remote Writer)
loadWriter cache url = loadRaw cache writerDecoder url

type alias Writer = {
  name: String
}

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

collectWriterUrls : Result Error (Remote Book) -> List String
collectWriterUrls bookResult =
  case bookResult of
    Result.Err error ->
      case error of
        NotFound { url } -> [url]
        _ -> []
    Result.Ok book -> [book.author.url]

-- Input

bookUrlContentMailbox : Mailbox Content
bookUrlContentMailbox = mailbox noContent

-- View

view : Content -> Result Error (Remote Book) -> Element
view bookUrlContent bookResult =
  let urlField = field Field.defaultStyle (bookUrlContentMailbox.address |> message) "Book URL" bookUrlContent
      bookView = bookResult |> viewReference viewBook
  in [urlField, bookView] |> flow down

viewReference : (Remote a -> Element) -> Result Error (Remote a) -> Element
viewReference viewValue result = result |> Result.map viewValue |> or viewError

or : (x -> a) -> Result x a -> a
or makeBadResult result =
  case result of
    Err error -> error |> makeBadResult
    Ok goodResult -> goodResult

viewError : Error -> Element
viewError error =
  let text =
        case error of
          NotFound { url }-> "[Loading " ++ url ++ "]"
          DecodingFailed { url, message } -> "[Can't decode " ++ url ++ ": " ++ message ++ "]"
  in text |> fromString |> leftAligned

viewBook : Remote Book -> Element
viewBook book =
  let titleView = book.title |> fromString |> bold |> leftAligned
      by = " by:" |> fromString |> leftAligned
      header = [titleView, by] |> flow right
      authorView = book.author |> viewWriter
  in [header, authorView] |> flow down

viewWriter : Remote Writer -> Element
viewWriter writer = writer.name |> fromString |> leftAligned
