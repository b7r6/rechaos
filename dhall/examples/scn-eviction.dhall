{- Shared executable tools plus a unique input per action, staged concurrently
   through a small worker cache (invariant 11). -}
let Step = ../Step.dhall

let Scenario = ../Scenario.dhall

let tools = [ "tool0", "tool1", "tool2", "tool3", "tool4", "tool5" ]

let unique = λ(i : Natural) → "u" ++ Natural/show i

let indexes = Scenario.range 16

in  Scenario.render
      (   Scenario.each Text tools (λ(t : Text) → Step.tool t 400000)
        # Scenario.each
            Natural
            indexes
            (λ(i : Natural) → Step.blob (unique i) 600000)
        # Scenario.each
            Natural
            indexes
            ( λ(i : Natural) →
                Step.action
                  ("a" ++ Natural/show i)
                  (i * 60)
                  1024
                  300
                  (tools # [ unique i ])
            )
      )
