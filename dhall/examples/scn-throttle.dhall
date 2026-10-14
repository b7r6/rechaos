{- A 60 s object-store throttle over cold inputs (invariants 12 and 13). Needs
   a rig with --cas-backend azure|s3 and the executing timeout disabled. -}
let Step = ../Step.dhall

let Scenario = ../Scenario.dhall

let tools = [ "tool0", "tool1", "tool2", "tool3", "tool4", "tool5" ]

let unique = λ(i : Natural) → "u" ++ Natural/show i

let indexes = Scenario.range 12

in  Scenario.render
      (   Scenario.each Text tools (λ(t : Text) → Step.tool t 400000)
        # Scenario.each
            Natural
            indexes
            (λ(i : Natural) → Step.blob (unique i) 500000)
        # Scenario.each
            Natural
            indexes
            ( λ(i : Natural) →
                Step.action
                  ("a" ++ Natural/show i)
                  (i * 100)
                  1024
                  200
                  (tools # [ unique i ])
            )
        # [ Step.storeThrottle 300 60000 ]
      )
