{- Detached clients while the scheduler's Redis refuses writes, then probes
   (invariants 10 and 9). Needs a Redis-backed rig. -}
let Step = ../Step.dhall

let Scenario = ../Scenario.dhall

in  Scenario.render
      (   Scenario.each
            Natural
            (Scenario.range 6)
            ( λ(i : Natural) →
                Step.detached
                  ("d" ++ Natural/show i)
                  (i * 100)
                  1024
                  3000
                  ([] : List Text)
            )
        # [ Step.storeFull 1200 6000 ]
        # Scenario.each
            Natural
            (Scenario.range 8)
            ( λ(k : Natural) →
                Step.action
                  ("p" ++ Natural/show k)
                  (9000 + k * 20)
                  256
                  200
                  ([] : List Text)
            )
      )
