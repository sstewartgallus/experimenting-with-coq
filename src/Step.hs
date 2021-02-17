module Step where

import qualified Prelude

type EqDec v =
  v -> v -> Prelude.Bool
  -- singleton inductive, whose constructor was Build_EqDec
  
eq_decide :: (EqDec a1) -> a1 -> a1 -> Prelude.Bool
eq_decide eqDec =
  eqDec

data Lambda t =
   Build_Lambda (t -> t -> t) ((t -> t) -> t)

lam :: (Lambda a1) -> (a1 -> a1) -> a1
lam lambda =
  case lambda of {
   Build_Lambda _ lam0 -> lam0}

data Term v =
   Var v
 | Pass (Term v) (Term v)
 | Lam_ (v -> Term v)

term_lambda :: Lambda (Term a1)
term_lambda =
  Build_Lambda (\x x0 -> Pass x x0) (\f -> Lam_ (\x -> f (Var x)))

type Store v = v -> Term v

put :: (EqDec a1) -> (a1 -> Term a1) -> a1 -> (Term a1) -> Store a1
put h old x e x' =
  case eq_decide h x x' of {
   Prelude.True -> e;
   Prelude.False -> old x'}

data Font v =
   Build_font v (Font v) (Font v)

head :: (Font a1) -> a1
head f =
  case f of {
   Build_font head0 _ _ -> head0}

data Stack v =
   Hole
 | Lpass (Stack v) (Term v)

type Heap v = [] ((,) v (Term v))

arbitrary :: Term a1
arbitrary =
  lam term_lambda (\x -> x)

lookup :: (EqDec a1) -> (Heap a1) -> Store a1
lookup h hp =
  case hp of {
   [] -> (\_ -> arbitrary);
   (:) p t -> case p of {
               (,) x' h0 -> put h (lookup h t) x' h0}}

type State v = (,) ((,) (Heap v) (Stack v)) (Term v)

go :: (EqDec a1) -> (Font a1) -> (Heap a1) -> (Stack a1) -> (Term a1) ->
      Prelude.Maybe (State a1)
go h fnt s k e =
  case e of {
   Var x -> Prelude.Just ((,) ((,) s k) (lookup h s x));
   Pass e0 e1 -> Prelude.Just ((,) ((,) s (Lpass k e1)) e0);
   Lam_ f ->
    case k of {
     Hole -> Prelude.Nothing;
     Lpass k' e0 ->
      let {x = head fnt} in
      Prelude.Just ((,) ((,) ((:) ((,) x e0) s) k') (f x))}}

