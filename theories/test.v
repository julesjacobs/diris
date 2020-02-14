From iris.proofmode Require Import tactics.

Ltac dorew :=
  match goal with
  | x : _ |- _ => (rewrite x; clear x) || (rewrite -x; clear x)
  end.

Hint Extern 100 => dorew : rewrite.

Definition cnat := forall X, (X -> X) -> X -> X.
Definition zero : cnat := fun _ f x => x.
Definition succ (n : cnat) : cnat := fun _ f x => f (n _ f x).
Definition plus (n m : cnat) : cnat := fun _ f x => n _ f (m _ f x).
Definition mult (n m : cnat) : cnat := fun _ f => n _ (m _ f).
Definition exp (n m : cnat) : cnat := fun _ => m _ (n _).

Definition succ' (n : cnat) : cnat := fun _ f => f ∘ n _ f.
Definition plus' (n m : cnat) : cnat := fun _ f => n _ f ∘ m _ f.

Definition one := succ zero.
Definition two := succ one.
Definition three := succ two.

Example ex1 : plus' zero zero = zero. reflexivity. Qed.
Example ex2 : plus' zero one = one. reflexivity. Qed.
Example ex3 : plus' one zero = one. reflexivity. Qed.
Example ex4 : plus' one one = two. reflexivity. Qed.
Example ex5 : plus' two zero = two. reflexivity. Qed.
Example ex6 : plus' zero two = two. reflexivity. Qed.
Example ex7 : plus' one two = three. reflexivity. Qed.
Example ex8 : plus' two one = three. reflexivity. Qed.

Ltac doind :=
  match goal with
  | x : _ |- _ => induction x; simpl
  end.

Hint Extern 200 => doind : induction.

Lemma foo' (P : nat -> Prop) :
  (forall n, (forall m, m < n -> P m) -> P n) -> (forall n, P n).
Proof.
    eauto with induction lia.
Qed.

Inductive N : Type := Z : N | S : N -> N.

Fixpoint add a b :=
  match a with
  | Z => b
  | S a' => S (add a' b)
  end.

Lemma add_comm : forall a b, add a b = add b a.
Proof.
  eauto 7 with induction rewrite.
Qed.

Lemma add_assoc : forall a b c, add (add a b) c = add a (add b c).
Proof.
  eauto with induction rewrite.
Qed.

Definition t_id := forall t:Type, t -> t.
Definition p1_id f := forall a, forall P : a -> Prop, forall x, P x -> P (f a x).

Lemma all_id (f : t_id) : p1_id f -> forall a x, f a x = x.
Proof.
  unfold p1_id. intros. apply H. auto.
Qed.

Definition cZ : cnat := fun t f z => z.
Definition cS (n : cnat) : cnat := fun t f z => f (n t f z).

Definition p2_nat f g := 
  forall a b, forall R : a -> b -> Prop,
  forall x y s r, R x y -> (forall x' y', R x' y' -> R (s x') (r y')) -> R (f a x s) (g b y r).

Lemma cnat_repr : (forall n:cnat, n cnat cZ cS = n).

Lemma cnat_ind : (forall n:cnat, p2_nat n n) -> forall P : cnat -> Prop, P cZ -> (forall n, P n -> P (cS n)) -> forall n, P n.
Proof.
  unfold p2_nat.
  intros.


Inductive A := fooA : A.
Inductive B := fooB : B.
Inductive C := fooC : C.
Inductive D := fooD : D.

Class R (x : Type) (y : Type) : Type := { foo : nat }.

Check R.

Instance I4 {x y z : Type} (a1 : R x y) (a2 : R y z) : R x z := { foo := 4 }.
Instance I5 (a1 : R A A) : R A D := { foo := 5 }.

Instance I1 : R A B := { foo := 1 }.
Instance I2 : R A C := { foo := 2 }.
Instance I3 : R C D := { foo := 3 }.

Definition bar `{x : R A D} := 2.
Definition baz `{x : R A A} := 3.
Set Typeclasses Iterative Deepening.
Compute bar.

From diris.heap_lang Require Export proofmode notation.
Set Default Proof Using "Type".


Definition lock : val := λ: "x", WAS "x" #false #true.
Definition unlock : val := λ: "x", "x" <- #true.


Lemma lock_spec1 : {{{ True }}} lock  {{{ RET #(); True }}}.
Proof.
Qed.

Lemma lock_spec1 (x:loc) (a:val) : {{{ x ↦ a }}} lock #x {{{ RET #(); x ↦ #true }}}.
Proof.
Qed.