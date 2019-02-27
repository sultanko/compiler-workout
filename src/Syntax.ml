(* Opening a library for generic programming (https://github.com/dboulytchev/GT).
   The library provides "@type ..." syntax extension and plugins like show, etc.
*)
open GT 
    
(* Simple expressions: syntax and semantics *)
module Expr =
  struct
    
    (* The type for expressions. Note, in regular OCaml there is no "@type..." 
       notation, it came from GT. 
    *)
    @type t =
    (* integer constant *) | Const of int
    (* variable         *) | Var   of string
    (* binary operator  *) | Binop of string * t * t with show

    (* Available binary operators:
        !!                   --- disjunction
        &&                   --- conjunction
        ==, !=, <=, <, >=, > --- comparisons
        +, -                 --- addition, subtraction
        *, /, %              --- multiplication, division, reminder
    *)
                                                            
    (* State: a partial map from variables to integer values. *)
    type state = string -> int 

    (* Empty state: maps every variable into nothing. *)
    let empty = fun x -> failwith (Printf.sprintf "Undefined variable %s" x)

    (* Update: non-destructively "modifies" the state s by binding the variable x 
      to value v and returns the new state.
    *)
    let update x v s = fun y -> if x = y then v else s y

    let from_bool (b : bool) : int = if b then 1 else 0 
    let to_bool (b : int) : bool = if b == 0 then false else true 

    let str_to_op s =
        match s with
        | "+"  -> (+)
        | "-"  -> (-)
        | "*"  -> ( * )
        | "/"  -> (/)
        | "%"  -> (mod)
        | "<"  -> fun l r -> from_bool ((<) l r)
        | "<=" -> fun l r -> from_bool ((<=) l r)
        | ">"  -> fun l r -> from_bool ((>) l r)
        | ">=" -> fun l r -> from_bool ((>=) l r)
        | "==" -> fun l r -> from_bool ((==) l r)
        | "!=" -> fun l r -> from_bool ((!=) l r)
        | "&&" -> fun l r -> from_bool ((&&) (to_bool l) (to_bool r))
        | "!!" -> fun l r -> from_bool ((||) (to_bool l) (to_bool r))
        | _ -> failwith "fail"

    (* Expression evaluator

          val eval : state -> t -> int
 
       Takes a state and an expression, and returns the value of the expression in 
       the given state.
    *)
    let rec eval st expr = match expr with
        | Const value -> value
        | Var str -> st str
        | Binop (op, l, r) -> str_to_op op (eval st l) (eval st r)

  end
                    
(* Simple statements: syntax and sematics *)
module Stmt =
  struct

    (* The type for statements *)
    @type t =
    (* read into the variable           *) | Read   of string
    (* write the value of an expression *) | Write  of Expr.t
    (* assignment                       *) | Assign of string * Expr.t
    (* composition                      *) | Seq    of t * t with show

    (* The type of configuration: a state, an input stream, an output stream *)
    type config = Expr.state * int list * int list 

    (* Statement evaluator

          val eval : config -> t -> config

       Takes a configuration and a statement, and returns another configuration
    *)
    let rec eval (st, i, o) stmt = match stmt with 
        | Read x -> (match i with
            | z::tail -> (Expr.update x z st, tail, o)
            | _ -> failwith "fail read")
        | Write e -> (st, i, o@[Expr.eval st e])
        | Assign (x, e) -> (Expr.update x (Expr.eval st e) st, i, o)
        | Seq (l, r) -> eval (eval (st, i, o) l) r
                                                         
  end

(* The top-level definitions *)

(* The top-level syntax category is statement *)
type t = Stmt.t    

(* Top-level evaluator

     eval : int list -> t -> int list

   Takes a program and its input stream, and returns the output stream
*)

let eval i p =
  let _, _, o = Stmt.eval (Expr.empty, i, []) p in o
