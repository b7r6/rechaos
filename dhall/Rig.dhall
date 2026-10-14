{- Fleet rig parameters: the typed form of the shape knobs in
   scripts/fleet_rig.py's Params, with the same defaults, so a rig is
   `Rig::{ workers = 3 }` and every other knob is the documented default; a knob
   the rig does not have is a type error. Launch mechanics (which ports were
   free, which binaries, the proxy seed, an external S3 endpoint) are not rig
   shape: the NativeLink config functions take the resolved listeners as
   `NativeLink.Ports`, and the object-store account and container are fixed
   by the rig (Azurite's development account, bucket `cas`). -}
let Backend = < Memory | Redis >

let CasBackend =
      < Filesystem | Azure : { sas_url : Text } | S3 : { bucket : Text } >

let Rig =
      { backend : Backend
      , workers : Natural
      , slots : Natural
      , memory_kb : Natural
      , worker_cache_bytes : Natural
      , cas_bytes : Natural
      , worker_timeout_s : Natural
      , max_action_executing_timeout_s : Natural
      , client_action_timeout_s : Natural
      , retain_completed_for_s : Natural
      , max_job_retries : Natural
      , max_inflight_tasks : Natural
      , reservation_hold_after_s : Natural
      , max_download_timeout_s : Natural
      , cas_backend : CasBackend
      , cas_fast_bytes : Natural
      , store_retries : Natural
      , store_retry_delay : Double
      , store_retry_jitter : Double
      , instance : Text
      }

let default
    : Rig
    = { backend = Backend.Memory
      , workers = 3
      , slots = 4
      , memory_kb = 20480
      , worker_cache_bytes = 200000000
      , cas_bytes = 2000000000
      , worker_timeout_s = 10
      , max_action_executing_timeout_s = 20
      , client_action_timeout_s = 30
      , retain_completed_for_s = 10
      , max_job_retries = 3
      , max_inflight_tasks = 0
      , reservation_hold_after_s = 0
      , max_download_timeout_s = 600
      , cas_backend = CasBackend.Filesystem
      , cas_fast_bytes = 1000000
      , store_retries = 6
      , store_retry_delay = 0.3
      , store_retry_jitter = 0.5
      , instance = "main"
      }

in  { Type = Rig, default, Backend, CasBackend }
