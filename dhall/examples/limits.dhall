{- The invariant bounds for a rig, as `Limits.for_rig` in
   scripts/scheduler_steps.py derives them from the same numbers; the step
   contracts compare the two. -}
let Rig = ../Rig.dhall

let Limits = ../Limits.dhall

in  Limits.forRig
      Rig::{
      , workers = 2
      , slots = 1
      , memory_kb = 999
      , worker_timeout_s = 7
      , max_action_executing_timeout_s = 0
      , max_download_timeout_s = 45
      }
      6000
