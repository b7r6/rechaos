{- A Redis-backed scheduler with an Azure CAS behind the fault proxy, as
   `scripts/fleet_rig.py config --backend redis --cas-backend azure --workers 1`
   prints it (the SAS is empty there because no fleet was started). -}
let Rig = ../Rig.dhall

let NativeLink = ../NativeLink.dhall

let rig =
      Rig::{
      , backend = Rig.Backend.Redis
      , workers = 1
      , cas_backend = Rig.CasBackend.Azure { sas_url = "" }
      }

let state = "/tmp/rechaos/fleet"

let ports =
      { port = 50090
      , worker_api_port = 50062
      , redis_port = 6379
      , proxy_port = 0
      }

in  { server = NativeLink.serverConfig rig state ports
    , workers = [ NativeLink.workerConfig rig state ports 0 ]
    }
