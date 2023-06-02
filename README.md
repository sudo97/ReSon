# ReSon

ReSon is a ReScript library that provides a convenient way to parse JSON data in a type-safe manner. Inspired by the classify approach described in the ReScript documentation and libraries like aeson, ReSon aims to simplify the process of parsing and validating JSON structures.

## Features
- Type-safe parsing of JSON data
- Error handling for invalid JSON and data types
- Support for parsing nested objects, arrays, and tuples
- Optional and nullable field handling
- Composable parsing combinators for building complex parsers

## Installation
1. Get it from npm
```
npm install --save reson
```
2. Update bscofig.json's "bs-dependencies"
```json
  "bs-dependenncies": ["ReSon"]
```

## Usage
It all wraps around ReSon.t, which is
```res
type t<'a> = result<'a, error>
```
Where error is the following:
```res
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
```

There are several primitives that are available:
```res
    let number: Js.Json.t => t<float>
    let string: Js.Json.t => t<string>
    let boolean: Js.Json.t => t<bool>
    let object: Js.Json.t => t<Js.Dict.t<Js.Json.t>>

    let initParse: string => t<Js.Json.t>
```

### Example
```res
    // This will print "34"
    let s = `34`
    let x = initParse(s)->Result.flatMap(number)
    switch x {
    | Ok(x) => Js.log(x)
    | Error(e) => Js.log(e->printError)
    }
```
There's an error type which can be pretty-printed
```res
    // This will print "Not a number"
    let s = `false`
    let x = initParse(s)->Result.flatMap(number)
    switch x {
    | Ok(x) => Js.log(x)
    | Error(e) => Js.log(e->printError)
    }
```

### Combining parsers together
There are also few helper functions, that allow combining, and updating existing parsers.
```res
    // allows any other parser to accept null as possible value
    let nullable: (Js.Json.t => t<'a>, Js.Json.t) => t<option<'a>>
    // parses items of array with given parses
    let array: (Js.Json.t => t<'a>, Js.Json.t) => t<array<'a>>

    // Just a wrapper around Result.map so that parsed result can be updated
    let map: ('a => t<'b>, 'b => 'd, 'a) => t<'d>

    // to parse results of parse, a wrapper around Result.flatMap, see examples below
    let with: (Js.Json.t => t<'b>, 'b => t<'c>, Js.Json.t) => t<'c>
    // to be used with(object), see example
    let field: (Js.Dict.t<Js.Json.t>, string, Js.Json.t => t<'a>) => t<'a>
    // Same as field, but allows field to not exist
    let optional: (Js.Dict.t<Js.Json.t>, string, Js.Json.t => t<'a>) => t<option<'a>>

    // Parses json arrays like [false, 13] into pair.
    // there are tuple2, tuple3, tuple4, and tuple5
    let tuple2: ( Js.Json.t => result<'a, error>, Js.Json.t => result<'b, error>, Js.Json.t,) => t<('a, 'b)>
```

### Example
```res
type myType = {
  key: float,
  otherKey: string,
  optional: option<string>,
}

// recommend to create constructor function
let make = (key, otherKey, optional) => {key, otherKey, optional}

let s = `{"key": 1, "otherKey": "some text here"}`

let p = with(object)(obj => {
  pure(make)
  ->apply(obj->field("key", number))
  ->apply(obj->field("otherKey", string))
  ->apply(obj->optional("optional", string))
})

// will print `{ key: 1, otherKey: 'some text here', optional: undefined }`
switch initParse(s)->Result.flatMap(p) {
| Ok(x) => Js.log(x)
| Error(e) => Js.log(e->printError)
}

let s = `{}`

// will print `Missing field "key"`
switch initParse(s)->Result.flatMap(p) {
| Ok(x) => Js.log(x)
| Error(e) => Js.log(e->printError)
}

let s = `{"key": "not a number"}`
// will print `Error on path [key]: Not a number`
switch initParse(s)->Result.flatMap(p) {
| Ok(x) => Js.log(x)
| Error(e) => Js.log(e->printError)
}

type nested = {key: float}
type withNested = {nested: nested}

let makeNested = key => {key}
let make = nested => {nested}

let s = `{"nested": {
  "key": "not a number"
}}`

let parseNested = with(object)(obj => {
  pure(key => {key})->apply(field(obj, "key", number))
})

let p = with(object)(obj => {
  pure(make)->apply(field(obj, "nested", parseNested))
})

// will print Error on path [nested.key]: Not a number
//                           ^ so nested path really looks cool
switch initParse(s)->Result.flatMap(p) {
| Ok(x) => Js.log(x)
| Error(e) => Js.log(e->printError)
}

```

## Sum types
There are situations when there can be some sort of variation:
```ts
  // In Ts we would say that
  type T = number | string
```
Idiomatic way of expressing it in ReScript would be something like this:
```res
  type t = OfFloat(float) | OfString(string)
```

Parser for such type can be constructed by using `or` helper function.
```res
let parseOfFloat = number->map(x => OfFloat(x))
let parseOfString = string->map(x => OfString(x))

let parseSumType = parseOfFloat->or(parseOfString)
```

Another typical situation is when in TS we would say
```ts
  type T = "tag1" | "tag2"
```

And in ReScript we usually express it like:
```res
  type t = [#tag1 | #tag2]
```

To parse such type I suggest using this little patternn:
```res
  let p = with(string)(s => switch s {
    | "tag1" => Ok(#tag1)
    | "tag2" => Ok(#tag2)
    | _ => Error(Custom("Unknown tag " ++ s))
  })
```

# The End

For further details I sugges taking a look at test cases or the src, it's just ~200 lines of code. If you think there's a way to improve the way these functions are interacted with on the surface, I'll hear you out in Issues. 