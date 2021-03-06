(* Dhruv Makwana *)
(* LT4LA Check Monad *)
(* ----------------- *)
(* This is a wrapper arround the monad defined in state_or_error.mli.
   This is so that (1) I don't have arbitrary access to the state during
   typechecking and (2) I can enforce invariants such as only marking those
   linear variables which have been found and not used as used in [use_var]
   or enforcing that all types are well-formed (3) I can change how the monad
   and how the state are implemented independently. Right now, (almost)
   everything is pure functional. *)

(** Proof that types is well-formed.
    Private so you can pattern match and extract but not fake proof. *)
type well_formed = private WF of Ast.linear_t

val sexp_of_well_formed : well_formed -> Base.Sexp.t

val wf_Array_t_Zero : well_formed
val wf_Unit         : well_formed
val wf_Int          : well_formed
val wf_Float64      : well_formed
val wf_Pair         : well_formed -> well_formed -> well_formed
val wf_Fun          : well_formed -> well_formed -> well_formed
val wf_ForAll       : Ast.variable -> well_formed -> well_formed

(** Proof that a type is not used *)
type not_used

val sexp_of_not_used : not_used -> Base.Sexp.t

(** Track usage of linear types *)
type tagged_linear_t = Not_used of not_used | Used of well_formed

val sexp_of_tagged_linear_t : tagged_linear_t -> Base.Sexp.t

(** The theory has two (eventually three) sorts: variables can map to either
    - Linear Types, with an 'a (e.g. usage)
    - Fractional capabilities
    - Sizes/dimensions or arrays and matrices *)
type state

val sexp_of_state : state -> Base.Sexp.t

(** Sequence computations based on a given state. *)
type 'a t

val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

module Monad_infix : sig

  val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

  val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

end

val bind : 'a t -> f:('a -> 'b t) -> 'b t

val return : 'a -> 'a t

val map : 'a t -> f:('a -> 'b) -> 'b t

val join : 'a t t -> 'a t

val ignore_m : 'a t -> unit t

val all : 'a t list -> 'a list t

val all_unit : unit t list -> unit t

module Let_syntax : sig

  val return : 'a -> 'a t

  val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

  val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

  module Let_syntax : sig

    val return : 'a -> 'a t

    val bind : 'a t -> f:('a -> 'b t) -> 'b t

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val both : 'a t -> 'b t -> ('a * 'b) t

    module Open_on_rhs : sig end

  end

end

(** Ignore the state and return error message with erroneous value. *)
val fail : ?strict:unit -> string -> 'a -> ('a -> Base.Sexp.t) -> 'a t

(** Ignore the state and return error message *)
val fail_string : string -> 'a t

(** Ignore the state and return a formatted message *)
val failf : ('a, unit, string, 'b t) format4 -> 'a

(* Create a fresh variable and update the state *)
val create_fresh : ?name:string -> unit -> Ast.variable t

(** Look for given variable in linear_vars *)
val lookup : Ast.variable -> tagged_linear_t option t

(** Proof that a fractional-capability is well-formed. *)
type wf_frac_cap

(** Check if a fractional capability is well-formed w.r.t. the environment. *)
val if_well_formed :
  Ast.frac_cap -> then_:(wf_frac_cap -> 'a t) -> else_:(Ast.frac_cap -> 'a t) -> 'a t

(** Proof that (fractional-capability) variable is well-formed. *)
type wf_variable

(** Perform a well-formed substitution on a ForAll_frac_cap type *)
val wf_substitute_in : well_formed -> wf_variable -> wf_frac_cap -> well_formed t

(** Perform a split on a well-formed typed assuming it is a ForAll_frac_cap. *)
val split_wf_ForAll :
   well_formed t ->
   if_forall:(wf_variable -> well_formed -> 'a t) ->
   not_forall:(Ast.linear_t -> 'a t) -> 'a t

(** Perform a split on a well-formed typed assuming it is a pair. *)
val split_wf_Pair :
   well_formed t ->
   if_pair:(well_formed -> well_formed -> 'a t) ->
   not_pair:(Ast.linear_t -> 'a t) -> 'a t

(** Perform a split on a well-formed typed assuming it is a fun. *)
val split_wf_Fun :
   well_formed t ->
   if_fun:(well_formed -> well_formed -> 'a t) ->
   not_fun:(Ast.linear_t -> 'a t) -> 'a t

(** Linear-type is well-formed if all fractional capabilities are well-formed. *)
val well_formed_lt :
  fmt:('a -> Ast.linear_t t, unit, string, 'b t) format4 ->
  arg:'a -> Ast.linear_t -> well_formed t

(** Marks the [not_used] variable and linear_t as used and returns latter. *)
val use_var : not_used -> well_formed t

(** Evaluates the given monadic value in the context extended with the given
    mappings and then removes those mappings from the environment, checking that
    each variable has been used once.
    - Mappings must be globally unique. *)
val with_linear_t :
  (Ast.variable * well_formed) list -> well_formed t -> well_formed t

(** Evaluates the given monadic value in the context extended with the given
    mappings and then removes those mappings from the environment.
    - Mappings must be globally unique. *)
val with_frac_cap :
  Ast.variable list -> well_formed t -> well_formed t

(** Evaluates the monadic value. Must ensure [counter] = #variables in expression + 1. *)
val run : well_formed t -> counter:int -> Ast.linear_t Base.Or_error.t
