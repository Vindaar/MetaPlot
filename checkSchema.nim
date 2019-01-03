import json, os, schemaValidator

let contentPlotly = readFile("resources/plotly_schema_reduced.json")
let contentVega = readFile("resources/vegaLitev3.json")
let pltly = parseJson(contentPlotly)
let vega = parseJson(contentVega)

# echo vega.len
# for k, v in pairs(vega):
  # echo "\n\n\n\n\n\n"
  ## echo "k ", k, " and ", v
  # echo "k ", k#, " a ", v.pretty


proc check(node: JsonNode, params: var seq[string]): bool =
  let p = params[0]
  params.delete(0)
  if hasKey(node, p):
    if params.len == 0:
      result = true
    else:
      result = check(node[p], params)
  else:
    result = false

proc topLevelVegaKeys(): seq[string] =
  result = @["TopLevelFacetedUnitSpec",
             "TopLevelFacetSpec",
             "TopLevelLayerSpec",
             "TopLevelRepeatSpec",
             "TopLevelVConcatSpec",
             "TopLevelHConcatSpec"]

proc main(): string =
  let count = paramCount()
  var backend = ""
  if count > 0:
    backend = paramStr(1)
    if backend != "vega" and backend != "plotly":
      quit("Select either vega or plotly schema!")

  if count > 1:
    case backend
    of "vega":
      # validate using JSON schema
      # vega requires parameter 2 to be a string literal of JSON data
      let data = paramStr(2)
      #result.add "Data is " & $data

      let dJson = data.parseJson
      #echo dJson.pretty
      #result.add "VALIDATING"
      #result.add $validate(vega, dJson)
      result = $validate(vega, dJson)

      #let tpkeys = topLevelVegaKeys()
      #let userKeys = deepcopy(keys)
      ## echo "AHA ", userKeys
      #for t in tpkeys:
      #  # echo " t  ", t
      #  keys.insert("properties")
      #  keys.insert(t)
      #  keys.insert("definitions")
      #  # echo "Checking ", keys, "   ", userKeys
      #  result = if check(vega, keys): 1 else: 0
      #  if result == 1:
      #    # echo "Found it in ", t
      #    break
      #  else:
      #    # echo "Resetting ", keys, " to ", userKeys
      #    keys = userKeys
    of "plotly":
      var key: string
      var keys: seq[string]
      for c in 2 .. count:
        keys.add paramStr(c)
      keys.insert("schema")
      # echo "CHecking ", keys
      #result = if check(pltly, keys): 1 else: 0
      result = $check(pltly, keys)
    else:
      quit("Invalid backend!")

stderr.write(main())
