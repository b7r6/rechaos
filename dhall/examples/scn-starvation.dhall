{- A large action behind a saturating stream of small ones (invariant 8). -}
let Step = ../Step.dhall

let Scenario = ../Scenario.dhall

let small =
      λ(i : Natural) →
        Step.action ("s" ++ Natural/show i) (i * 250) 2048 2000 ([] : List Text)

in  Scenario.render
      (   Scenario.each Natural (Scenario.range 48) small
        # [ Step.action "L" 3000 16384 500 ([] : List Text) ]
      )
