{- A scenario step: the unit the shrinker deletes and weakens. Every variant is
   a closed record, so a scenario cannot name a step kind the engine does not
   know, omit a field it needs, give a count a negative value, or declare a
   shrink floor for a field the kind does not have: those are type errors here,
   not runtime surprises in a trial. That a floor sits at or below its value is
   checked by the readers (`rechaos validate-steps`).

   `render` flattens a step into the engine's wire shape, an object with a
   "step" tag and only the fields that kind carries; `dhall-to-json` omits the
   `None`s. -}
let Op = ./Op.dhall

let Floors = ./Floors.dhall

let Blob =
      { id : Text
      , bytes : Natural
      , executable : Bool
      , weaker : Floors.Blob.Type
      }

let Action =
      { id : Text
      , at_ms : Natural
      , cpu : Natural
      , memory_kb : Natural
      , sleep_ms : Natural
      , inputs : List Text
      , detach : Bool
      , timeout_ms : Optional Natural
      , weaker : Floors.Action.Type
      }

let Window = { at_ms : Natural, for_ms : Natural, weaker : Floors.Window.Type }

let WorkerPause = Window ⩓ { worker : Natural }

let Throttle = Window ⩓ { ops : List Op.Type }

let Step =
      < Blob : Blob
      | Action : Action
      | StoreFull : Window
      | StorePause : Window
      | WorkerPause : WorkerPause
      | StoreThrottle : Throttle
      >

let Wire =
      { step : Text
      , id : Optional Text
      , bytes : Optional Natural
      , executable : Optional Bool
      , at_ms : Optional Natural
      , cpu : Optional Natural
      , memory_kb : Optional Natural
      , sleep_ms : Optional Natural
      , inputs : Optional (List Text)
      , detach : Optional Bool
      , timeout_ms : Optional Natural
      , for_ms : Optional Natural
      , worker : Optional Natural
      , ops : Optional Text
      , weaker : Optional Floors.Wire
      }

let empty =
      { id = None Text
      , bytes = None Natural
      , executable = None Bool
      , at_ms = None Natural
      , cpu = None Natural
      , memory_kb = None Natural
      , sleep_ms = None Natural
      , inputs = None (List Text)
      , detach = None Bool
      , timeout_ms = None Natural
      , for_ms = None Natural
      , worker = None Natural
      , ops = None Text
      , weaker = None Floors.Wire
      }

let window =
      λ(step : Text) →
      λ(w : Window) →
          empty
        ⫽ { step
          , at_ms = Some w.at_ms
          , for_ms = Some w.for_ms
          , weaker = Floors.renderWindow w.weaker
          }

let render
    : Step → Wire
    = λ(s : Step) →
        merge
          { Blob =
              λ(b : Blob) →
                  empty
                ⫽ { step = "blob"
                  , id = Some b.id
                  , bytes = Some b.bytes
                  , executable = Some b.executable
                  , weaker = Floors.renderBlob b.weaker
                  }
          , Action =
              λ(a : Action) →
                  empty
                ⫽ { step = "action"
                  , id = Some a.id
                  , at_ms = Some a.at_ms
                  , cpu = Some a.cpu
                  , memory_kb = Some a.memory_kb
                  , sleep_ms = Some a.sleep_ms
                  , inputs = Some a.inputs
                  , detach = Some a.detach
                  , timeout_ms = a.timeout_ms
                  , weaker = Floors.renderAction a.weaker
                  }
          , StoreFull = window "store-full"
          , StorePause = window "store-pause"
          , WorkerPause =
              λ(w : WorkerPause) →
                window "worker-pause" w.(Window) ⫽ { worker = Some w.worker }
          , StoreThrottle =
              λ(t : Throttle) →
                  window "store-throttle" t.(Window)
                ⫽ { ops = Some (Op.renderList t.ops) }
          }
          s

let blob =
      λ(id : Text) →
      λ(bytes : Natural) →
        Step.Blob
          { id
          , bytes
          , executable = False
          , weaker = Floors.Blob::{ bytes = Some 1 }
          }

let tool =
      λ(id : Text) →
      λ(bytes : Natural) →
        Step.Blob
          { id
          , bytes
          , executable = True
          , weaker = Floors.Blob::{ bytes = Some 1 }
          }

let action =
      λ(id : Text) →
      λ(at_ms : Natural) →
      λ(memory_kb : Natural) →
      λ(sleep_ms : Natural) →
      λ(inputs : List Text) →
        Step.Action
          { id
          , at_ms
          , cpu = 1
          , memory_kb
          , sleep_ms
          , inputs
          , detach = False
          , timeout_ms = None Natural
          , weaker = Floors.Action::{ sleep_ms = Some 0 }
          }

let detached =
      λ(id : Text) →
      λ(at_ms : Natural) →
      λ(memory_kb : Natural) →
      λ(sleep_ms : Natural) →
      λ(inputs : List Text) →
        Step.Action
          { id
          , at_ms
          , cpu = 1
          , memory_kb
          , sleep_ms
          , inputs
          , detach = True
          , timeout_ms = None Natural
          , weaker = Floors.Action::{ sleep_ms = Some 0 }
          }

let pause =
      λ(at_ms : Natural) →
      λ(for_ms : Natural) →
        { at_ms, for_ms, weaker = Floors.Window::{ for_ms = Some 100 } }

in  { Type = Step
    , Blob
    , Action
    , Window
    , WorkerPause
    , Throttle
    , Wire
    , render
    , blob
    , tool
    , action
    , detached
    , storeFull =
        λ(at_ms : Natural) →
        λ(for_ms : Natural) →
          Step.StoreFull (pause at_ms for_ms)
    , storePause =
        λ(at_ms : Natural) →
        λ(for_ms : Natural) →
          Step.StorePause (pause at_ms for_ms)
    , workerPause =
        λ(at_ms : Natural) →
        λ(for_ms : Natural) →
        λ(worker : Natural) →
          Step.WorkerPause (pause at_ms for_ms ⫽ { worker })
    , storeThrottle =
        λ(at_ms : Natural) →
        λ(for_ms : Natural) →
          Step.StoreThrottle (pause at_ms for_ms ⫽ { ops = [ Op.Type.GET ] })
    }
