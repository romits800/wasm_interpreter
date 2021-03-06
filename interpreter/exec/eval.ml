(* open Values *)
open Svalues
open Types
open Instance
open Ast
open Source
open Pc_type

(* Errors *)

module Link = Error.Make ()
module Trap = Error.Make ()
module Crash = Error.Make ()
module Exhaustion = Error.Make ()
module ConstantTime = Error.Make ()
module NonInterference = Error.Make ()

exception Link = Link.Error
exception Trap = Trap.Error
exception Crash = Crash.Error (* failure that cannot happen in valid code *)
exception Exhaustion = Exhaustion.Error
(* exception ConstantTime = ConstantTime.Error
 * exception NonIntereference = NonInterference.Error *)

(* let memory_error at = function
 *   | Memory.Bounds -> "out of bounds memory access"
 *   | Memory.SizeOverflow -> "memory size overflow"
 *   | Memory.SizeLimit -> "memory size limit reached"
 *   | Memory.Type -> Crash.error at "type mismatch at memory access"
 *   | exn -> raise exn *)

(*TODO(Romy): implement *)
(* let smemory_error at = function *)
  (* | Memory.Bounds -> "out of bounds memory access"
   * | Memory.SizeOverflow -> "memory size overflow"
   * | Memory.SizeLimit -> "memory size limit reached"
   * | Memory.Type -> Crash.error at "type mismatch at memory access" *)
  (* | exn -> raise exn *)



let numeric_error at = function
  | Numeric_error.IntegerOverflow -> "integer overflow"
  | Numeric_error.IntegerDivideByZero -> "integer divide by zero"
  | Numeric_error.InvalidConversionToInteger -> "invalid conversion to integer"
  | Eval_numeric.TypeError (i, v, t) ->
    Crash.error at
      ("type error, expected " ^ Types.string_of_value_type t ^ " as operand " ^
       string_of_int i ^ ", got " ^ Types.string_of_value_type (Values.type_of v))
  | Eval_symbolic.TypeError (i, v, t) ->
    Crash.error at
      ("type error, expected " ^ Types.string_of_svalue_type t ^ " as operand " ^
       string_of_int i ^ ", got " ^ Types.string_of_svalue_type (Svalues.type_of v))
  | exn -> raise exn


(* administrative Expressions & Configurations *)

type 'a stack = 'a list

module LocalVarsMap = Map.Make(struct
                          type t = int
                          let compare = (-)
                        end)

              
(* TODO(Romy): Fix module_inst *)
type frame =
{
  inst : module_inst;
  locals : svalue LocalVarsMap.t ; (*svalue list;*)
  is_memset : bool;
}


type modifier = Increase of svalue | Decrease of svalue | Nothing
                                                       
type loopvar_t = LocalVar of int32 Source.phrase * bool * modifier * (svalue * simpl) option
               | GlobalVar of int32 Source.phrase * bool * modifier * (svalue * simpl) option
               | StoreVar of svalue option * Types.value_type * Types.pack_size option * bool * modifier * region
               | StoreZeroVar of svalue


module MaxLoopSize = Map.Make(struct
                       type t = int
                       let compare = (-)
                     end)

let maxloop :  int MaxLoopSize.t ref = ref MaxLoopSize.empty

                                     
                                     
let empty_maxloop () =
  maxloop := MaxLoopSize.empty


let update_maxloop addr maxl =
  maxloop := MaxLoopSize.add addr maxl !maxloop

let find_maxloop addr =
  MaxLoopSize.find addr !maxloop

(* TODO(Romy): MapFix *)
module IndVarMap = Map.Make(struct
                       type t = svalue * Source.region
                       let compare = compare
                     end)
                 
type triple = svalue * svalue * svalue * svalue
(*real init value, symb init value, mul, add*)

                           
type iv_type = triple IndVarMap.t

type ct_check_t = bool


                
type code = svalue stack * admin_instr list          
and admin_instr = admin_instr' phrase
and admin_instr' =
  | Plain of instr'
  | Invoke of func_inst
  | Trapping of string
  | Returning of svalue stack
  | Breaking of int32 * svalue stack
  | Label of int32 * admin_instr list * code * pc_ext * iv_type option * ct_check_t 
  | Frame of int32 * frame * code * pc_ext * iv_type option 
  | Assert of loopvar_t list * instr' * bool
  | Havoc of loopvar_t list
  | FirstPass of int32 * admin_instr list * code
  | NonCheckPass of int32 * admin_instr list * code * triple * loopvar_t list * config 
  | SecondPass of int32 * admin_instr list * code
           
and obs_type =
  | CT_UNSAT of pc_ext * svalue * (Smemory.t list * int * int) * obs_type
  | CT_V_UNSAT of pc_ext * svalue * (Smemory.t list * int * int) * obs_type
  (* | CT_SAT of pc * obs_type *)
  | OBSTRUE

and config =
{
  frame : frame;
  code : code;
  budget : int;  (* to model stack overflow *)
  pc : pc_ext;  (* to model path condition *)
  progc : int;
  msecrets : secret_type list;
  loops : config list;
  (* abstract_loops: admin_instr' list; *)
  abstract_loops: config list;
  observations: obs_type;
  counter : int;
  induction_vars : iv_type option;
  ct_check : ct_check_t;
}
and
secret_type = int * int


module LocMap = Map.Make(struct
                    type t = string
                    let compare = compare
                  end)
                   
let locmap :  config list LocMap.t ref = ref LocMap.empty

let rec find_loc (e : admin_instr) (es : admin_instr list) : string =
  match e.it with
  | Frame (n, frame', (vs', []), pc', iv') ->
     (match es with
     | e'::es' -> find_loc e' es'
     | [] -> string_of_region e.at
     )
  | Frame (n, frame', (vs', e'::es'), pc', iv') -> find_loc e' es'
  | Label (n, es0, (vs', []), pc', iv', cct) ->
     (match es with
     | e'::es' -> find_loc e' es'
     | [] -> string_of_region e.at
     )
  | Label (n, es0, (vs',e'::es'), pc', iv', cct') -> find_loc e' es'
  | _ -> string_of_region e.at
     
let add_locmap c =
  match c.code with
  | vs, [] -> ()
  | vs, {it = Trapping msg; at} :: _ -> Trap.error at msg
  | vs, e::es ->
     let loc = find_loc e es in
     if !Flags.debug then
       print_endline "Add locmap.";
     let oldval = 
       try
         LocMap.find loc !locmap
       with Not_found ->
         []
     in
     locmap := LocMap.add loc (c::oldval) !locmap

let next_locmap () =
  try
    Some (LocMap.find_first (fun k -> true) !locmap)
  with Not_found -> None

let remove_locmap loc =
  locmap := LocMap.remove loc !locmap
                  
let modifier_to_string = function
  | Decrease vold -> "Decrease " ^ (svalue_to_string vold)
  | Increase vold -> "Increase " ^ (svalue_to_string vold)
  | Nothing -> "Nothing"
                     
let print_loopvar = function
  | LocalVar (i, tf, mo, Some (sv,simp)) ->
     "Local " ^ (string_of_bool tf) ^ " " ^
       (Int32.to_int i.it |> string_of_int) ^ " " ^
         (svalue_to_string sv) |> print_endline
  | LocalVar (i, tf, mo, _) ->
     "Local " ^ (string_of_bool tf) ^ " " ^
       (Int32.to_int i.it |> string_of_int) |> print_endline
  | GlobalVar (i, tf, mo, Some (sv,simp)) ->
     "Global " ^ (string_of_bool tf) ^ " " ^
       (Int32.to_int i.it |> string_of_int) ^  " " ^
         (svalue_to_string sv) |> print_endline
  | GlobalVar (i, tf, mo, _) ->
     "Global " ^ (string_of_bool tf) ^ " " ^
       (Int32.to_int i.it |> string_of_int) |> print_endline
  | StoreVar (Some sv, ty, sz, tf, mo, loc) ->
     "Store " ^ (string_of_bool tf) ^ " " ^ (svalue_to_string sv) |> print_endline
  | StoreVar (None, ty, sz, tf, mo, loc) ->
     "Store " ^ (string_of_bool tf)  |> print_endline
  | StoreZeroVar (sv) ->
     "StoreZero: Prev Value " ^ (svalue_to_string sv) |> print_endline
     
  
    
let frame inst locals = {inst; locals; is_memset = false}
let config inst vs es =
  {frame = frame inst LocalVarsMap.empty; code = vs, es; budget = 300;
   pc = empty_pc(); msecrets = inst.secrets; loops = []; abstract_loops = [];
   observations = OBSTRUE;  counter = 0; induction_vars = None; progc = 0;
   ct_check = true}

let plain e = Plain e.it @@ e.at

let lookup_map category map x =
  let intval = Int32.to_int x.it in
  try LocalVarsMap.find intval map with Not_found ->
    Crash.error x.at ("undefined " ^ category ^ " " ^ Int32.to_string x.it)
  
            
let lookup category list x =
  try Lib.List32.nth list x.it with Failure _ ->
    Crash.error x.at ("undefined " ^ category ^ " " ^ Int32.to_string x.it)

let type_ (inst : module_inst) x = lookup "type" inst.types x
let func (inst : module_inst) x = lookup "function" inst.funcs x
let table (inst : module_inst) x = lookup "table" inst.tables x
let memory (inst : module_inst) x = lookup "memory" inst.memories x
let smemory (inst : module_inst) x = lookup "smemory" inst.smemories x
let smemlen (inst : module_inst) =  inst.smemlen
let smemnum (inst : module_inst) =  inst.smemnum
(* let global (inst : module_inst) x = lookup "global" inst.globals x *)
let sglobal (inst : module_inst) x = lookup "sglobal" inst.sglobals x
let local (frame : frame) x = lookup_map "local" frame.locals x

let update_smemory (inst : module_inst) (mem : Instance.smemory_inst)
      (x : int32 Source.phrase)  = 
  try
    {inst with smemories = Lib.List32.replace x.it mem inst.smemories}
  with Failure _ ->
    Crash.error x.at ("undefined smemory " ^ Int32.to_string x.it)

let insert_smemory (inst : module_inst) (smemnum: int) (mem : Instance.smemory_inst)  = 
  try
    {inst with smemories = Lib.List32.insert mem inst.smemories;
               smemlen = inst.smemlen + 1;
               smemnum = smemnum}
  with Failure _ ->
    failwith "insert memory"

let update_local (frame : frame) (x : int32 Source.phrase) (sv: svalue) = 
  try
    {frame with locals = LocalVarsMap.add (Int32.to_int x.it) sv frame.locals}
  with Failure _ ->
    Crash.error x.at ("udefined local " ^ Int32.to_string x.it)

let update_sglobal (inst : module_inst) (glob : Instance.sglobal_inst)
      (x : int32 Source.phrase)  = 
  try
    {inst with sglobals = Lib.List32.replace x.it glob inst.sglobals}
  with Failure _ ->
    Crash.error x.at ("undefined smemory " ^ Int32.to_string x.it)

let elem inst x i at =
  match Table.load (table inst x) i with
  | Table.Uninitialized ->
    Trap.error at ("uninitialized element " ^ Int32.to_string i)
  | f -> f
  | exception Table.Bounds ->
    Trap.error at ("undefined element " ^ Int32.to_string i)

let func_elem inst x i at =
  match elem inst x i at with
  | FuncElem f -> f
  | _ -> Crash.error at ("type mismatch for element " ^ Int32.to_string i)

let func_is_memset = function
  | Func.AstFunc (t, inst, f) -> f.it.memset
  | Func.HostFunc (t, _) -> false

       
let func_type_of = function
  | Func.AstFunc (t, inst, f) -> t
  | Func.HostFunc (t, _) -> t

let block_type inst bt =
  match bt with
  | VarBlockType x -> type_ inst x
  | ValBlockType None -> FuncType ([], [])
  | ValBlockType (Some t) -> FuncType ([], [t])

let take n (vs : 'a stack) at =
  try Lib.List32.take n vs with Failure _ -> Crash.error at "stack underflow"

let drop n (vs : 'a stack) at =
  try Lib.List32.drop n vs with Failure _ -> Crash.error at "stack underflow"

(* let svalue_to_string (sv : svalue): string =
 *   match sv with
 *   | SI32 sv -> Si32.to_string_s sv
 *   | SI64 sv -> Si64.to_string_s sv
 *   | SF32 sv -> F32.to_string sv
 *   | SF64 sv -> F64.to_string sv *)

  
let split_condition (sv : svalue) (pc : pc_ext): pc * pc =
  let pc' = 
    match sv with
    | SI32 vi32 ->
       let zero = Si32.zero in
       PCAnd( SI32 (Si32.ne vi32 zero), pc)
    | SI64 vi64 ->
       let zero = Si64.zero in
       PCAnd( SI64 (Si64.ne vi64 zero), pc)
    | SF32 vf32 -> PCAnd( SF32 ( F32.neg vf32), pc)
    | SF64 vf64 -> PCAnd( SF64 ( F64.neg vf64), pc)
  in
  let pc'' =
    match sv with
    | SI32 vi32 ->
       let zero = Si32.zero in
       PCAnd( SI32 ( Si32.eq vi32 zero ), pc)
    | SI64 vi64 ->
       let zero = Si64.zero in
       PCAnd( SI64 ( Si64.eq vi64 zero), pc)
    | SF32 vf32 -> PCAnd( SF32 ( F32.neg vf32), pc)
    | SF64 vf64 -> PCAnd( SF64 ( F64.neg vf64), pc)
  in
  (pc'', pc') (* false, true *)


let add_equality (sv1 : svalue) (sv2 : svalue) (pc : pc_ext): pc =
    match sv1, sv2 with
    | SI32 vi1, SI32 vi2 ->
       PCAnd( SI32 (Si32.eq vi1 vi2), pc)
    | SI64 vi1, SI64 vi2 ->
       PCAnd( SI64 (Si64.eq vi1 vi2), pc)
    | _, _-> failwith "Equality different types or floats is not supported."

  
let split_msec (sv : svalue)
      (msec : (int * int) list )
      (mpub : (int * int) list ) (pc : pc_ext) : pc * pc =  
  (* let pc' = PCAnd (sv, pc) in
   * let pc'' = *)
  (* print_endline "split_msec"; *)
  let rec within_range sv msec =
    match msec with
    | [] -> Si32.ne Si32.zero Si32.zero
    | (lo, hi)::[] ->
       let hrange = Si32.le_u sv (Si32.of_int_s hi) in
       let lrange = Si32.ge_u sv (Si32.of_int_s lo) in
       Si32.and_ hrange lrange
       (* PCAnd(sv, pc) *)
    | (lo, hi)::msecs ->
       let hrange = Si32.le_u sv (Si32.of_int_s hi) in
       let lrange = Si32.ge_u sv (Si32.of_int_s lo) in
       let hl = Si32.and_ hrange lrange in
       Si32.or_ hl (within_range sv msecs)
  in
  match sv with
  | SI32 vi32 ->
     let lrange = within_range vi32 mpub in (* Si32.not_ hrange in *)
     let hrange = Si32.not_ lrange in (* within_hrange vi32 msec in *)
     (PCAnd (SI32 hrange, pc), PCAnd (SI32 lrange, pc))
  | _ -> failwith "Address should be 32bit integer"


let select_condition v0 v1 v2 = (* (v0: svalue  v1: svalue): svalue = *)
  match v0, v1, v2 with
  (* v0 :: v2 :: v1 :: vs' -> *)
  | SI32 vi32, SI32 vi32_1, SI32 vi32_2 ->
     let one = Si32.one in
     let cond = Si32.eq vi32 one in
     SI32 ( Si32.ite cond vi32_1 vi32_2 )
  | SI32 vi32, SI64 vi64_1, SI64 vi64_2 ->
     let one = Si32.one in
     let cond = Si32.eq vi32 one in
     SI64 ( Si64.ite cond vi64_1 vi64_2 )
  (* | SF32 vf32, SF32 vf32_1, SF32 vf32_2 -> SF32 vf32
   * | SF64 vf64, SF64 vf64_1, SF64 vf64_2 -> SF64 vf64 *)
  | _ -> failwith "Type problem select"

let match_policy b1 b2 =
  match b1,b2 with
  | true, true | false, false -> true
  | _ -> false

let get_mem_tripple frame =
  (frame.inst.smemories, smemlen frame.inst, smemnum frame.inst)



let is_int_addr sv =
    match sv with
    | Svalues.SI32 s32 -> Si32.is_int s32
    | _ -> failwith "Address should be i32."

let get_int_addr sv =
    match sv with
    | Svalues.SI32 s32 -> Si32.to_int_u s32
    | _ -> failwith "Address should be i32."


let is_int sv =
    match sv with
    | Svalues.SI32 s32 -> Si32.is_int s32
    | Svalues.SI64 s64 -> Si64.is_int s64
    | _ -> failwith "No support for floats."

let get_int sv =
    match sv with
    | Svalues.SI32 s32 -> Si32.to_int_u s32
    | Svalues.SI64 s64 -> Si64.to_int_u s64
    | _ -> failwith "No support for floats."

         

let rtype_equal r1 r2 =
  match r1, r2 with
  | L e1, L e2 -> Z3.Expr.equal e1 e2
  | H (e11, e12), L e2
    | L e2, H (e11, e12) -> Z3.Expr.equal e11 e2 && Z3.Expr.equal e12 e2
   | H (e11, e12), H (e21, e22) -> Z3.Expr.equal e11 e21 && Z3.Expr.equal e12 e22 

let simpl_equal s1 s2 =
  match s1, s2 with
  | Sv sv1, Sv sv2 ->
     is_int sv1 && is_int sv2 && get_int sv1 = get_int sv2
  | Z3Expr32 e1, Z3Expr32 e2
    | Z3Expr64 e1, Z3Expr64 e2 -> rtype_equal e1 e2
  | _, _ -> false
    
     

module VulnerabilitiesMap = Map.Make(struct
                                type t = int
                                let compare = (-)
                              end)
(* Vulnerability types *)
(* Todo(Romy): make only one IntMap *)
module IntMap = Map.Make(struct
                            type t = int
                            let compare = (-)
                          end)

type cline_t = bool IntMap.t
let codelines: cline_t ref = ref IntMap.empty

                          
module ModifiedVarsMap = Map.Make(struct
                              type t = int
                              let compare = (-)
                            end)
let modified_vars: (loopvar_t list * bool IntMap.t) ModifiedVarsMap.t ref = ref ModifiedVarsMap.empty 
type vuln_t = bool VulnerabilitiesMap.t         
let cond_vuln:  vuln_t ref = ref VulnerabilitiesMap.empty
let noninter_vuln: vuln_t ref = ref VulnerabilitiesMap.empty

let memindex_vuln: vuln_t ref = ref VulnerabilitiesMap.empty 


let init_maps () = 
    codelines := IntMap.empty;
    cond_vuln := VulnerabilitiesMap.empty;
    noninter_vuln := VulnerabilitiesMap.empty;
    memindex_vuln := VulnerabilitiesMap.empty

let get_codelines () = 
    IntMap.bindings !codelines |> List.length

let print_codelines () = 
    IntMap.bindings !codelines |> List.iter (fun (k,v) -> print_endline (string_of_int k))


let are_same_sv_simpl v simp c = 
    let memtuple = get_mem_tripple c.frame in
    match simp with
    | Sv nv -> 
        Z3_solver.are_same v nv c.pc memtuple 
    | Z3Expr32 ex | Z3Expr64 ex ->
        Z3_solver.are_same_e v ex c.pc memtuple 

(* Assert invariant *)
let assert_invar (lv : loopvar_t list) (c : config) : bool =
 let rec assert_invar_i (lv : loopvar_t list) (c : config) : bool =
  match lv with
  | LocalVar (x, _, mo, Some (nv,simp)) as lh :: lvs ->
     (* print_endline "localvar"; *)
     
     if !Flags.debug then print_loopvar lh;
     if !Flags.debug then print_endline (svalue_to_string nv);
     let v = local c.frame x in
     if are_same_sv_simpl v simp c then
       assert_invar_i lvs c
     else false
     
  | LocalVar (x, (true as is_low), mo, None) as lh :: lvs ->
     (* print_endline "localvar"; *)
     
     if !Flags.debug then print_loopvar lh;
     let v = local c.frame x in
     let mem = get_mem_tripple c.frame in
     let is_low_new = Z3_solver.is_v_ct_unsat ~timeout:200 c.pc v mem in
     if !Flags.debug then print_endline (string_of_bool is_low_new);
     if match_policy is_low is_low_new then assert_invar_i lvs c
     else (
       (* print_endline (Int32.to_string x.it); *)
       (*let _ = assert_invar_i lvs c in*)
       false )

  | GlobalVar (x, _, mo, Some (nv,simp)) as lh :: lvs ->     
     if !Flags.debug then print_loopvar lh;
     if !Flags.debug then print_endline (svalue_to_string nv);
     let v = Sglobal.load (sglobal c.frame.inst x) in
     if are_same_sv_simpl v simp c then
       assert_invar_i lvs c
     else false
     (*if (is_int v && get_int v = get_int nv) then assert_invar_i lvs c
     else false*)

  | GlobalVar (x, (true as is_low), mo, None) as lh :: lvs ->
     if !Flags.debug then print_loopvar lh;
     (* print_endline "globalvar"; *)
     let v = Sglobal.load (sglobal c.frame.inst x) in
     let mem = get_mem_tripple c.frame in 
     let is_low_new = Z3_solver.is_v_ct_unsat ~timeout:200 c.pc v mem in
     if !Flags.debug then print_endline (string_of_bool is_low_new);
     if match_policy is_low is_low_new then assert_invar_i lvs c
     else (
        (*let _ = assert_invar_i lvs c in*)
         false
     )

  | StoreVar (Some (SI32 addr' as addr), ty, sz, (true as is_low), mo, loc) :: lvs
       when Si32.is_int addr' ->
     if !Flags.debug then print_loopvar (List.hd lv);
     (* print_endline "storevar"; *)
     let nv =
       (match sz with
        | None ->
           Eval_symbolic.eval_load ty addr (smemlen c.frame.inst) (smemnum c.frame.inst)
             (Types.size ty) None
        | Some (sz) ->
           assert (packed_size sz <= Types.size ty);
           let n = packed_size sz in
           Eval_symbolic.eval_load ty addr (smemlen c.frame.inst) (smemnum c.frame.inst) n None 
       )
     in
     (* let mem = smemory c.frame.inst (0l @@ Source.no_region) in *)

     let memtuple = get_mem_tripple c.frame in 
     let is_low_new = Z3_solver.is_v_ct_unsat ~timeout:200 c.pc nv memtuple in
     if !Flags.debug then  print_endline (string_of_bool is_low_new);

     if match_policy is_low is_low_new then assert_invar_i lvs c
     else (
       (*let _ = assert_invar_i lvs c in*)
       false)
  (* if it is high, we don't mind if it got low *)
  | StoreZeroVar sv :: lvs -> 
     let ty = Types.I32Type in 
     let final_addr = Svalues.SI32 (Si32.of_int_u 0) in
     let nv = Eval_symbolic.eval_load ty final_addr 
                (smemlen c.frame.inst) (smemnum c.frame.inst) 4 None
     in
     let memtuple = get_mem_tripple c.frame in
     if Z3_solver.are_same sv nv c.pc memtuple then
       assert_invar_i lvs c
     else (false)
  | _ :: lvs -> assert_invar_i lvs c
  | [] -> true
 in

 assert_invar_i lv c

(* let disable_ct = ref false *)       
  
(* Find variants that get updated in a loop *)


       
let add_high types =
  let rec add_high_i types acc =
    match types with
    | [] -> acc
    | I32Type::ts -> add_high_i ts (SI32 (Si32.of_high ())::acc)
    | I64Type::ts -> add_high_i ts (SI64 (Si64.of_high ())::acc)
    | _ -> failwith "Not support floats"
  in
  add_high_i types []        


let begin_line_number reg = 
    reg.left.line
