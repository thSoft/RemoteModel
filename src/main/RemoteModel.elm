module RemoteModel where

import Signal exposing (..)
import Json.Decode exposing (..)
import Graphics.Element as Element exposing (..)
import Graphics.Input exposing (..)
import Graphics.Input.Field as Field exposing (..)
import Text exposing (..)
import ExternalStorage.Cache as Cache exposing (..)
import ExternalStorage.Loader exposing (..)

main : Signal Element
main = Signal.map2 view libraryUrlContentMailbox.signal model

-- Model

model : Signal (Loaded Library)
model = Signal.map2 loadLibrary cache libraryUrl

loadLibrary : Cache -> String -> Loaded Library
loadLibrary cache url = load cache rawLibraryDecoder resolveLibrary url

type alias Library = {
  books: List (Remote Book)
}

rawLibraryDecoder : Decoder RawLibrary
rawLibraryDecoder =
  object1 RawLibrary
    ("books" := list string)

resolveLibrary : Cache -> RawLibrary -> Result Error Library
resolveLibrary cache rawLibrary =
  let booksResult = rawLibrary.books |> loadList cache loadBook
  in
    booksResult |> Result.map (\books ->
      {
        books = books
      }
    )

type alias RawLibrary = {
  books: List String
}

loadBook : Cache -> String -> Loaded Book
loadBook cache url = load cache rawBookDecoder resolveBook url

type alias Book = {
  title: String,
  author: Remote Writer
}

rawBookDecoder : Decoder RawBook
rawBookDecoder =
  object2 RawBook
    ("title" := string)
    ("author" := string)

resolveBook : Cache -> RawBook -> Result Error Book
resolveBook cache rawBook =
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

loadWriter : Cache -> String -> Loaded Writer
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
port urls = Signal.map2 (::) libraryUrl otherUrls

libraryUrl : Signal String
libraryUrl = Signal.map .string libraryUrlContentMailbox.signal

otherUrls : Signal (List String)
otherUrls = Signal.map collectUrlsOfLibraryResult model

collectUrlsOfLibraryResult : Loaded Library -> List String
collectUrlsOfLibraryResult libraryResult =
  case libraryResult of
    Result.Err error ->
      case error of
        NotFound { url } -> [url]
        _ -> []
    Result.Ok library ->
      library.books |> List.map collectUrlsOfBook |> List.concat

collectUrlsOfBook : Remote Book -> List String
collectUrlsOfBook book = [book.url, book.author.url]

-- Input

libraryUrlContentMailbox : Mailbox Content
libraryUrlContentMailbox = mailbox noContent

-- View

view : Content -> Loaded Library -> Element
view libraryUrlContent loadedLibrary =
  let urlField = field Field.defaultStyle (libraryUrlContentMailbox.address |> message) "Library URL" libraryUrlContent
      exampleContent = Content "https://thsoft.firebaseio-demo.com/RemoteModel/library/0" (Selection 0 0 Forward)
      exampleButton = button (exampleContent |> message libraryUrlContentMailbox.address) "Load example data"
      header = [urlField, exampleButton] |> flow right
      libraryView = loadedLibrary |> viewLoaded viewLibrary
  in [header, libraryView] |> flow down

viewLoaded : (Remote a -> Element) -> Loaded a -> Element
viewLoaded viewObject result = result |> Result.map viewObject |> or viewError

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

viewLibrary : Remote Library -> Element
viewLibrary library =
  let header = "Books:" |> fromString |> leftAligned
      booksView = library.books |> List.map viewBook |> flow down
  in [header, booksView] |> flow down

viewBook : Remote Book -> Element
viewBook book =
  let titleView = book.title |> fromString |> bold |> leftAligned
      by = " by:" |> fromString |> leftAligned
      header = [titleView, by] |> flow right
      authorView = book.author |> viewWriter
  in [header, authorView] |> flow down

viewWriter : Remote Writer -> Element
viewWriter writer = writer.name |> fromString |> leftAligned
