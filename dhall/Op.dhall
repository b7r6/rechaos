{- The object-store operations a throttle can target: exactly the vocabulary
   the fault proxy's control endpoint accepts. The wire form is the proxy's
   comma-separated list. -}
let Op = < GET | PUT | DELETE | HEAD | LIST >

let render =
      λ(op : Op) →
        merge
          { GET = "GET"
          , PUT = "PUT"
          , DELETE = "DELETE"
          , HEAD = "HEAD"
          , LIST = "LIST"
          }
          op

let renderList =
      λ(ops : List Op) →
        merge
          { None = "", Some = λ(joined : Text) → joined }
          ( List/fold
              Op
              ops
              (Optional Text)
              ( λ(op : Op) →
                λ(acc : Optional Text) →
                  merge
                    { None = Some (render op)
                    , Some = λ(rest : Text) → Some (render op ++ "," ++ rest)
                    }
                    acc
              )
              (None Text)
          )

in  { Type = Op, render, renderList }
