module Q = struct
  type t = Fa | Ex

  let is_forall = function Fa -> true | Ex -> false
  let is_exists x = not @@ is_forall x

  let of_string = function
    | "forall" -> Fa
    | "exists" -> Ex
    | _ -> failwith "not a quantifier"

  let to_string = function Fa -> "forall" | Ex -> "exists"
  let pretty_layout = function Fa -> "∀ " | Ex -> "∃ "
end

module Smtty = struct
  type t = Bool | Int | Dt [@@deriving sexp]

  let smtty_eq = function
    | Bool, Bool | Int, Int -> true
    | Dt, Dt -> true
    | _ -> false

  let eq a b = smtty_eq (a, b)
  let layout = function Bool -> "B" | Int -> "I" | Dt -> "D"

  let pretty_typed_layout str = function
    | Bool -> Printf.sprintf "(%s:𝓑 )" str
    | Dt -> Printf.sprintf "(%s:𝓓 )" str
    | Int -> str

  let is_dt = function Dt -> true | _ -> false
end

module T = struct
  open Sexplib.Std
  open Sugar

  type id = string [@@deriving sexp]

  type t =
    | Ty_unknown
    | Ty_var of string
    | Ty_unit
    | Ty_int
    | Ty_bool
    | Ty_list of t
    | Ty_tree of t
    | Ty_arrow of t * t
    | Ty_tuple of t list
    | Ty_constructor of (id * t list)
  [@@deriving sexp]

  let rec to_string (ty : t) : id =
    (match ty with
      | Ty_unknown -> "unknown"
      | Ty_var x -> x
      | Ty_unit -> "()"
      | Ty_int -> "int"
      | Ty_bool -> "bool"
      | Ty_list l -> to_string l ^ " list"
      | Ty_tree t -> to_string t ^ " tree"
      | Ty_arrow (t1, t2) -> Printf.sprintf "%s -> %s" (to_string t1) (to_string t2)
      | Ty_tuple ts -> Printf.sprintf "(%s)" @@ String.concat ", " @@ List.map to_string ts
      | Ty_constructor (id, args) ->
          Printf.sprintf "%s(%s)" id (String.concat ", " @@ List.map to_string args)
    )

  let is_basic_tp = function Ty_unit | Ty_int | Ty_bool -> true | _ -> false

  let is_dt = function
    | Ty_list _ | Ty_tree _ | Ty_constructor _ -> true
    | _ -> false

  let eq x y =
    let rec aux (x, y) =
      match (x, y) with
      | Ty_unknown, Ty_unknown -> true
      | Ty_var x, Ty_var y -> String.equal x y
      | Ty_unit, Ty_unit -> true
      | Ty_int, Ty_int -> true
      | Ty_bool, Ty_bool -> true
      | Ty_list x, Ty_list y -> aux (x, y)
      | Ty_tree x, Ty_tree y -> aux (x, y)
      | Ty_arrow (x, x'), Ty_arrow (y, y') -> aux (x, y) && aux (x', y')
      | Ty_tuple xs, Ty_tuple ys ->
          if List.length xs == List.length ys then
            List.for_all aux @@ List.combine xs ys
          else false
      | Ty_constructor (id1, args1), Ty_constructor (id2, args2) ->
          String.equal id1 id2
          && List.length args1 == List.length args2
          && List.for_all2 (fun a b -> aux (a, b)) args1 args2
      | _ -> false
    in
    aux (x, y)

  let destruct_arrow_tp tp =
    let rec aux = function
      | Ty_arrow (t1, t2) ->
          let argsty, bodyty = aux t2 in
          (t1 :: argsty, bodyty)
      | ty -> ([], ty)
    in
    aux tp

  let rec construct_arrow_tp = function
    | [], retty -> retty
    | h :: t, retty -> Ty_arrow (h, construct_arrow_tp (t, retty))

  let to_smtty t =
    let aux = function
      | Ty_bool -> Smtty.Bool
      | Ty_int -> Smtty.Int
      | Ty_list _ | Ty_tree _ | Ty_constructor _ -> Smtty.Dt
      | _ ->
          let () =
            Printf.printf "t: %s\n" @@ Sexplib.Sexp.to_string @@ sexp_of_t t
          in
          _failatwith __FILE__ __LINE__ "not a basic type"
    in
    aux t
end
