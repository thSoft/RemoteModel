module Cache where

import Dict (..)
import Signal (..)
import Maybe (..)
import Maybe

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

findAndMap : (a -> b) -> b -> Cache a -> String -> b
findAndMap transform default cache url = cache |> get url |> Maybe.map transform |> withDefault default