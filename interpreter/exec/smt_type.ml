type identifier =
  High of int | Low of int 

type func =
  | Id of string

  | Eq  | And | Or 
  | Ite | Not

  | Implies
  | Add | Sub | Mul | Div
  | Lt | Gt | Lte | Gte

  | BvAdd | BvSub | BvMul
                  
  | BvURem | BvSRem | BvSMod | BvDiv
  | BvShl | BvLShr | BvAShr
                   
  | BvOr | BvAnd | BvNand | BvNor | BvXNor | BvXor
  | BvNeg | BvNot
  | BvUle | BvUlt
  | BvSle | BvSlt 
  | BvUge | BvUgt
  | BvSge | BvSgt

                           
type sort = 
  | Sort of identifier
  | SortApp of identifier * sort list
  | BitVecSort of int

type term = 
  | String of string
  | Int of int
  | Float of float
  | BitVec of int * int (* bool + number of bits *)
  | Const of identifier
  | Multi of term list * identifier * int (* term list, high/low, number_of_elements *)
  (* index in memory and index of memory - because we cannot have the memory here*)
  | Load of term * int
  | Store of term * term * int (* address, value, memory *) 
  (* | Load of Smemory.t * term (\* memory, index *\) *)
  | App of func * term list
  | Let of string * term * term


type mergetype = PLUS_INF | MINUS_INF | Integer of int | Term of term
                                                     
let curr_num = ref 0

let new_const () =
  curr_num := !curr_num + 1;
  !curr_num

(* val int_sort : sort
 * 
 * val bool_sort : sort
 * 
 * val array_sort : sort -> sort -> sort *)

let zero = BitVec (0, 32)
let one = BitVec (1, 32)
         
let int_to_intterm i = Int i
let int_to_bvterm i n = BitVec (i,n)
let float_to_term f = Float f

  
let rec is_high =
  function
  | Const (High _)
    | Multi(_, High _, _) -> true
  | App (f, t::ts) -> is_high_all ts
  | Let (str, t1, t2) -> is_high t1 || is_high t2
  | _ -> false

and is_high_all = function
  | h::hs -> is_high h || is_high_all hs
  | [] -> false


        
let is_low l =
  not (is_high l)

let is_int = function
  | Int _
    | BitVec _ -> true
  | _ -> false

let get_high () =
  let newc = new_const() in
  High newc

let get_low () =
  let newc = new_const() in
  Low newc
                    
let high_to_term () =
  Const (get_high())
  
let low_to_term () =
  Const (get_low())
                   
let list_to_term ts =
  let id = if is_high_all ts then get_high () else get_low () in
  Multi(ts, id, List.length ts)
  
let term_to_int i =
  match i with
  | Int i -> i
  | BitVec (i,n) -> i
  | _ -> failwith "Term_to_int error: at smt_type"

let bool_to_term b =  if b then BitVec (1, 1) else BitVec (0, 1)

(* let const str = Const str *)

  (* match t1, t2 with
   * | App (Eq, ts1), App (Eq, ts2) -> App(Eq, ts1 @ ts2)
   * | App (Eq, ts), t
   *   | t, App(Eq, ts) -> App(Eq, t::ts)
   * | _, _-> App(Eq, [t1;t2]) *)

let load t i = Load(t, i)
let store t vt i = Store(t, vt, i) 

let and_ t1 t2 =
  match t1, t2 with
  | App (And, ts1), App (And, ts2) -> App (And, ts1 @ ts2)
  | App (And, ts), t
    | t, App (And, ts) -> App (And, t::ts)
  | _, _-> App (And, [t1;t2])

let or_ t1 t2 =
  match t1, t2 with
  | App (Or, ts1), App (Or, ts2) -> App(Or, ts1 @ ts2)
  | App (Or, ts), t
    | t, App(Or, ts) -> App(Or, t::ts)
  | _, _-> App(Or, [t1;t2])

        
let not_ t1 =
  match t1 with
  | App (Not, [ts]) -> ts
  | _ -> App(Not, [t1])

(* val not_ : term -> term *)


(* val ite : term -> term -> term -> term *)
let ite b tif telse = App (Ite, [b;tif;telse])

let equals t1 t2 = App (Eq, [t1;t2]) (* ite (App(Eq, [t1;t2])) (Int 1) (Int 0) *)
                 
let implies t1 t2 = App(Implies, [t1;t2])

let add t1 t2 =
  match t1, t2 with
  | App (Add, ts1), App (Add, ts2) -> App (Add, ts1 @ ts2)
  | App (Add, ts), t
    | t, App (Add, ts) -> App (Add, t::ts)
  | _, _-> App (Add, [t1;t2])

let sub t1 t2 = App (Sub, [t1;t2])

let mul t1 t2 =
  match t1, t2 with
  | App (Mul, ts1), App (Mul, ts2) -> App (Mul, ts1 @ ts2)
  | App (Mul, ts), t
    | t, App (Mul, ts) -> App (Mul, t::ts)
  | _, _-> App (Mul, [t1;t2])

let div t1 t2 = App (Div, [t1;t2])

let lt t1 t2 = App(Lt, [t1;t2])
             
let gt t1 t2 = App(Gt, [t1;t2])

let lte t1 t2 = App(Lte, [t1;t2])
              
let gte t1 t2 = App(Gte, [t1;t2])


let bv i nb = BitVec(i, nb)

let bvadd t1 t2 = App (BvAdd, [t1; t2])
    (* match t1, t2 with
     * | App (BvAdd, ts1), App (BvAdd, ts2) -> App (BvAdd, ts1 @ ts2)
     * | App (BvAdd, ts), t
     *   | t, App (BvAdd, ts) -> App (BvAdd, t::ts)
     * | _, _-> App (BvAdd, [t1;t2]) *)


let bvsub t1 t2 = App (BvSub, [t1;t2])

let bvmul t1 t2 = App (BvMul, [t1;t2])
    (* match t1, t2 with
     * | App (BvMul, ts1), App (BvMul, ts2) -> App (BvMul, ts1 @ ts2)
     * | App (BvMul, ts), t
     *   | t, App (BvMul, ts) -> App (BvMul, t::ts)
     * | _, _-> App (BvMul, [t1;t2]) *)


let bvurem t1 t2 = App (BvURem, [t1;t2])
                
let bvsrem t1 t2 = App (BvSRem, [t1;t2])
let bvsmod t1 t2 = App (BvSMod, [t1;t2])

(* Todo(Romy): Check doesn't exists *)
let bvdiv t1 t2 = App (BvDiv, [t1;t2])
                 
let bvshl t1 t2 = App (BvShl, [t1;t2])
let bvlshr t1 t2 = App (BvLShr, [t1;t2])
let bvashr t1 t2 = App (BvAShr, [t1;t2])

let bvor t1 t2 = App (BvOr, [t1;t2])
let bvand t1 t2 = App (BvAnd, [t1;t2])
let bvnand t1 t2 = App (BvNand, [t1;t2])
let bvnor t1 t2 = App (BvNor, [t1;t2])
let bvxnor t1 t2 = App (BvXNor, [t1;t2])
let bvxor t1 t2 = App (BvXor, [t1;t2])
let bvneg t1 = App (BvNeg, [t1])
let bvnot t1 = App (BvNot, [t1])
                
let bvule t1 t2 = App (BvUle, [t1;t2])
let bvult t1 t2 = App (BvUlt, [t1;t2])
let bvuge t1 t2 = App (BvUge, [t1;t2])
let bvugt t1 t2 = App (BvUgt, [t1;t2])
let bvsle t1 t2 = App (BvSle, [t1;t2])
let bvslt t1 t2 = App (BvSlt, [t1;t2])
let bvsge t1 t2 = App (BvSge, [t1;t2])
let bvsgt t1 t2 = App (BvSgt, [t1;t2])



let equal_app f1 f2 =
  match f1,f2 with
  | Eq, Eq | Or, Or | Ite, Ite | Not, Not | Implies, Implies
    | Add, Add | Sub, Sub | Mul, Mul | Div, Div | Lt, Lt
    | Gt, Gt   | Lte, Lte | Gte, Gte | BvAdd, BvAdd | BvSub, BvSub
    | BvMul, BvMul | BvURem, BvURem | BvSRem, BvSRem | BvSMod, BvSMod
    | BvDiv, BvDiv | BvShl, BvShl  | BvLShr, BvLShr  | BvAShr, BvAShr
    | BvOr, BvOr   | BvAnd, BvAnd  | BvNand, BvNand  | BvNor, BvNor
    | BvXNor, BvXNor  | BvXor, BvXor | BvNeg, BvNeg  | BvNot, BvNot
    | BvUle, BvUle | BvUlt, BvUlt  | BvSle, BvSle    | BvSlt, BvSlt
    | BvUge, BvUge | BvUgt, BvUgt  | BvSgt, BvSgt    | BvSge, BvSge
    | And, And -> true
  | _ -> false
       
let equal_id i1 i2 =
  match i1,i2 with
  | High i, High j when i == j -> true
  | Low i, Low j when i == j -> true
  | _ -> false

let rec equal t1 t2 =
  match t1,t2 with
  | Int i, Int j when i == j -> true
  | BitVec (i1,n1), BitVec (i2,n2) when i1 == i2 && n1 == n2 -> true
  | Const id1, Const id2 -> equal_id id1 id2
  | Load (t11,i1), Load (t21, i2) when equal t11 t21 && i1 == i2 -> true
  | Store (t11,t12,i1), Store (t21,t22,i2) when equal t11 t21 && equal t12 t22 && i1 == i2 -> true
  | App (f1, ts1), App (f2, ts2) -> equal_app f1 f2 && equal_list ts1 ts2 
  | _ -> false

and equal_list ts1 ts2 =
  match ts1,ts2 with
  | [], [] -> true
  | t1::ts1',t2::ts2' -> equal t1 t2 && equal_list ts1' ts2'
  | [], _ | _, [] -> false


let ispos v =
  match v with
  | BitVec (i, n) -> i>0
  | Int i -> i>0
  | _ -> false
       
let isneg v = 
  match v with
  | BitVec (i, n) -> i<0
  | Int i -> i<0
  | _ -> false

(* Not accounting for overflows *)
let merge t1 t2 =
  match t1,t2 with
  | App(BvAdd,v1::v2::[]), ts2 
    | ts2, App(BvAdd,v1::v2::[]) ->
     if (equal ts2 v1 && ispos v2) || (equal ts2 v2 && ispos v1)
     then Some (Term ts2, PLUS_INF)
     else
       if (equal ts2 v1 && isneg v2) || (equal ts2 v2 && isneg v1)
       then Some (MINUS_INF, Term ts2)
       else None
  | App(BvSub,v1::v2::[]), ts2 
    | ts2, App(BvSub,v1::v2::[]) ->
     if (equal ts2 v1 && isneg v2) || (equal ts2 v2 && isneg v1)
     then Some (Term ts2, PLUS_INF)
     else
       if (equal ts2 v1 && ispos v2) || (equal ts2 v2 && ispos v1)
       then Some (MINUS_INF, Term ts2)
       else None
  | App(BvMul,v1::v2::[]), ts2 
    | ts2, App(BvMul,v1::v2::[]) ->
     if (equal ts2 v1 && ispos v2) || (equal ts2 v2 && ispos v1)
     then Some (Term ts2, PLUS_INF)
     else
       if (equal ts2 v1 && isneg v2) || (equal ts2 v2 && isneg v1)
       then Some (MINUS_INF, Term ts2)
       else None
  | App(BvShl,v1::v2::[]), ts2 
    | ts2, App(BvShl,v1::v2::[]) ->
     if (equal ts2 v1 && ispos v2) || (equal ts2 v2 && ispos v1)
     then Some (Term ts2, PLUS_INF)
     else None
  | App(BvAShr,v1::v2::[]), ts2 
    | ts2, App(BvAShr,v1::v2::[]) ->
     if (equal ts2 v1 && ispos v2) || (equal ts2 v2 && ispos v1)
     then Some (Term ts2, PLUS_INF)
     else None
  | _ -> None

    
let identifier_to_string id =
  match id with
  | High i -> "h" ^ string_of_int i
  | Low i -> "l" ^ string_of_int i

let func_to_string func =
  match func with
  | Id str -> str
  | Eq -> "Eq"
  | And -> "And"
  | Or -> "Or"
  | Not -> "Not"
  | Ite -> "Ite"
  | Implies -> "Implies"
  | Add -> "Add"
  | Sub -> "Sub"
  | Mul -> "Mul"
  | Div -> "Div"
  | Lt -> "Lt"
  | Gt -> "Gt"
  | Lte -> "Lte"
  | Gte -> "Gte"

  | BvAdd -> "BvAdd"
  | BvSub -> "BvSub"
  | BvMul -> "BvMul"
  | BvURem -> "BvURem"
  | BvSRem -> "BvSRem"
  | BvSMod -> "BvSMod"
  | BvDiv -> "BvDiv"
  | BvShl -> "BvShl"
  | BvLShr -> "BvLShr"
  | BvAShr -> "BvAShr"
  | BvOr -> "BvOr"
  | BvAnd -> "BvAnd"
  | BvNand -> "BvNand"
  | BvXor -> "BvXor"
  | BvNor -> "BvNor"
  | BvXNor -> "BvXNor"
  | BvNeg  -> "BvNeg"
  | BvNot -> "BvNot"
  | BvUle -> "BvUle"
  | BvUlt -> "BvUlt"
  | BvUge -> "BvUge"
  | BvUgt -> "BvUgt"
  | BvSle -> "BvSle"
  | BvSlt -> "BvSlt"
  | BvSge -> "BvSge"
  | BvSgt -> "BvSgt"

           
let rec term_to_string (t : term) : string =
  match t with
  | Load (i, index) -> "Mem[" ^ term_to_string i ^ "]"
  | Store (i, v, index) -> "Mem[" ^ term_to_string i ^ "] = " ^ term_to_string v
  | String s -> s
  | Int i -> string_of_int i
  | Float f ->  string_of_float f
  | BitVec (i, n) -> "BitVec(" ^ string_of_int i ^ ", " ^ string_of_int n ^ ")"
  | Const id ->  identifier_to_string id
  | App (f, ts) -> func_to_string f ^ " (" ^
                     List.fold_left (fun acc -> fun t -> acc ^ term_to_string t ^ ",") "" ts ^ ")" 
  | Let (st, t1, t2) -> "let " ^ st ^ "=" ^ term_to_string t1 ^ "in" ^ term_to_string t2
  | Multi (ts, id, n) ->
     let terms = List.fold_left (fun acc -> fun t -> acc ^ term_to_string t ^ ",") "" ts in
     "Multi( " ^ terms ^ "," ^ identifier_to_string id ^ "," ^ string_of_int n ^ ")"

     (* type mergetype = PLUS_INF | MINUS_INF | ZERO | Term of term *)
let merge_to_string (m : mergetype) : string =
  match m with
  | PLUS_INF -> "inf"
  | MINUS_INF -> "-inf"
  | Integer i -> string_of_int i
  | Term t -> term_to_string t
