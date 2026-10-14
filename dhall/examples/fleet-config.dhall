{- The configs `scripts/fleet_rig.py config` prints for its defaults, as the
   flake check compares them: three workers, memory scheduler, filesystem CAS,
   fixed state directory and ports. -}
let Rig = ../Rig.dhall

let NativeLink = ../NativeLink.dhall

let rig = Rig::{=}

let state = "/tmp/rechaos/fleet"

let ports =
      { port = 50090
      , worker_api_port = 50062
      , redis_port = 6379
      , proxy_port = 0
      }

in  { server = NativeLink.serverConfig rig state ports
    , workers =
      [ NativeLink.workerConfig rig state ports 0
      , NativeLink.workerConfig rig state ports 1
      , NativeLink.workerConfig rig state ports 2
      ]
    }
