{- The bounds the invariants are evaluated against (see docs/scheduler-chaos.md).
   `forRig` derives the executing bound from the scheduler's own timeouts and
   the download budget from the worker's, exactly as Limits.for_rig does. -}
let Rig = ./Rig.dhall

let Limits =
      { queue_age_ms : Natural
      , executing_ms : Natural
      , workers : Natural
      , slots : Natural
      , memory_kb : Natural
      , settle_ms : Natural
      , download_budget_ms : Natural
      }

let forRig
    : Rig.Type → Natural → Limits
    = λ(rig : Rig.Type) →
      λ(queue_age_ms : Natural) →
        { queue_age_ms
        , executing_ms =
              (rig.max_action_executing_timeout_s + rig.worker_timeout_s) * 1000
            + 5000
        , workers = rig.workers
        , slots = rig.slots
        , memory_kb = rig.memory_kb
        , settle_ms = 3000
        , download_budget_ms = rig.max_download_timeout_s * 1000
        }

in  { Type = Limits, forRig }
