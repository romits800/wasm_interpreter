open Types
open Svalues

type memory
type t = memory

type size = int32  (* number of pages *)
type address = int64
type offset = int32

exception Type
exception Bounds
exception SizeOverflow
exception SizeLimit
exception OutOfMemory

val page_size : int64

val get_secrets : memory -> (int * int) list
val get_public : memory -> (int * int) list
val get_stores : memory -> svalue list
val get_prev_mem : memory -> memory option
val get_num : memory -> int
  
val alloc : smemory_type -> memory 
val alloc2 : int32  -> memory 
val type_of : memory -> smemory_type
val bound : memory -> address
val grow : memory -> size -> memory
(*TODO(Romy): change int to address *)
val store_byte : memory -> int -> Si8.t -> memory
val load_value :
  memory -> int -> int -> svalue_type -> memory * svalue
val store_value :
  memory -> int -> int -> svalue -> memory
(* inputs: memory, store_svalue (index, value); outputs: memory *)
val store_sind_value : int -> memory -> svalue ->  memory
val store_init_value : int -> memory -> svalue ->  memory
val add_secret : memory -> (int * int) -> memory
val add_public : memory -> (int * int) -> memory

val replace_stores : memory -> svalue list -> memory
(* val init_secrets : memory -> (int32 * int32 ) list -> memory *)

