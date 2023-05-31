type rec error =
  | NotJSON
  | NotNumber
  | NotString
  | NotBoolean
  | NotArray
  | NotObject
  | MissingField(string)
  | Field(string, error)
  | ArrayItem(int, error)
  | Nor(error, error)
  | NotTuple2
  | Tuple2(int, error)
  | NotTuple3
  | Tuple3(int, error)
  | NotTuple4
  | Tuple4(int, error)
  | NotTuple5
  | Tuple5(int, error)
  | Custom(string)

let rec printError = (e: error) => {
  let rec printField = (e: error, acc: string) => {
    switch e {
    | Field(key, e') => printField(e', `${acc}.${key}`)
    | ArrayItem(i, e) => printField(e, `${acc}.${i->Int.toString}`)
    | _ => `${acc}]: ${printError(e)}`
    }
  }
  switch e {
  | NotJSON => "Not a JSON"
  | NotNumber => "Not a number"
  | NotString => "Not a string"
  | NotBoolean => "Not a boolean"
  | NotArray => "Not an array"
  | NotObject => "Not an object"
  | MissingField(key) => `Missing field "${key}"`
  | Field(key, e) => `Error on path [${printField(e, key)}`
  | ArrayItem(i, e) => `Array item ${i->Int.toString}: ${printError(e)}`
  | Nor(e1, e2) => `These cases have failed: \n - ${e1->printError} \n - ${e2->printError}`
  | NotTuple2 => "Not a tuple2"
  | Tuple2(i, e) => `Tuple2 item ${i->Int.toString}: ${printError(e)}`
  | NotTuple3 => "Not a tuple3"
  | Tuple3(i, e) => `Tuple3 item ${i->Int.toString}: ${printError(e)}`
  | NotTuple4 => "Not a tuple4"
  | Tuple4(i, e) => `Tuple4 item ${i->Int.toString}: ${printError(e)}`
  | NotTuple5 => "Not a tuple5"
  | Tuple5(i, e) => `Tuple5 item ${i->Int.toString}: ${printError(e)}`
  | Custom(s) => s
  }
}

type t<'a> = result<'a, error>

let pure = x => Ok(x)

let apply = (f, x) =>
  switch (f, x) {
  | (Ok(f), Ok(x)) => Ok(f(x))
  | (Error(e), _) => Error(e)
  | (_, Error(e)) => Error(e)
  }

let sequence = (xs: array<result<'a, 'b>>): result<array<'a>, (int, 'b)> => {
  xs->Js.Array2.reducei((acc, curr, i) =>
    switch (acc, curr) {
    | (Ok(acc), Ok(curr)) => {
        acc->Js.Array2.push(curr)->ignore
        Ok(acc)
      }
    | (Error(e), _) => Error(e)
    | (_, Error(e)) => Error((i, e))
    }
  , Ok([]))
}

let map = (p, f, json) => json->p->Result.map(f)

let or = (p1: Js.Json.t => t<'a>, p2: Js.Json.t => t<'a>, json) =>
  switch p1(json) {
  | Error(e) =>
    switch p2(json) {
    | Error(e2) => Error(Nor(e, e2))
    | x => x
    }
  | x => x
  }

let number = (json: Js.Json.t): t<float> =>
  switch Js.Json.classify(json) {
  | Js.Json.JSONNumber(n) => Ok(n)
  | _ => Error(NotNumber)
  }

let string = (json: Js.Json.t): t<string> =>
  switch Js.Json.classify(json) {
  | Js.Json.JSONString(s) => Ok(s)
  | _ => Error(NotString)
  }

let boolean = (json: Js.Json.t): t<bool> =>
  switch Js.Json.classify(json) {
  | Js.Json.JSONFalse => Ok(false)
  | Js.Json.JSONTrue => Ok(true)
  | _ => Error(NotBoolean)
  }

let flatMap = (a, b, json) => json->a->Result.flatMap(b)

let array = (p: Js.Json.t => t<'a>, json: Js.Json.t): t<array<'a>> =>
  switch Js.Json.classify(json) {
  | Js.Json.JSONArray(a) =>
    switch a->Js.Array2.map(p)->sequence {
    | Ok(x) => Ok(x)
    | Error((i, e)) => Error(ArrayItem(i, e))
    }
  | _ => Error(NotArray)
  }

let nullable = (p: Js.Json.t => t<'a>, json: Js.Json.t): t<option<'a>> =>
  switch Js.Json.classify(json) {
  | Js.Json.JSONNull => Ok(None)
  | _ => p(json)->Result.map(x => Some(x))
  }

let object = (json: Js.Json.t): t<Js.Dict.t<Js.Json.t>> =>
  switch Js.Json.classify(json) {
  | Js.Json.JSONObject(o) => Ok(o)
  | _ => Error(NotObject)
  }

let field = (obj: Js.Dict.t<Js.Json.t>, key: string, p: Js.Json.t => t<'a>): t<'a> =>
  switch Js.Dict.get(obj, key) {
  | Some(value) =>
    switch Ok(value)->Result.flatMap(p) {
    | Ok(x) => Ok(x)
    | Error(e) => Error(Field(key, e))
    }
  | None => Error(MissingField(key))
  }

let optional = (obj, k, p) =>
  switch obj->Js.Dict.get(k) {
  | Some(allies) => p(allies)->Result.map(x => Some(x))
  | None => Ok(None)
  }

let tuple2 = (p1, p2, json) =>
  switch Js.Json.classify(json) {
  | Js.Json.JSONArray(a) =>
    switch a {
    | [x, y] if a->Js.Array2.length == 2 =>
      switch (p1(x), p2(y)) {
      | (Ok(x), Ok(y)) => Ok((x, y))
      | (Error(e), _) => Error(Tuple2(0, e))
      | (_, Error(e)) => Error(Tuple2(1, e))
      }
    | _ => Error(NotTuple2)
    }
  | _ => Error(NotTuple2)
  }

let tuple3 = (p1, p2, p3, json) =>
  switch Js.Json.classify(json) {
  | Js.Json.JSONArray(a) =>
    switch a {
    | [x, y, z] if a->Js.Array2.length == 3 =>
      switch (p1(x), p2(y), p3(z)) {
      | (Ok(x), Ok(y), Ok(z)) => Ok((x, y, z))
      | (Error(e), _, _) => Error(Tuple3(0, e))
      | (_, Error(e), _) => Error(Tuple3(1, e))
      | (_, _, Error(e)) => Error(Tuple3(2, e))
      }
    | _ => Error(NotTuple3)
    }
  | _ => Error(NotTuple3)
  }

let tuple4 = (p1, p2, p3, p4, json) =>
  switch Js.Json.classify(json) {
  | Js.Json.JSONArray(a) =>
    switch a {
    | [x, y, z, w] if a->Js.Array2.length == 4 =>
      switch (p1(x), p2(y), p3(z), p4(w)) {
      | (Ok(x), Ok(y), Ok(z), Ok(w)) => Ok((x, y, z, w))
      | (Error(e), _, _, _) => Error(Tuple4(0, e))
      | (_, Error(e), _, _) => Error(Tuple4(1, e))
      | (_, _, Error(e), _) => Error(Tuple4(2, e))
      | (_, _, _, Error(e)) => Error(Tuple4(3, e))
      }
    | _ => Error(NotTuple4)
    }
  | _ => Error(NotTuple4)
  }

let tuple5 = (p1, p2, p3, p4, p5, json) =>
  switch Js.Json.classify(json) {
  | Js.Json.JSONArray(a) =>
    switch a {
    | [x, y, z, w, v] if a->Js.Array2.length == 5 =>
      switch (p1(x), p2(y), p3(z), p4(w), p5(v)) {
      | (Ok(x), Ok(y), Ok(z), Ok(w), Ok(v)) => Ok((x, y, z, w, v))
      | (Error(e), _, _, _, _) => Error(Tuple5(0, e))
      | (_, Error(e), _, _, _) => Error(Tuple5(1, e))
      | (_, _, Error(e), _, _) => Error(Tuple5(2, e))
      | (_, _, _, Error(e), _) => Error(Tuple5(3, e))
      | (_, _, _, _, Error(e)) => Error(Tuple5(4, e))
      }
    | _ => Error(NotTuple5)
    }
  | _ => Error(NotTuple5)
  }

let initParse = (s): t<Js.Json.t> =>
  try Ok(s->Js.Json.parseExn) catch {
  | _ => Error(NotJSON)
  }
