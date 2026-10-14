{- A scenario is an ordered list of steps. `render` produces the array
   `rechaos minimize --steps`, `rechaos validate-steps`, and
   `scripts/scheduler_steps.py` read. `range n` is `[0, 1, ..., n-1]` and
   `each` maps a constructor over a list, so a stream of actions is one
   expression. No remote imports: the flake check renders these offline. -}
let Step = ./Step.dhall

let range
    : Natural → List Natural
    = λ(n : Natural) →
        Natural/fold
          n
          (List Natural)
          (λ(acc : List Natural) → acc # [ List/length Natural acc ])
          ([] : List Natural)

let each
    : ∀(a : Type) → List a → (a → Step.Type) → List Step.Type
    = λ(a : Type) →
      λ(xs : List a) →
      λ(f : a → Step.Type) →
        List/fold
          a
          xs
          (List Step.Type)
          (λ(x : a) → λ(acc : List Step.Type) → [ f x ] # acc)
          ([] : List Step.Type)

let render
    : List Step.Type → List Step.Wire
    = λ(steps : List Step.Type) →
        List/fold
          Step.Type
          steps
          (List Step.Wire)
          (λ(x : Step.Type) → λ(acc : List Step.Wire) → [ Step.render x ] # acc)
          ([] : List Step.Wire)

in  { Type = List Step.Type, render, range, each }
