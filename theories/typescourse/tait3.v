From iris.proofmode Require Import tactics.
Ltac inv H := inversion H; clear H; simplify_eq; simpl in *.

Inductive expr :=
  | EUnit : expr
  | EVar : string -> expr
  | ELam : string -> expr -> expr
  | EApp : expr -> expr -> expr
  | EPair : expr -> expr -> expr
  | EProj : bool -> expr -> expr
  | EInj : bool -> expr -> expr
  | EMatch : expr -> expr -> expr -> expr
  | EMatch0 : expr -> expr.

Fixpoint subst e x v :=
  match e with
  | EUnit => EUnit
  | EVar x' => if decide (x = x') then v else EVar x'
  | ELam x' e' =>  (* only works for when v is a value *)
      if decide (x = x') then ELam x' e' else ELam x' (subst e' x v)
  | EApp e1 e2 => EApp (subst e1 x v) (subst e2 x v)
  | EPair e1 e2 => EPair (subst e1 x v) (subst e2 x v)
  | EProj b e' => EProj b (subst e' x v)
  | EInj b e' => EInj b (subst e' x v)
  | EMatch e1 e2 e3 => EMatch (subst e1 x v) (subst e2 x v) (subst e3 x v)
  | EMatch0 e' => EMatch0 (subst e' x v)
  end.

Inductive val : expr -> Prop :=
  | VNat : val EUnit
  | VPair e1 e2 : val e1 -> val e2 -> val (EPair e1 e2)
  | VLam x e : val (ELam x e)
  | VInj e b : val e -> val (EInj b e).

Inductive head_step : expr -> expr -> Prop :=
  | head_step_app x e v :
      val v ->
      head_step (EApp (ELam x e) v) (subst e x v)
  | head_step_proj b v1 v2 :
      val v1 -> val v2 ->
      head_step (EProj b (EPair v1 v2)) (if b then v1 else v2)
  | head_step_match b v e1 e2 :
      val v ->
      head_step (EMatch (EInj b v) e1 e2) (EApp (if b then e1 else e2) v).

Inductive ctx1 : (expr -> expr) -> Prop :=
  | ctx1_app_l e : ctx1 (λ x, EApp x e)
  | ctx1_app_r v : val v -> ctx1 (λ x, EApp v x)
  | ctx1_pair_l e : ctx1 (λ x, EPair x e)
  | ctx1_pair_r v : val v -> ctx1 (λ x, EPair v x)
  | ctx1_proj b : ctx1 (λ x, EProj b x)
  | ctx1_inj b : ctx1 (λ x, EInj b x)
  | ctx1_match e1 e2 : ctx1 (λ x, EMatch x e1 e2)
  | ctx1_match0 : ctx1 (λ x, EMatch0 x).

Inductive ctx : (expr -> expr) -> Prop :=
  | ctx_nil : ctx (λ x, x)
  | ctx_cons k1 k2 : ctx1 k1 -> ctx k2 -> ctx (k1 ∘ k2).

Inductive step : expr -> expr -> Prop :=
  | step_head_step k e e' :
      ctx k -> head_step e e' -> step (k e) (k e').

Inductive ty :=
  | TZero : ty
  | TUnit : ty
  | TFun : ty -> ty -> ty
  | TPair : ty -> ty -> ty
  | TSum : ty -> ty -> ty.

Notation env := (gmap string expr).
Notation envT := (gmap string ty).

Inductive typed : envT -> expr -> ty -> Prop :=
  | typed_unit Γ :
      typed Γ EUnit TUnit
  | typed_var Γ x t :
      Γ !! x = Some t -> typed Γ (EVar x) t
  | typed_lam Γ x t1 t2 e :
      typed (<[ x := t1 ]> Γ) e t2 ->
      typed Γ (ELam x e) (TFun t1 t2)
  | typed_app Γ e1 e2 t1 t2 :
      typed Γ e1 (TFun t1 t2) ->
      typed Γ e2 t1 ->
      typed Γ (EApp e1 e2) t2
  | typed_pair Γ t1 t2 e1 e2 :
      typed Γ e1 t1 ->
      typed Γ e2 t2 ->
      typed Γ (EPair e1 e2) (TPair t1 t2)
  | typed_proj Γ t1 t2 e b :
      typed Γ e (TPair t1 t2) ->
      typed Γ (EProj b e) (if b then t1 else t2)
  | typed_inj Γ t1 t2 e (b : bool) :
      typed Γ e (if b then t1 else t2) ->
      typed Γ (EInj b e) (TSum t1 t2)
  | typed_match Γ e1 e2 e3 t1 t2 t :
      typed Γ e1 (TSum t1 t2) ->
      typed Γ e2 (TFun t1 t) ->
      typed Γ e3 (TFun t2 t) ->
      typed Γ (EMatch e1 e2 e3) t
  | typed_match0 Γ e t :
      typed Γ e TZero ->
      typed Γ (EMatch0 e) t.

Definition steps := rtc step.

Lemma ctx1_ctx k :
  ctx1 k -> ctx k.
Proof.
  intros Hk. apply ctx_cons; first done. constructor.
Qed.

Lemma ctx_comp k1 k2 :
  ctx k1 -> ctx k2 -> ctx (k1 ∘ k2).
Proof.
  induction 1; first done.
  intro. apply (ctx_cons k1); auto.
Qed.

Lemma step_ctx k e e' :
  ctx k -> step e e' -> step (k e) (k e').
Proof.
  intros Hk Hs.
  destruct Hs.
  apply (step_head_step (k ∘ k0));
  first apply ctx_comp; done.
Qed.

Lemma steps_ctx k e e' :
  ctx k -> steps e e' -> steps (k e) (k e').
Proof.
  intros Hk Hs.
  induction Hs; first done.
  eapply rtc_transitive; last done.
  apply rtc_once. apply step_ctx; done.
Qed.

Definition ctx_typed k t1 t2 :=
    ∀ e, typed ∅ e t1 -> typed ∅ (k e) t2.

Lemma ctx_typed_typed k t1 t2 e :
  ctx_typed k t1 t2 -> typed ∅ e t1 -> typed ∅ (k e) t2.
Proof.
  intros Hc Ht. apply Hc. done.
Qed.

Lemma typed_ctx1_typed k e t2 :
  ctx1 k -> typed ∅ (k e) t2 -> ∃ t1, typed ∅ e t1 ∧ ctx_typed k t1 t2.
Proof.
  intros Hc Ht.
  destruct Hc; inv Ht; eexists; split;
  try done; intros ??; econstructor; done.
Qed.

Lemma ctx_typed_comp k k' t1 t2 t3 :
  ctx_typed k t1 t2 -> ctx_typed k' t2 t3 -> ctx_typed (k' ∘ k) t1 t3.
Proof.
  intros Hc Hc' ??. apply Hc'. apply Hc. done.
Qed.

Lemma typed_ctx_typed k e t2 :
  ctx k -> typed ∅ (k e) t2 -> ∃ t1, typed ∅ e t1 ∧ ctx_typed k t1 t2.
Proof.
  intros Hk. revert t2.
  induction Hk; intros t2 Ht.
  - eexists. split; first done. intros ??; done.
  - apply (typed_ctx1_typed k1) in Ht; last done.
    destruct Ht as (t1 & Ht' & Hct').
    edestruct IHHk as (t' & H1 & H2); first done.
    eexists. split; first done.
    eapply ctx_typed_comp; done.
Qed.

Lemma typed_mono Γ e t :
  typed Γ e t -> ∀ Γ', Γ ⊆ Γ' -> typed Γ' e t.
Proof.
  induction 1; intros Γ' Hs; try econstructor;
  eauto using lookup_weaken.
  apply IHtyped. apply insert_mono. done.
Qed.

Lemma empty_subseteq' (Γ : envT) : ∅ ⊆ Γ.
Proof.
  intro. rewrite lookup_empty. destruct (Γ !! i); done.
Qed.

Lemma subst_typed Γ x tv e t v :
  Γ !! x = Some tv -> val v -> typed ∅ v tv ->
  typed Γ e t -> typed (delete x Γ) (subst e x v) t.
Proof.
  intros HΓ Hv Htv Ht.
  induction Ht; simpl; try solve [econstructor; eauto].
  - case_decide.
    + subst. rewrite HΓ in H. simplify_eq.
      eapply typed_mono; first done.
      apply empty_subseteq'.
    + constructor. rewrite lookup_delete_ne; done.
  - case_decide.
    + subst. econstructor. rewrite insert_delete. done.
    + econstructor. rewrite <-delete_insert_ne; last done.
      apply IHHt. rewrite lookup_insert_ne; done.
Qed.

Lemma head_step_typed e e' t :
  typed ∅ e t -> head_step e e' -> typed ∅ e' t.
Proof.
  intros Ht Hs.
  destruct Hs.
  - inv Ht. inv H3.
    replace (∅ : envT) with (delete x (<[x:=t1]> ∅) : envT).
    + eapply subst_typed; try done.
      rewrite lookup_insert. done.
    + rewrite delete_insert; first done.
      apply lookup_empty.
  - inv Ht. inv H5.
    destruct b; done.
  - inv Ht. inv H4. destruct b; econstructor; eauto.
Qed.

Lemma step_typed e e' t :
  typed ∅ e t -> step e e' -> typed ∅ e' t.
Proof.
  intros Ht Hs.
  destruct Hs.
  apply typed_ctx_typed in Ht as (t1 & H1 & H2); last done.
  apply H2. eapply head_step_typed; done.
Qed.

Lemma steps_typed e e' t :
  typed ∅ e t -> steps e e' -> typed ∅ e' t.
Proof.
  intros Ht Hs.
  induction Hs; first done.
  apply IHHs. eapply step_typed; done.
Qed.

Lemma head_step_step e e' :
  head_step e e' -> step e e'.
Proof.
  intros Hs. apply (step_head_step id); last done. constructor.
Qed.

Lemma termination_failed_attempt e t Γ :
  Γ = ∅ -> typed Γ e t -> ∃ e', steps e e' ∧ val e'.
Proof.
  intros HΓ H.
  induction H.
  - eexists. split; first done. constructor.
  - subst. rewrite lookup_empty in H. simplify_eq.
  - eexists. split; first done. constructor.
  - admit. (* impossible with this IH *)
  - destruct IHtyped1 as (v1 & H11 & H12); first done.
    destruct IHtyped2 as (v2 & H21 & H22); first done.
    exists (EPair v1 v2). split.
    + eapply rtc_transitive.
      * apply (steps_ctx (λ x, EPair x e2)); last done.
        apply ctx1_ctx. constructor.
      * apply (steps_ctx (λ x, EPair v1 x)); last done.
        apply ctx1_ctx. constructor. done.
    + constructor; done.
  - destruct IHtyped as (v & H1 & H2); first done. subst.
    eapply steps_typed in H; last done.
    inv H; inv H2. (* canonical forms lemma = inversion on typed and val *)
    exists (if b then e1 else e2).
    split.
    + eapply rtc_transitive.
      * apply (steps_ctx (λ x, EProj b x)); last done.
        apply ctx1_ctx. constructor.
      * apply rtc_once.
        apply head_step_step. constructor; done.
    + destruct b; done.
Admitted. (* Failed attempt *)

Fixpoint HT (e : expr) (t : ty) :=
  match t with
  | TUnit =>
      steps e EUnit
  | TFun t1 t2 =>
      ∃ x e', steps e (ELam x e') ∧
              ∀ v, typed ∅ v t1 -> HT v t1 -> HT (subst e' x v) t2
  | TPair t1 t2 =>
      ∃ e1 e2, steps e (EPair e1 e2) ∧ HT e1 t1 ∧ HT e2 t2
  | TSum t1 t2 =>
      ∃ b e', steps e (EInj b e') ∧ HT e' (if b then t1 else t2)
  | TZero => False
  end.

Definition env_HT (γ : env) (Γ : envT) :=
  ∀ x, match  (Γ !! x),(γ !! x) with
       | Some t, Some v => HT v t ∧ typed ∅ v t
       | None, None => True
       | _, _ => False
       end.

Fixpoint env_subst (γ : env) (e : expr) :=
  match e with
  | EUnit => EUnit
  | EVar x' =>
    match γ !! x' with
    | Some v => v
    | None => EVar x'
    end
  | ELam x' e' => ELam x' (env_subst (delete x' γ) e')
  | EApp e1 e2 => EApp (env_subst γ e1) (env_subst γ e2)
  | EPair e1 e2 => EPair (env_subst γ e1) (env_subst γ e2)
  | EProj b e' => EProj b (env_subst γ e')
  | EInj b e' => EInj b (env_subst γ e')
  | EMatch e1 e2 e3 => EMatch (env_subst γ e1) (env_subst γ e2) (env_subst γ e3)
  | EMatch0 e' => EMatch0 (env_subst γ e')
  end.

Lemma typed_subst_id e t x v Γ :
  Γ !! x = None -> typed Γ e t -> subst e x v = e.
Proof.
  intros Hx Ht.
  induction Ht; intros; simpl; try done; try case_decide;
  simplify_eq; try done;
  rewrite ?IHHt ?IHHt1 ?IHHt2 ?IHHt3; try done.
  rewrite lookup_insert_ne; done.
Qed.

Lemma typed_emp_subst_id x e v t :
  typed ∅ e t -> subst e x v = e.
Proof.
  eapply typed_subst_id. apply lookup_empty.
Qed.

Lemma env_HT_insert x v t1 γ Γ :
  typed ∅ v t1 -> HT v t1 -> env_HT γ Γ -> env_HT (<[x:=v]> γ) (<[x:=t1]> Γ).
Proof.
  intros Ht Hv He y.
  destruct (decide (x = y)).
  - subst. rewrite !lookup_insert; eauto.
  - specialize (He y). rewrite !lookup_insert_ne; done.
Qed.

Lemma env_HT_delete γ Γ x :
  env_HT γ Γ -> env_HT (delete x γ) (delete x Γ).
Proof.
  intros He y.
  destruct (decide (x = y)).
  - subst. rewrite !lookup_delete. done.
  - specialize (He y). rewrite !lookup_delete_ne; done.
Qed.

Lemma subst_env_subst x γ v e Γ :
  γ !! x = None ->
  env_HT γ Γ ->
  subst (env_subst γ e) x v = env_subst (<[ x := v ]> γ) e.
Proof.
  revert γ Γ.
  induction e; intros γ Γ Hx Hvals; simpl in *; eauto;
  try solve [ try erewrite IHe; try erewrite IHe1;
              try erewrite IHe2; try erewrite IHe3; done].
  - destruct (decide (x = s)).
    + subst. rewrite lookup_insert Hx. simpl.
      case_decide; try done.
    + rewrite lookup_insert_ne; last done.
      pose proof (Hvals s).
      destruct (γ !! s) eqn:E; simpl;
      try case_decide; try done.
      destruct (Γ !! s) eqn:F; try done.
      destruct H.
      eapply typed_emp_subst_id; try done.
  - case_decide; subst; f_equal.
    + rewrite delete_insert_delete. done.
    + erewrite IHe.
      * rewrite delete_insert_ne; done.
      * rewrite lookup_delete_ne; eauto.
      * eapply env_HT_delete. done.
Qed.

(* Γ !! x = Some tv -> val v -> typed ∅ v tv ->
typed Γ e t -> typed (delete x Γ) (subst e x v) t. *)

Lemma map_union_delete (A B : envT) x :
  is_Some (A !! x) -> A ∪ B = A ∪ (delete x B).
Proof.
  intros Hs.
  apply map_eq. intros i.
  rewrite !lookup_union.
  destruct (decide (i = x)).
  - subst. destruct Hs. rewrite H. simpl. rewrite lookup_delete. simpl.
    destruct (B !! x); simpl; done.
  - rewrite lookup_delete_ne; eauto.
Qed.

Lemma map_union_insert' (A B : envT) x v :
  <[x:=v]> (A ∪ B) = <[x:=v]> A ∪ delete x B.
Proof.
  rewrite insert_union_l.
  rewrite <- map_union_delete; first done.
  rewrite lookup_insert. eauto.
Qed.

Lemma disjoint_move (A B : envT) x v :
  A ##ₘ B -> delete x A ##ₘ <[x:=v]> B.
Proof.
  intros H y.
  destruct (decide (x = y)).
  - subst. rewrite lookup_delete. simpl. rewrite lookup_insert. done.
  - rewrite lookup_delete_ne; last done.
    rewrite lookup_insert_ne; last done. done.
Qed.

Lemma env_subst_typed Γ Γ' γ e t :
  Γ' ##ₘ Γ -> typed (Γ ∪ Γ') e t -> env_HT γ Γ' -> typed Γ (env_subst γ e) t.
Proof.
  remember (Γ ∪ Γ') as g.
  intros Hdisj Ht. revert γ Γ' Γ Hdisj Heqg.
  induction Ht; intros; simpl in *; try solve [econstructor;eauto]; simplify_eq.
  - specialize (H0 x).
    destruct (Γ' !! x) eqn:E; destruct (γ !! x) eqn:F; simplify_eq; try done.
    + simplify_map_eq. destruct H0.
      eapply typed_mono; first done.
      apply empty_subseteq'.
    + constructor. apply lookup_union_Some in H; naive_solver.
  - constructor. eapply IHHt; eauto using env_HT_delete.
    + apply disjoint_move. done.
    + apply map_union_insert'.
Qed.

Lemma HT_steps_rev e' e t :
  steps e e' -> HT e' t -> HT e t.
Proof.
  intros Hs Ht.
  induction t; simpl in *; try done.
  - eapply rtc_transitive; done.
  - destruct Ht as (x & e1 & ? & ?).
    repeat eexists.
    + eapply rtc_transitive; done.
    + eauto.
  - destruct Ht as (e1 & e2 & ? & ? & ?).
    repeat eexists.
    + eapply rtc_transitive; done.
    + eauto.
    + eauto.
  - destruct Ht as (b & e1 & ? & ?).
    exists b. repeat eexists; eauto.
    eapply rtc_transitive; done.
Qed.

Lemma HT_val e t :
  HT e t -> ∃ v, steps e v ∧ val v ∧ HT v t.
Proof.
  revert e. induction t; intros e; simpl; try done.
  - intros ?. repeat eexists; first done.
    constructor. reflexivity.
  - intros (? & ? & ? & ?).
    repeat eexists; try done.
    constructor.
  - intros (? & ? & ? & ? & ?).
    edestruct IHt1 as (v1 & ? & ? & ?); try done.
    edestruct IHt2 as (v2 & ? & ? & ?); try done.
    exists (EPair v1 v2).
    repeat eexists; try done.
    + eapply rtc_transitive; first done.
      eapply (rtc_transitive _ (EPair v1 x0)).
      { apply (steps_ctx (λ x, EPair x _)); last done.
        apply ctx1_ctx. constructor. }
      apply (steps_ctx (λ x, EPair _ x)); last done.
      apply ctx1_ctx. constructor. done.
    + constructor; done.
  - intros (b & ? & ? & ?).
    destruct b.
    + edestruct IHt1 as (v1 & ? & ? & ?); try done; try done.
      exists (EInj true v1).
      repeat eexists; try done.
      * eapply rtc_transitive; first done.
        apply (steps_ctx (λ x, EInj _ x)); last done.
        apply ctx1_ctx. constructor.
      * constructor; done.
    + edestruct IHt2 as (v2 & ? & ? & ?); try done; try done.
      exists (EInj false v2).
      repeat eexists; try done.
      * eapply rtc_transitive; first done.
        apply (steps_ctx (λ x, EInj _ x)); last done.
        apply ctx1_ctx. constructor.
      * constructor; done.
Qed.

(*
  For env_HT γ Γ we need to have:
  - if Γ !! x = Some t then γ !! x = Some v and HT v t
  - subst (env_subst (delete x γ) e) x v
               =
      env_subst (<[x:=v]> γ) e
  - we need to be able to insert into γ
*)

Definition judg_HT Γ e t :=
  ∀ γ, env_HT γ Γ -> HT (env_subst γ e) t.

Lemma HT_app e1 e2 t1 t2 :
  typed ∅ e2 t1 ->
  HT e1 (TFun t1 t2) ->
  HT e2 t1 ->
  HT (EApp e1 e2) t2.
Proof.
  intros Htyped IHtyped1 IHtyped2.
  simpl in *.
  destruct IHtyped1 as (x & e' & ? & ?).
  eapply HT_steps_rev.
  { apply (steps_ctx (λ x, EApp x _)); last done.
    apply ctx1_ctx. constructor. }
  apply HT_val in IHtyped2.
  destruct IHtyped2 as (v & Hst & Hv & Hv').
  eapply HT_steps_rev.
  { apply (steps_ctx (λ x, EApp _ x)); last done.
    apply ctx1_ctx. constructor. constructor. }
  apply (HT_steps_rev (subst e' x v)).
  { apply rtc_once. eapply (step_head_step id); first by constructor.
    fold subst. constructor. done. }
  eapply H0; eauto.
  eapply steps_typed; done.
Qed.

Lemma main Γ e t : typed Γ e t -> judg_HT Γ e t.
Proof.
  induction 1; intros γ Hγ; simpl in *.
  - reflexivity.
  - specialize (Hγ x). rewrite H in Hγ.
    destruct (γ !! x) eqn:E; naive_solver.
  - do 2 eexists. split; first done.
    intros v Hvt Hv.
    assert (HT (env_subst (<[x:=v]> γ) e) t2).
    { apply IHtyped. apply env_HT_insert; try done. }
    assert ((subst (env_subst (delete x γ) e) x v) =
            (env_subst (<[x:=v]> γ) e)).
    { erewrite subst_env_subst; eauto using env_HT_delete.
      - rewrite insert_delete. done.
      - rewrite lookup_delete. done. }
    rewrite H1. done.
  - specialize (IHtyped1 γ Hγ).
    specialize (IHtyped2 γ Hγ).
    eapply HT_app; eauto.
    eapply env_subst_typed; eauto.
    + solve_map_disjoint.
    + rewrite left_id. done.
  - specialize (IHtyped1 γ Hγ).
    specialize (IHtyped2 γ Hγ).
    do 2 eexists.
    split; first by reflexivity.
    split; done.
  - specialize (IHtyped γ Hγ).
    simpl in *.
    destruct IHtyped as (e1 & e2 & Hs & Ht1 & Ht2).
    eapply HT_steps_rev.
    { apply (steps_ctx (λ x, EProj b x)); last done.
      apply ctx1_ctx. constructor. }
    apply HT_val in Ht1 as (v & Hs1 & Hv1 & Ht1).
    apply HT_val in Ht2 as (v' & Hs1' & Hv1' & Ht1').
    eapply HT_steps_rev.
    { apply (steps_ctx (λ x, EProj b (EPair x _))); last done.
      apply ctx_cons. constructor. apply ctx1_ctx. constructor. }
    eapply HT_steps_rev.
    { apply (steps_ctx (λ x, EProj b (EPair _ x))); last done.
      apply ctx_cons. constructor. apply ctx1_ctx. constructor. done. }
    apply (HT_steps_rev (if b then v else v')).
    { apply rtc_once. eapply (step_head_step id); first by constructor.
      constructor; done. }
    destruct b; done.
  - specialize (IHtyped γ Hγ).
    exists b. repeat eexists; eauto.
    reflexivity.
  - specialize (IHtyped1 γ Hγ).
    specialize (IHtyped2 γ Hγ).
    specialize (IHtyped3 γ Hγ).
    simpl in *.
    destruct IHtyped1 as (? & ? & ? & ?).
    destruct IHtyped2 as (? & ? & ? & ?).
    destruct IHtyped3 as (? & ? & ? & ?).
    eapply HT_steps_rev.
    { apply (steps_ctx (λ x, EMatch x _ _)); last done.
      apply ctx1_ctx. constructor. }
    apply HT_val in H3 as (v & Hs1 & Hv1 & Ht1).
    eapply (HT_steps_rev (EMatch (EInj x v) (env_subst γ e2) (env_subst γ e3))).
    { apply (steps_ctx (λ x, EMatch (EInj _ x) _ _)); last done.
      eapply (ctx_cons (λ x, EMatch x _ _)).
      constructor. apply ctx1_ctx. constructor. }
    apply (HT_steps_rev (EApp (if x then (env_subst γ e2) else (env_subst γ e3)) v)).
    { apply rtc_once. eapply (step_head_step id); first by constructor.
      constructor. done. }
    eapply HT_app; eauto.
    + assert (typed ∅ (env_subst γ e1) (TSum t1 t2)) as Htyped.
      { eapply env_subst_typed; eauto; [solve_map_disjoint|by rewrite left_id]. }
      eapply steps_typed in H2; eauto.
      inv H2.
      eapply steps_typed in Hs1; eauto.
    + destruct x; simpl; eauto.
  - specialize (IHtyped γ Hγ). simpl in *. done.
Qed.

Lemma env_HT_empty : env_HT ∅ ∅.
Proof.
  intro. rewrite !lookup_empty. done.
Qed.

Lemma env_subst_empty e :
  env_subst ∅ e = e.
Proof.
  induction e; simpl; rewrite ?delete_empty ?IHe ?IHe1 ?IHe2 ?IHe3; try done.
Qed.

Theorem termination e t : typed ∅ e t -> ∃ e', steps e e' ∧ val e'.
Proof.
  intros Ht.
  apply main in Ht.
  specialize (Ht ∅ env_HT_empty).
  apply HT_val in Ht as (? & ? & ? & ?).
  rewrite env_subst_empty in H.
  eauto.
Qed.

Lemma head_step_deterministic e e1 e2 :
  head_step e e1 -> head_step e e2 -> e1 = e2.
Proof.
  intros H1 H2. destruct H1; inv H2; done.
Qed.

Definition head_reducible e := ∃ e', head_step e e'.

Lemma head_reducible_ctx1_val k e :
  ctx1 k -> head_reducible (k e) -> val e.
Proof.
  intros Hk H. destruct H. destruct Hk; inv H; eauto; constructor; eauto.
Qed.

Lemma ctx_val k e :
  ctx k -> val (k e) -> val e.
Proof.
  intros Hc Hv.
  induction Hc; eauto.
  destruct H; simpl in *; inv Hv; eauto.
Qed.

Lemma head_reducible_ctx_val k e :
  ctx k -> head_reducible (k e) -> val e ∨ k = (λ x, x).
Proof.
  intros Hk H. destruct Hk; eauto.
  simpl in *. apply head_reducible_ctx1_val in H; eauto.
  apply ctx_val in H; eauto.
Qed.

Lemma head_reducible_not_val e :
  head_reducible e -> val e -> False.
Proof.
  intros [] H2. destruct H; inv H2.
Qed.

Lemma ctx_headstep_deterministic k1 e1 k2 e2 : ctx k1 -> ctx k2 ->
  k1 e1 = k2 e2 ->
  head_reducible e1 ->
  head_reducible e2 ->
  k1 = k2 ∧ e1 = e2.
Proof.
  intros C1.
  revert k2 e1 e2.
  induction C1 as [|C1' k1']; intros k2 e1 e2 C2 Heq Hr1 Hr2; subst.
  - apply head_reducible_ctx_val in Hr1; eauto.
    destruct Hr1.
    + apply head_reducible_not_val in Hr2; done.
    + subst. eauto.
  - destruct C2 as [|C2' k2']; subst.
    + apply head_reducible_ctx_val in Hr2; last by constructor.
      destruct Hr2.
      * apply head_reducible_not_val in H0; done.
      * rewrite H0. eauto.
    + inv H; inv H0; try solve [edestruct IHC1; eauto; subst; done];
      exfalso; eauto using head_reducible_not_val, ctx_val.
Qed.

Lemma head_step_not_val v e :
  head_step v e -> val v -> False.
Proof.
  intros Hs Hv. destruct Hv; inv Hs.
Qed.

Lemma step_not_val v e :
  step v e -> val v -> False.
Proof.
  intros Hs Hv. destruct Hs.
  apply ctx_val in Hv; eauto.
  eapply head_step_not_val; eauto.
Qed.

Lemma steps_val v e :
  val v -> steps v e -> v = e.
Proof.
  intros Hv. induction 1; eauto.
  exfalso. eapply step_not_val; eauto.
Qed.

Lemma step_deterministic e e1 e2 :
  step e e1 -> step e e2 -> e1 = e2.
Proof.
  intros H1 H2.
  inv H1. inv H2.
  eapply ctx_headstep_deterministic in H1;
  try unfold head_reducible; eauto.
  destruct H1. subst. f_equal.
  eapply head_step_deterministic; eauto.
Qed.

Lemma steps_deterministic e e1 e2 :
  steps e e1 -> steps e e2 ->
  val e1 -> val e2 -> e1 = e2.
Proof.
  intros H1 H2 Hv1 Hv2.
  induction H1.
  - apply steps_val; eauto.
  - apply IHrtc; eauto.
    destruct H2; eauto.
    + exfalso. eapply step_not_val; eauto.
    + assert (y = y0) as ->; eauto using step_deterministic.
Qed.