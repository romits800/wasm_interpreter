open Stypes


(* Values and operators *)

type ('i32, 'i64, 'f32, 'f64) op =
  SI32 of 'i32 | SI64 of 'i64 | SF32 of 'f32 | SF64 of 'f64

type svalue = (Si32.t, Si64.t, F32.t, F64.t) op


(* Typing *)

let type_of = function
  | SI32 _ -> SI32Type
  | SI64 _ -> SI64Type
  | SF32 _ -> SF32Type
  | SF64 _ -> SF64Type

let default_value = function
  | SI32Type -> SI32 Si32.zero
  | SI64Type -> SI64 Si64.zero
  | SF32Type -> SF32 F32.zero
  | SF64Type -> SF64 F64.zero

let value_to_svalue = function
  | Types.I32Type -> SI32Type
  | Types.I64Type -> SI64Type
  | Types.F32Type -> SF32Type
  | Types.F64Type -> SF64Type

              
(* Conversion *)

let value_of_bool b = SI32 (if b then 1l else 0l)

let string_of_value = function
  | SI32 i -> Si32.to_string_s i
  | SI64 i -> Si64.to_string_s i
  | SF32 z -> F32.to_string z
  | SF64 z -> F64.to_string z

let string_of_values = function
  | [v] -> string_of_value v
  | vs -> "[" ^ String.concat " " (List.map string_of_value vs) ^ "]"


(* Injection & projection *)

exception SValue of svalue_type

module type ValueType =
sig
  type t
  val to_value : t -> svalue
  val of_value : svalue -> t (* raise Value *)
end

module SI32Value =
struct
  type t = Si32.t
  let to_value i = SI32 i
  let of_value = function SI32 i -> i | _ -> raise (SValue SI32Type)
end

module SI64Value =
struct
  type t = Si64.t
  let to_value i = SI64 i
  let of_value = function SI64 i -> i | _ -> raise (SValue SI64Type)
end

module SF32Value =
struct
  type t = F32.t
  let to_value i = SF32 i
  let of_value = function SF32 z -> z | _ -> raise (SValue SF32Type)
end

module SF64Value =
struct
  type t = F64.t
  let to_value i = SF64 i
  let of_value = function SF64 z -> z | _ -> raise (SValue SF64Type)
end