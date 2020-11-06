From stdpp Require Import gmap.

Lemma lookup_app_lr {A} (l1 l2 : list A) {i : nat} :
  (l1 ++ l2) !! i = if decide (i < length l1) then l1 !! i else l2 !! (i - length l1).
Proof.
  case_decide.
  - apply lookup_app_l. lia.
  - apply lookup_app_r. lia.
Qed.

Lemma lookup_app_plus {A} (l1 l2 : list A) (i : nat) :
  (l1 ++ l2) !! (length l1 + i) = l2 !! i.
Proof.
  by induction l1.
Qed.

Lemma pigeon `{Countable A} (s : gset A) (xs : list A) :
  (∀ i x, xs !! i = Some x -> x ∈ s) ->
  size s < length xs ->
  ∃ i j a, xs !! i = Some a ∧ xs !! j = Some a ∧ i ≠ j.
Proof.
  revert s. induction xs as [|x xs IH]; simpl; [lia|].
  intros s Hxs Hsize.
  destruct (decide (Exists (x=.) xs)) as [(? & Hx & <-)%Exists_exists|H2].
  - apply elem_of_list_lookup in Hx as [j Hj].
    exists 0,(S j),x.
    eauto with lia.
  - apply not_Exists_Forall in H2; [|solve_decision].
    rewrite Forall_forall in H2. simpl in *.
    assert (x ∈ s).
    { specialize (Hxs 0). naive_solver. }
    assert (∀ i x, xs !! i = Some x -> x ∈ s).
    { intros i x' Hi. specialize (Hxs (S i)). naive_solver.  }
    destruct (IH (s ∖ {[x]})) as (i & j & a & ?).
    * intros i x' Hi.
      apply elem_of_difference. split;[naive_solver|].
      apply not_elem_of_singleton_2. apply not_symmetry.
      apply H2. eapply elem_of_list_lookup_2. done.
    * assert (size s = 1 + size (s ∖ {[x]})); try lia.
      replace 1 with (size ((singleton x) : gset A)); try apply size_singleton.
      replace (size s) with (size ({[x]} ∪ s)); try apply size_union_alt.
      f_equiv. apply subseteq_union_1_L.
      rewrite <-elem_of_subseteq_singleton. done.
    * exists (S i),(S j),a. naive_solver.
Qed.

Lemma lookup_take_Some {A} (xs : list A) (k i : nat) (x : A) :
  take k xs !! i = Some x -> xs !! i = Some x.
Proof.
  revert k i. induction xs; destruct k, i; naive_solver.
Qed.

Lemma lookup_take_Some_iff {A} (xs : list A) (k i : nat) (x : A) :
  take k xs !! i = Some x <-> xs !! i = Some x ∧ i < k.
Proof.
  split.
  - intros. split.
    + apply lookup_take_Some in H. done.
    + apply lookup_lt_Some in H. rewrite take_length in H. lia.
  - intros [].
    rewrite lookup_take; done.
Qed.

Fixpoint insert {T} (i : nat) (x : T) (xs : list T) : list T :=
  match i,xs with
  | 0,xs => x :: xs
  | S i',y :: xs => y :: insert i' x xs
  | S i',[] => []
  end.

Lemma insert_length {T} (i : nat) (x : T) (xs : list T) :
  i ≤ length xs -> length (insert i x xs) = length xs + 1.
Proof.
  revert i. induction xs; intros; destruct i; simpl in *; auto with lia.
Qed.

Lemma in_insert {T} (i : nat) (x a : T) (xs : list T) :
  i ≤ length xs -> (a ∈ insert i x xs <-> a = x ∨ a ∈ xs).
Proof.
  revert i; induction xs; intros; destruct i; simpl in *; rewrite ?elem_of_cons, ?IHxs;
  rewrite ?elem_of_cons; naive_solver lia.
Qed.

Lemma insert_NoDup {T} (i : nat) (x : T) (xs : list T) :
  i ≤ length xs ->
  (x ∉ xs ∧ NoDup xs <-> NoDup (insert i x xs)).
Proof.
  revert i; induction xs; destruct i; simpl; intros;
  rewrite ?list.NoDup_cons; eauto with lia.
  rewrite <-IHxs, in_insert, not_elem_of_cons; naive_solver lia.
Qed.

Lemma insert_out_of_bounds {T} (i : nat) (x : T) (xs : list T) :
  i > length xs -> insert i x xs = xs.
Proof.
  revert i; induction xs; destruct i; simpl; intros; try f_equiv; eauto with lia.
Qed.

Lemma insert_NoDup_2 {T} (i : nat) (x : T) (xs : list T) :
  x ∉ xs -> NoDup xs -> NoDup (insert i x xs).
Proof.
  destruct (decide (i ≤ length xs)).
  - rewrite <-insert_NoDup; eauto with lia.
  - rewrite insert_out_of_bounds; eauto with lia.
Qed.

Lemma insert_delete {T} (i : nat) (x : T) (xs : list T) :
  delete i (insert i x xs) = xs.
Proof.
  revert i; induction xs; destruct i; simpl; try f_equiv; eauto.
Qed.

Lemma delete_insert {T} (i : nat) (x : T) (xs : list T) :
  xs !! i = Some x -> insert i x (delete i xs) = xs.
Proof.
  revert i; induction xs; destruct i; simpl; intros; try f_equiv; naive_solver.
Qed.

Lemma in_delete {A} x i (xs : list A) :
  x ∈ delete i xs -> x ∈ xs.
Proof.
  revert i; induction xs; intros; destruct i; simpl in *;
  eauto; rewrite elem_of_cons; eauto.
  rewrite elem_of_cons in H.
  destruct H; eauto.
Qed.

Lemma NoDup_delete {A} i (xs : list A) :
  NoDup xs -> NoDup (delete i xs).
Proof.
  intro. revert i; induction xs; intros; destruct i; simpl in *; eauto.
  - eapply NoDup_cons_12. done.
  - eapply NoDup_cons_2; eauto using NoDup_cons_12.
    rewrite list.NoDup_cons in H. intro.
    apply in_delete in H0. naive_solver.
Qed.

Lemma take_nonempty {A} (xs : list A) (k : nat) :
  k ≠ 0 -> xs ≠ [] -> take k xs ≠ [].
Proof.
  destruct k, xs; simpl; naive_solver.
Qed.

Lemma drop_nonempty {A} (xs : list A) (i : nat) (a : A) :
  xs !! i = Some a -> drop i xs ≠ [].
Proof.
  revert xs; induction i; destruct xs; simpl; naive_solver.
Qed.

Lemma drop_take_app {A} (xs : list A) n :
  xs = take n xs ++ drop n xs.
Proof.
  revert n; induction xs; simpl; intros.
  - destruct n; simpl; done.
  - destruct n; simpl; try done.
    f_equiv. eauto.
Qed.

Lemma lookup_reverse {A} i (l : list A) :
  i < length l → reverse l !! i = l !! (length l - S i).
Proof.
  revert i. induction l as [|y l IH]; intros i ?; simplify_eq/=; [done|].
  rewrite reverse_cons. destruct (decide (i = length l)) as [->|].
  - by rewrite lookup_app_r, reverse_length, Nat.sub_diag
      by (by rewrite reverse_length).
  - rewrite lookup_app_l, IH by (rewrite ?reverse_length; lia).
    by replace (length l - i) with (S (length l - S i)) by lia.
Qed.

Lemma lookup_reverse_Some {A} i a (l : list A) :
  reverse l !! i = Some a -> l !! (length l - S i) = Some a.
Proof.
  destruct (decide (i < length l)).
  - rewrite lookup_reverse; done.
  - intro. apply lookup_lt_Some in H. rewrite reverse_length in H. lia.
Qed.

Lemma lookup_reverse_Some_iff {A} i a (l : list A) :
  reverse l !! i = Some a <-> l !! (length l - S i) = Some a ∧ i < length l.
Proof.
  destruct (decide (i < length l)).
  - rewrite lookup_reverse;[|done]. naive_solver.
  - split.
    + intro. apply lookup_lt_Some in H. rewrite reverse_length in H. lia.
    + naive_solver lia.
Qed.

Lemma lookup_singleton_Some {A} (a b : A) i :
  [a] !! i = Some b <-> i = 0 ∧ a = b.
Proof.
  destruct i; simpl. naive_solver.
  destruct i; simpl; naive_solver.
Qed.

Lemma lookup_delete_lr {A} (xs : list A) (i j : nat) :
  delete i xs !! j = if decide (j < i) then xs !! j else xs !! (S j).
Proof.
  case_decide.
  - rewrite lookup_delete_lt; done.
  - rewrite lookup_delete_ge. done. lia.
Qed.