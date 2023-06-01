open Test

open ReSon

let assertEq = (a, b, ~message, ~operator) => assertion((a, b) => a == b, a, b, ~message, ~operator)

test("pure", () => {
  assertEq(pure(0), Ok(0), ~message="should give Ok(val)", ~operator="pure")
})

test("apply", () => {
  assertEq(
    apply(pure(x => x + 1), pure(0)),
    Ok(1),
    ~message="should apply for pure",
    ~operator="apply",
  )
  assertEq(
    apply(pure(x => x + 1), Error("error")),
    Error("error"),
    ~message="should propagate error",
    ~operator="apply",
  )
  assertEq(
    apply(Error("error"), pure(0)),
    Error("error"),
    ~message="should propagate error",
    ~operator="apply",
  )
})

test("sequence", () => {
  assertEq(
    sequence([pure(0), pure(1)]),
    Ok([0, 1]),
    ~message="should sequence for pure",
    ~operator="sequence",
  )
  assertEq(
    sequence([Ok(0), Error("error")]),
    Error((1, "error")),
    ~message="should propagate error with index",
    ~operator="sequence",
  )
})

test("number", () => {
  assertEq(
    number("0"->Js.Json.parseExn),
    Ok(0.0),
    ~message="should parse number",
    ~operator="number",
  )
  assertEq(
    number("\"a\""->Js.Json.parseExn),
    Error(NotNumber),
    ~message="should report not a number",
    ~operator="number",
  )
})

test("string", () => {
  assertEq(
    string("\"a\""->Js.Json.parseExn),
    Ok("a"),
    ~message="should parse string",
    ~operator="string",
  )
  assertEq(
    string("0"->Js.Json.parseExn),
    Error(NotString),
    ~message="should report not a string",
    ~operator="string",
  )
})

test("boolean", () => {
  assertEq(
    boolean("true"->Js.Json.parseExn),
    Ok(true),
    ~message="should parse boolean",
    ~operator="boolean",
  )
  assertEq(
    boolean("false"->Js.Json.parseExn),
    Ok(false),
    ~message="should parse boolean",
    ~operator="boolean",
  )
  assertEq(
    boolean("0"->Js.Json.parseExn),
    Error(NotBoolean),
    ~message="should report not a boolean",
    ~operator="boolean",
  )
})

test("object", () => {
  let result: Js.Dict.t<Js.Json.t> = Js.Dict.empty()
  assertEq(
    "{}"->Js.Json.parseExn->object,
    Ok(result),
    ~message="should parse empty object",
    ~operator="object",
  )
  assertEq(
    "false"->Js.Json.parseExn->object,
    Error(NotObject),
    ~message="should report not an object",
    ~operator="object",
  )
})

test("nullable", () => {
  assertEq(
    Js.Json.parseExn("null")->nullable(number, _),
    Ok(None),
    ~message="should parse null",
    ~operator="nullable",
  )
  assertEq(
    "0"->Js.Json.parseExn->nullable(number, _),
    Ok(Some(0.0)),
    ~message="should report not null",
    ~operator="nullable",
  )
})

test("with", () => {
  let p = string->with(s =>
    switch s {
    | "a" => pure(#a)
    | "b" => pure(#b)
    | _ => Error(Custom("not a or b"))
    }
  )
  assertEq("\"a\""->Js.Json.parseExn->p, Ok(#a), ~message="should parse a", ~operator="with")
  assertEq(`"b"`->Js.Json.parseExn->p, Ok(#b), ~message="should parse b", ~operator="with")
  assertEq(
    `"c"`->Js.Json.parseExn->p,
    Error(Custom("not a or b")),
    ~message="should report not a or b",
    ~operator="with",
  )
})

test("map", () => {
  let p = number->map(n => n +. 1.0)
  assertEq("0"->Js.Json.parseExn->p, Ok(1.0), ~message="should map", ~operator="map")
})

test("field", () => {
  let p = object->with(obj => {
    pure((a, b) => (a, b))->apply(obj->field("a", string))->apply(obj->field("b", number))
  })
  assertEq(
    `{"a": "string", "b": 0}`->Js.Json.parseExn->p,
    Ok(("string", 0.0)),
    ~message="should access fields and parse",
    ~operator="field",
  )
  assertEq(
    `{"a": "string"}`->Js.Json.parseExn->p,
    Error(MissingField("b")),
    ~message="should report missing field",
    ~operator="field",
  )
})

test("optional", () => {
  let p = object->with(obj => {
    pure((a, b) => (a, b))->apply(obj->field("a", string))->apply(obj->optional("b", number))
  })
  assertEq(
    `{"a": "string", "b": 0}`->Js.Json.parseExn->p,
    Ok(("string", Some(0.0))),
    ~message="should access fields and parse",
    ~operator="optional",
  )
  assertEq(
    `{"a": "string"}`->Js.Json.parseExn->p,
    Ok(("string", None)),
    ~message="should put None instead of optional",
    ~operator="optional",
  )
})

type sumType = OfFloat(float) | OfString(string) | OfBool(bool)

test("or", () => {
  let of_float = number->map(n => OfFloat(n))
  let of_string = string->map(s => OfString(s))
  let of_bool = boolean->map(b => OfBool(b))
  let p = of_float->or(of_string)->or(of_bool)
  assertEq(
    "0"->Js.Json.parseExn->p,
    Ok(OfFloat(0.0)),
    ~message="should parse float",
    ~operator="or",
  )
  assertEq(
    `"a"`->Js.Json.parseExn->p,
    Ok(OfString("a")),
    ~message="should parse string",
    ~operator="or",
  )
  assertEq(
    "true"->Js.Json.parseExn->p,
    Ok(OfBool(true)),
    ~message="should parse boolean",
    ~operator="or",
  )
})

test("array", () => {
  let p = array(number)
  assertEq(
    "[0, 1, 2]"->Js.Json.parseExn->p,
    Ok([0.0, 1.0, 2.0]),
    ~message="should parse array",
    ~operator="array",
  )
  assertEq(
    "0"->Js.Json.parseExn->p,
    Error(NotArray),
    ~message="should report not an array",
    ~operator="array",
  )
  assertEq(
    "[0, false, 2]"->Js.Json.parseExn->p,
    Error(ArrayItem(1, NotNumber)),
    ~message="should report not a number and index",
    ~operator="array",
  )
})

test("initParse", () => {
  let resultGood = Ok(0.0->Js.Json.number)
  assertEq(
    "0"->initParse,
    resultGood,
    ~message="should wrap in Ok(Js.Json.t)",
    ~operator="initParse",
  )
  assertEq(
    "{"->initParse,
    Error(NotJSON),
    ~message="should report invalid json",
    ~operator="initParse",
  )
})

test("tuple2", () => {
  let p = tuple2(number, string)
  assertEq(
    "[0, \"a\"]"->Js.Json.parseExn->p,
    Ok((0.0, "a")),
    ~message="should parse tuple2",
    ~operator="tuple2",
  )
  assertEq(
    "0"->Js.Json.parseExn->p,
    Error(NotTuple2),
    ~message="should report not a tuple2",
    ~operator="tuple2",
  )
  assertEq(
    "[0, false]"->Js.Json.parseExn->p,
    Error(Tuple2(1, NotString)),
    ~message="should report not a string and index",
    ~operator="tuple2",
  )

  assertEq(
    "[0]"->Js.Json.parseExn->p,
    Error(NotTuple2),
    ~message="should report not a string and index",
    ~operator="tuple2",
  )

  assertEq(
    "[0, 0, 0]"->Js.Json.parseExn->p,
    Error(NotTuple2),
    ~message="should report not a string and index",
    ~operator="tuple2",
  )
})

test("tuple3", () => {
  let p = tuple3(number, string, boolean)
  assertEq(
    "[0, \"a\", true]"->Js.Json.parseExn->p,
    Ok((0.0, "a", true)),
    ~message="should parse tuple3",
    ~operator="tuple3",
  )
  assertEq(
    "0"->Js.Json.parseExn->p,
    Error(NotTuple3),
    ~message="should report not a tuple3",
    ~operator="tuple3",
  )
  assertEq(
    "[0, false, true]"->Js.Json.parseExn->p,
    Error(Tuple3(1, NotString)),
    ~message="should report not a string and index",
    ~operator="tuple3",
  )

  assertEq(
    "[0, \"a\"]"->Js.Json.parseExn->p,
    Error(NotTuple3),
    ~message="should report not a tuple3",
    ~operator="tuple3",
  )

  assertEq(
    "[0, \"a\", true, 0]"->Js.Json.parseExn->p,
    Error(NotTuple3),
    ~message="should report not a tuple3",
    ~operator="tuple3",
  )
})

test("tuple4", () => {
  let p = tuple4(number, string, boolean, number)
  assertEq(
    "[0, \"a\", true, 0]"->Js.Json.parseExn->p,
    Ok((0.0, "a", true, 0.0)),
    ~message="should parse tuple4",
    ~operator="tuple4",
  )
  assertEq(
    "0"->Js.Json.parseExn->p,
    Error(NotTuple4),
    ~message="should report not a tuple4",
    ~operator="tuple4",
  )
  assertEq(
    "[0, false, true, 0]"->Js.Json.parseExn->p,
    Error(Tuple4(1, NotString)),
    ~message="should report not a string and index",
    ~operator="tuple4",
  )

  assertEq(
    "[0, \"a\", true]"->Js.Json.parseExn->p,
    Error(NotTuple4),
    ~message="should report not a tuple4",
    ~operator="tuple4",
  )

  assertEq(
    "[0, \"a\", true, 0, 0]"->Js.Json.parseExn->p,
    Error(NotTuple4),
    ~message="should report not a tuple4",
    ~operator="tuple4",
  )
})

test("tuple5", () => {
  let p = tuple5(number, string, boolean, number, string)
  assertEq(
    "[0, \"a\", true, 0, \"a\"]"->Js.Json.parseExn->p,
    Ok((0.0, "a", true, 0.0, "a")),
    ~message="should parse tuple5",
    ~operator="tuple5",
  )
  assertEq(
    "0"->Js.Json.parseExn->p,
    Error(NotTuple5),
    ~message="should report not a tuple5",
    ~operator="tuple5",
  )
  assertEq(
    "[0, false, true, 0, \"a\"]"->Js.Json.parseExn->p,
    Error(Tuple5(1, NotString)),
    ~message="should report not a string and index",
    ~operator="tuple5",
  )

  assertEq(
    "[0, \"a\", true, 0]"->Js.Json.parseExn->p,
    Error(NotTuple5),
    ~message="should report not a tuple5",
    ~operator="tuple5",
  )

  assertEq(
    "[0, \"a\", true, 0, \"a\", 0]"->Js.Json.parseExn->p,
    Error(NotTuple5),
    ~message="should report not a tuple5",
    ~operator="tuple5",
  )
})

test("printError", () => {
  assertEq(NotArray->printError, "Not an array", ~message="Not an Array", ~operator="error")
  assertEq(NotJSON->printError, "Not a JSON", ~message="Not JSON", ~operator="error")
  assertEq(NotNumber->printError, "Not a number", ~message="Not a number", ~operator="error")
  assertEq(NotString->printError, "Not a string", ~message="Not a string", ~operator="error")
  assertEq(NotTuple2->printError, "Not a tuple2", ~message="Not a tuple2", ~operator="error")
  assertEq(NotTuple3->printError, "Not a tuple3", ~message="Not a tuple3", ~operator="error")
  assertEq(NotTuple4->printError, "Not a tuple4", ~message="Not a tuple4", ~operator="error")
  assertEq(NotTuple5->printError, "Not a tuple5", ~message="Not a tuple5", ~operator="error")
  assertEq(
    MissingField("a")->printError,
    "Missing field \"a\"",
    ~message="Missing field",
    ~operator="error",
  )
  assertEq(
    Tuple2(0, NotString)->printError,
    "Tuple2 item 0: Not a string",
    ~message="Tuple2 error",
    ~operator="error",
  )
  assertEq(
    Tuple3(0, NotString)->printError,
    "Tuple3 item 0: Not a string",
    ~message="Tuple3 error",
    ~operator="error",
  )
  assertEq(
    Tuple4(0, NotString)->printError,
    "Tuple4 item 0: Not a string",
    ~message="Tuple4 error",
    ~operator="error",
  )
  assertEq(
    Tuple5(0, NotString)->printError,
    "Tuple5 item 0: Not a string",
    ~message="Tuple5 error",
    ~operator="error",
  )
  assertEq(
    Nor(NotString, NotNumber)->printError,
    "These cases have failed: \n - Not a string \n - Not a number",
    ~message="Nor",
    ~operator="error",
  )
  assertEq(
    ArrayItem(0, NotString)->printError,
    "Array item 0: Not a string",
    ~message="ArrayItem",
    ~operator="error",
  )
  assertEq(
    Field("a", NotString)->printError,
    "Error on path [a]: Not a string",
    ~message="Field",
    ~operator="error",
  )
  assertEq(
    Field("a", Field("b", NotString))->printError,
    "Error on path [a.b]: Not a string",
    ~message="Field",
    ~operator="error",
  )
  assertEq(
    Field("a", Field("b", ArrayItem(3, NotString)))->printError,
    "Error on path [a.b.3]: Not a string",
    ~message="Field",
    ~operator="error",
  )
})
