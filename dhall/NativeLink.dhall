{- The NativeLink scheduler and worker configurations a fleet rig runs, as
   total functions of the rig parameters. These mirror server_config and
   worker_config in scripts/fleet_rig.py field for field; the flake check
   renders both and diffs them, so the Python emitter cannot drift from the
   typed definition. JSON5 is a superset of the JSON these render to.

   `Ports` are the listeners resolved at launch (the fault proxy's among them);
   `state` is the run's state directory, which must be a normalized absolute
   path, since the Python emitter normalizes it and this file concatenates. -}
let Rig = ./Rig.dhall

let Ports =
      { port : Natural
      , worker_api_port : Natural
      , redis_port : Natural
      , proxy_port : Natural
      }

let azuriteAccount = "devstoreaccount1"

let azuriteContainer = "cas"

let Eviction = { max_bytes : Natural }

let Filesystem =
      { content_path : Text, temp_path : Text, eviction_policy : Eviction }

let filesystem =
      λ(dir : Text) →
      λ(max_bytes : Natural) →
        { content_path = dir ++ "/content-cas"
        , temp_path = dir ++ "/tmp-cas"
        , eviction_policy.max_bytes = max_bytes
        }

let Retry = { max_retries : Natural, delay : Double, jitter : Double }

let retry =
      λ(rig : Rig.Type) →
        { max_retries = rig.store_retries
        , delay = rig.store_retry_delay
        , jitter = rig.store_retry_jitter
        }

let -- The CAS slow tier for an object-store backend, keyed by provider.
    ObjectStore =
      { provider : Text
      , account_name : Optional Text
      , container : Optional Text
      , sas_url : Optional Text
      , region : Optional Text
      , bucket : Optional Text
      , endpoint : Optional Text
      , force_path_style : Optional Bool
      , retry : Retry
      , insecure_allow_http : Bool
      }

let objectStore
    : Rig.Type → Ports → Optional ObjectStore
    = λ(rig : Rig.Type) →
      λ(ports : Ports) →
        merge
          { Filesystem = None ObjectStore
          , Azure =
              λ(a : { sas_url : Text }) →
                Some
                  { provider = "azure"
                  , account_name = Some azuriteAccount
                  , container = Some azuriteContainer
                  , sas_url = Some a.sas_url
                  , region = None Text
                  , bucket = None Text
                  , endpoint = None Text
                  , force_path_style = None Bool
                  , retry = retry rig
                  , insecure_allow_http = True
                  }
          , S3 =
              λ(s : { bucket : Text }) →
                Some
                  { provider = "aws"
                  , account_name = None Text
                  , container = None Text
                  , sas_url = None Text
                  , region = Some "us-east-1"
                  , bucket = Some s.bucket
                  , endpoint = Some
                      ("http://127.0.0.1:" ++ Natural/show ports.proxy_port)
                  , force_path_style = Some True
                  , retry = retry rig
                  , insecure_allow_http = True
                  }
          }
          rig.cas_backend

let CasStore =
      { name : Text
      , filesystem : Optional Filesystem
      , fast_slow :
          Optional
            { fast : { filesystem : Filesystem }
            , slow : { experimental_cloud_object_store : ObjectStore }
            }
      , redis_store :
          Optional
            { addresses : List Text
            , mode : Text
            , experimental_pub_sub_channel : Text
            }
      }

let store =
      { filesystem = None Filesystem
      , fast_slow =
          None
            { fast : { filesystem : Filesystem }
            , slow : { experimental_cloud_object_store : ObjectStore }
            }
      , redis_store =
          None
            { addresses : List Text
            , mode : Text
            , experimental_pub_sub_channel : Text
            }
      }

let casStore
    : Rig.Type → Text → Ports → CasStore
    = λ(rig : Rig.Type) →
      λ(state : Text) →
      λ(ports : Ports) →
        merge
          { None =
                store
              ⫽ { name = "CAS_MAIN_STORE"
                , filesystem = Some
                    (filesystem (state ++ "/server") rig.cas_bytes)
                }
          , Some =
              λ(slow : ObjectStore) →
                  store
                ⫽ { name = "CAS_MAIN_STORE"
                  , fast_slow = Some
                    { fast.filesystem
                      = filesystem (state ++ "/server") rig.cas_fast_bytes
                    , slow.experimental_cloud_object_store = slow
                    }
                  }
          }
          (objectStore rig ports)

let acStore =
      λ(state : Text) →
          store
        ⫽ { name = "AC_MAIN_STORE"
          , filesystem = Some
            { content_path = state ++ "/server/content-ac"
            , temp_path = state ++ "/server/tmp-ac"
            , eviction_policy.max_bytes = 200000000
            }
          }

let redisStore =
      λ(redis_port : Natural) →
          store
        ⫽ { name = "SCHEDULER_REDIS_STORE"
          , redis_store = Some
            { addresses =
              [ "redis://127.0.0.1:" ++ Natural/show redis_port ++ "/" ]
            , mode = "standard"
            , experimental_pub_sub_channel = "rechaos_scheduler_key_change"
            }
          }

let Backend = < Memory : Text | Redis : { redis : { redis_store : Text } } >

let Simple =
      { supported_platform_properties :
          { cpu_count : Text
          , memory_kb : Text
          , OSFamily : Text
          , container-image : Text
          , cpu_arch : Text
          }
      , worker_timeout_s : Natural
      , max_action_executing_timeout_s : Natural
      , client_action_timeout_s : Natural
      , retain_completed_for_s : Natural
      , max_job_retries : Natural
      , experimental_backend : Backend
      , reservation_hold : Optional { hold_after_s : Natural }
      }

let simple
    : Rig.Type → Simple
    = λ(rig : Rig.Type) →
        { supported_platform_properties =
          { cpu_count = "minimum"
          , memory_kb = "minimum"
          , OSFamily = "priority"
          , container-image = "priority"
          , cpu_arch = "priority"
          }
        , worker_timeout_s = rig.worker_timeout_s
        , max_action_executing_timeout_s = rig.max_action_executing_timeout_s
        , client_action_timeout_s = rig.client_action_timeout_s
        , retain_completed_for_s = rig.retain_completed_for_s
        , max_job_retries = rig.max_job_retries
        , experimental_backend =
            merge
              { Memory = Backend.Memory "memory"
              , Redis =
                  Backend.Redis { redis.redis_store = "SCHEDULER_REDIS_STORE" }
              }
              rig.backend
        , reservation_hold =
            if    Natural/isZero rig.reservation_hold_after_s
            then  None { hold_after_s : Natural }
            else  Some { hold_after_s = rig.reservation_hold_after_s }
        }

let server
    : Rig.Type → Text → Ports → CasStore → List CasStore
    = λ(rig : Rig.Type) →
      λ(state : Text) →
      λ(ports : Ports) →
      λ(cas : CasStore) →
          [ cas, acStore state ]
        # merge
            { Memory = [] : List CasStore
            , Redis = [ redisStore ports.redis_port ]
            }
            rig.backend

let serverConfig =
      λ(rig : Rig.Type) →
      λ(state : Text) →
      λ(ports : Ports) →
        let inst = rig.instance

        in  { stores = server rig state ports (casStore rig state ports)
            , schedulers = [ { name = "MAIN_SCHEDULER", simple = simple rig } ]
            , servers =
              [ { name = "public"
                , listener.http.socket_address
                  = "127.0.0.1:" ++ Natural/show ports.port
                , services =
                  { cas = Some
                    [ { instance_name = inst, cas_store = "CAS_MAIN_STORE" } ]
                  , ac = Some
                    [ { instance_name = inst, ac_store = "AC_MAIN_STORE" } ]
                  , bytestream = Some
                    [ { instance_name = inst, cas_store = "CAS_MAIN_STORE" } ]
                  , execution = Some
                    [ { instance_name = inst
                      , cas_store = "CAS_MAIN_STORE"
                      , scheduler = "MAIN_SCHEDULER"
                      }
                    ]
                  , capabilities = Some
                    [ { instance_name = inst
                      , remote_execution.scheduler = "MAIN_SCHEDULER"
                      }
                    ]
                  , health = Some { path = Some "/status" }
                  , worker_api = None { scheduler : Text }
                  }
                }
              , { name = "worker_api"
                , listener.http.socket_address
                  = "127.0.0.1:" ++ Natural/show ports.worker_api_port
                , services =
                  { cas = None (List { instance_name : Text, cas_store : Text })
                  , ac = None (List { instance_name : Text, ac_store : Text })
                  , bytestream =
                      None (List { instance_name : Text, cas_store : Text })
                  , execution =
                      None
                        ( List
                            { instance_name : Text
                            , cas_store : Text
                            , scheduler : Text
                            }
                        )
                  , capabilities =
                      None
                        ( List
                            { instance_name : Text
                            , remote_execution : { scheduler : Text }
                            }
                        )
                  , health = Some { path = None Text }
                  , worker_api = Some { scheduler = "MAIN_SCHEDULER" }
                  }
                }
              ]
            , global.max_open_files = 4096
            }

let Grpc =
      { instance_name : Text
      , endpoints : List { address : Text }
      , store_type : Text
      }

let WorkerFastSlow =
      { fast : { filesystem : Filesystem }
      , slow : { ref_store : { name : Text } }
      }

let WorkerStore =
      { name : Text, grpc : Optional Grpc, fast_slow : Optional WorkerFastSlow }

let grpcStore =
      λ(rig : Rig.Type) →
      λ(ports : Ports) →
      λ(name : Text) →
      λ(kind : Text) →
        { name
        , grpc = Some
          { instance_name = rig.instance
          , endpoints =
            [ { address = "grpc://127.0.0.1:" ++ Natural/show ports.port } ]
          , store_type = kind
          }
        , fast_slow = None WorkerFastSlow
        }

let workerConfig =
      λ(rig : Rig.Type) →
      λ(state : Text) →
      λ(ports : Ports) →
      λ(index : Natural) →
        let wdir = state ++ "/worker-" ++ Natural/show index

        in  { stores =
                  [ grpcStore rig ports "GRPC_CAS" "cas"
                  , grpcStore rig ports "GRPC_AC" "ac"
                  , { name = "WORKER_FAST_SLOW_STORE"
                    , grpc = None Grpc
                    , fast_slow = Some
                      { fast.filesystem = filesystem wdir rig.worker_cache_bytes
                      , slow.ref_store.name = "GRPC_CAS"
                      }
                    }
                  ]
                : List WorkerStore
            , workers =
              [ { local =
                  { name = "w" ++ Natural/show index
                  , worker_api_endpoint.uri
                    = "grpc://127.0.0.1:" ++ Natural/show ports.worker_api_port
                  , cas_fast_slow_store = "WORKER_FAST_SLOW_STORE"
                  , upload_action_result.ac_store = "GRPC_AC"
                  , work_directory = wdir ++ "/work"
                  , platform_properties =
                    { cpu_count.values = [ Natural/show rig.slots ]
                    , memory_kb.values = [ Natural/show rig.memory_kb ]
                    , OSFamily.values = [ "linux", "" ]
                    , container-image.values = [ "" ]
                    , cpu_arch.values = [ "x86_64", "" ]
                    }
                  , max_inflight_tasks =
                      if    Natural/isZero rig.max_inflight_tasks
                      then  None Natural
                      else  Some rig.max_inflight_tasks
                  , max_download_timeout_s = rig.max_download_timeout_s
                  }
                }
              ]
            , servers = [] : List {}
            , global.max_open_files = 4096
            }

in  { Ports, serverConfig, workerConfig }
