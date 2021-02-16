Import IfNotations.

Class EqDec {v : Set} := {
  eq_decide (x y : v) : {x = y} + {x <> y}
}.

Section term.
(* I define terms in a parameteric higher order abstract style.
   As we go along variables become a sort of address/pointer.
 *)
Variable v : Set.

Inductive term :=
| var (_ : v)
| pass (_ : term) (_ : term)
| lam (_ : v -> term)
.

Declare Custom Entry lam.
Notation "_{ e }" := e (e custom lam at level 99).
Notation "x" := x (in custom lam at level 0, x constr at level 0).
Notation "f x" := (pass f x) (in custom lam at level 1, left associativity).
Notation "'fun' x => y" :=
  (lam (fun x => y)) (in custom lam at level 90,
                     x ident,
                     y custom lam at level 99,
                     left associativity).
Notation "( x )" := x (in custom lam, x at level 99).
Notation "${ x }" := x (in custom lam, x constr at level 0).

Coercion var : v >-> term.

(* My intuition is that a stack is kind of like a one hole context/evaluation context.
   An alternate representation might be:
 *)
Definition term' := term -> term.

Record ck := { control : term ; kont : term' }. 
Notation " 'E' [ h | e ]" := (h (e : term)) (e custom lam).

(* We use a very simple model of the heap as a function. *)
Definition store := v -> term.

Record model := { model_store : store ; expr : term }.
(*
I used the turnstile before while figuring things out but really this is a store not an environment.
I need to think up better notation/denotation.

fun store => E[kont|control] ?
*)
Notation "s |- ck" := {| model_store := s ; expr := ck |} (at level 70).

Definition put `{EqDec v} old x e : store :=
fun x' => if eq_decide x x' then e else old x'.

Reserved Notation "s0 ~> s1 " (at level 80).

Variant step: model -> model -> Prop := 
| step_var s (x: v) k :
   s |- E[k| x] ~> s |- E[k| ${s x}]

| step_pass s k e0 e1 :
   s |- E[k| e0 e1] ~> s |- E[fun x => _{ ${k x} e1 }| e0]

| step_lam `{EqDec v} s k f x e:
   s |- E[fun x => _{ ${k x} e } | ${lam f}] ~> put s x e |- E[k|${f x}]
where "st ~> st'" := (step st st').

(* FIXME I need to think of a less misleading name, the spec is very weak currently *)
(*
  If an interpreter takes a step (and succeeds!) then that implies that must have been a valid state transition.
*)
Definition valid state to (tick : state -> option state) :=
forall a,
exists b,
tick a = Some b ->
to a ~> to b.

(* We use an old trick of lazily threading through new variables *)
CoInductive font : Set := { head : v ; left : font ; right : font }.

Inductive stack : Set :=
| hole
| lpass (_ : stack) (_ : term).

(* We currently leak memory *)
Definition heap := list (v * term).

Definition arbitrary := _{ fun x => x }.

(* We use a funny style to make proving equivalence easier *)
Fixpoint lookup `{EqDec v} (hp : heap) : store :=
match hp with
| cons (x', h) t => put (lookup t) x' h
| nil => fun _ => arbitrary
end.

Definition state := (heap * stack * term) %type.

Fixpoint go `{EqDec v} (fnt : font) s k e : option state :=
match e with
| var x => Some (s, k, lookup s x)

| _{ e0 e1 } => Some (s, lpass k e1, e0)
| lam f =>
   if k is lpass k' e0
   then
     let x := head fnt in
     go (right fnt) (cons (x, e0) s) k' (f x)
   else None
end.

Definition go' `{EqDec v} fnt st :=
match st with
| (s, k, e) => go fnt s k e
end.

Section applyk.
Variable h : term.
Fixpoint applyk k :=
match k with
| hole => h
| lpass k e => pass (applyk k) e
end.
End applyk.

Definition to_term' k : term' := fun x => applyk x k.
Definition to_store `{EqDec v} (s : heap) : store := lookup s.

Definition models_put `{EqDec v} (h : heap) x e:
put (to_store h) x e = to_store (cons (x, e) h).
induction h.
- trivial.
- trivial.
Qed.

Definition go_to_model `{EqDec v} (st : state) : model :=
match st with
| (s, k , e) => to_store s |- E[to_term' k|e]
end.

Definition go_valid `{EqDec v} fnt : valid _ go_to_model (go' fnt).
intro a.
destruct a, p.
cbn.
(* Perform induction over all possible cases of control, then all cases of the stack *)
induction t.
+ cbn.
  eexists (h, s, _).
  intro.
  eapply (step_var).
+ cbn.
  eexists (h, lpass s t2, t1).
  intro.
  apply (step_pass (to_store h) (to_term' s) t1 t2).
+ cbn.
  induction s.
  * (* I'm not precisely sure why we have to introduce an arbitrary term here but identity works well enough. *)
    eexists (h, hole, arbitrary).
    discriminate.
  * pose (x := head fnt).
    pose (h' := cons (x, t0) h).
    eexists (h', s, t x).
    intro.
    cbn.
    pose (str := to_store h).
    pose (str' := to_store h').
    rewrite -> (models_put h x t0).
    eapply (step_lam str (to_term' s) t x t0).
Qed.

End term.

(* My language of choice is Haskell but a runtime of Ocaml or Scheme might be preferable. Not sure. *)
Require Extraction.

Extraction Language Haskell.
Extract Inductive bool => "Prelude.Bool" ["Prelude.True" "Prelude.False"].
Extract Inductive sumbool => "Prelude.Bool" ["Prelude.True" "Prelude.False"].
Extract Inductive sumor => "Prelude.Maybe" ["Prelude.Just" "Prelude.Nothing"].
Extract Inductive option => "Prelude.Maybe" ["Prelude.Just" "Prelude.Nothing"].
Extract Inductive prod => "(,)" ["(,)"].
Extract Inductive unit => "()" ["()"].
Extract Inductive list => "[]" ["[]" "(:)"].
Extraction "./Step.hs" go.