open Base
;;

let numpy, numpy_measure =
  let lin_reg_bytecode =
    Python_compile.f `Exec ~optimize:`Normal ~filename:"lin_reg.py" ~source:"
import gc
import resource
import numpy as np
from numpy.linalg import inv, lstsq

def lin_reg(x, y):
    return np.dot(np.dot(inv(np.dot(x.T, x)), x.T), y)

def measure(x, y):
    gc.collect()
    start = resource.getrusage(resource.RUSAGE_SELF).ru_utime
    result = lin_reg(x, y)
    end = resource.getrusage(resource.RUSAGE_SELF).ru_utime
    return ((end - start) * 1000000.0)
" in
  let lin_reg_module = Py.Import.exec_code_module "lin_reg" lin_reg_bytecode in
  let measure = Py.Module.get_function lin_reg_module "measure" in
  let lin_reg = Py.Module.get_function lin_reg_module "lin_reg" in
  lin_reg, measure
;;

let numpy ~x ~y =
  [| x; y |]
  |> Array.map ~f:Numpy.of_bigarray
  |> numpy
  |> Numpy.to_bigarray Bigarray.float64 Bigarray.c_layout
;;

let numpy_measure ~x ~y =
  [| x; y |]
  |> Array.map ~f:Numpy.of_bigarray
  |> numpy_measure
  |> Py.Float.to_float
;;

let owl ~x ~y =
  let open Owl.Mat in
  let ( * ) = dot in
  let x' = transpose x in
  inv (x' * x) * x' * y
;;

let numlin ~x ~y =
  Gen.Lin_reg.it (M x) (M y)
;;

(* Uniform interface *)
type o_mat =
  Owl.Mat.mat
;;

type 'a l_mat =
  'a Numlin.Template.mat
;;

type l_z =
  Numlin.Template.z
;;

type 'a from_input =
  x:o_mat -> y:o_mat -> 'a
;;

type numlin =
  { f : 'a 'b.  (('a l_mat * 'b l_mat) * l_z l_mat) from_input }
;;

type _ t =
  | Owl : o_mat from_input t
  | NumLin : numlin t
  | NumPy : (float from_input * o_mat from_input) t
;;

type wrap =
  | W : _ t -> wrap
[@@ocaml.unboxed]
;;

let get : type a . a t -> a = function
  | Owl -> owl
  | NumLin -> { f = numlin }
  | NumPy -> (numpy_measure, numpy)
;;

let name : wrap -> string = function
  | W Owl -> "Owl"
  | W NumLin -> "NumLin"
  | W NumPy -> "NumPy"
;;

let all =
  [ W NumPy; W Owl; W NumLin]
;;
