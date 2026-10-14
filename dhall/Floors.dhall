{- The shrinker's intensity declaration, one closed record per step kind: which
   of that kind's integer fields may shrink, and the floor each halves toward.
   A floor for a field the kind does not have is a type error. `render*` emit
   the wire form, a `{"field": floor}` object (or nothing when no floor is
   declared), which is what `rechaos minimize --steps` reads. -}
let Entry = { mapKey : Text, mapValue : Natural }

let Wire = List Entry

let Blob = { Type = { bytes : Optional Natural }, default.bytes = None Natural }

let Action =
      { Type =
          { at_ms : Optional Natural
          , cpu : Optional Natural
          , memory_kb : Optional Natural
          , sleep_ms : Optional Natural
          , timeout_ms : Optional Natural
          }
      , default =
        { at_ms = None Natural
        , cpu = None Natural
        , memory_kb = None Natural
        , sleep_ms = None Natural
        , timeout_ms = None Natural
        }
      }

let Window =
      { Type = { at_ms : Optional Natural, for_ms : Optional Natural }
      , default = { at_ms = None Natural, for_ms = None Natural }
      }

let entry =
      λ(name : Text) →
      λ(floor : Optional Natural) →
        merge
          { None = [] : Wire
          , Some = λ(n : Natural) → [ { mapKey = name, mapValue = n } ]
          }
          floor

let nonEmpty =
      λ(entries : Wire) →
        if    Natural/isZero (List/length Entry entries)
        then  None Wire
        else  Some entries

let renderBlob = λ(f : Blob.Type) → nonEmpty (entry "bytes" f.bytes)

let renderAction =
      λ(f : Action.Type) →
        nonEmpty
          (   entry "at_ms" f.at_ms
            # entry "cpu" f.cpu
            # entry "memory_kb" f.memory_kb
            # entry "sleep_ms" f.sleep_ms
            # entry "timeout_ms" f.timeout_ms
          )

let renderWindow =
      λ(f : Window.Type) →
        nonEmpty (entry "at_ms" f.at_ms # entry "for_ms" f.for_ms)

in  { Wire, Blob, Action, Window, renderBlob, renderAction, renderWindow }
