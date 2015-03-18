module Cache where

import Dict (..)
import Dict
import Signal (..)
import Json.Decode (..)
import Json.Decode as Decode

type alias Cache a = Dict String a

type alias Entry a = Maybe {
  url: String,
  value: a
}

loadCache : (a -> b) -> Signal (Entry a) -> Signal (Cache b)
loadCache transform feed = feed |> foldp (updateCache transform) empty

updateCache : (a -> b) -> Entry a -> Cache b -> Cache b
updateCache transform entry cache =
  case entry of
    Nothing -> cache
    Just { url, value } -> cache |> insert url (value |> transform)

type alias Reference a = {
  url: String,
  lookup: Cache a -> Maybe a
}

reference : Decoder (Reference a)
reference =
  string |> Decode.map (\url ->
    {
      url = url,
      lookup = Dict.get url
    }
  )