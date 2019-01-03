import osproc, tables, sets, strutils, parsecsv
import macros, json #jsmn#packedjson
import plotly
import monocle

import schemaValidator

## a macro to build plotly (and potentially other JSON based
## plotting schemas) with type checking at compile time

const SpecialKeys = { "trace" : "traces",
                      "scatter": "traces scatter attributes",
                      "layout" : "layout layoutAttributes" }.toTable

const TypeKeys = toSet(["scatter"])

# keys, which are not checked
const ExceptionKeys = toSet(["xaxis", "yaxis"])

proc checkKey(backend: string, key: string): bool {.compileTime.} =
  # checks if given key exists in schema
  #var xyz = ""
  #if parent == "traces":
  #  xyz = key & " attributes"
  case backend
  of "plotly":
    echo "Call for ", key
    echo "./checkSchema " & $backend & " " & $key
    if staticExec("./checkSchema " & $backend & " " & $key) == "true":
      result = true
    else:
      result = false
  of "vega":
    result = true

proc checkVega(data: string): bool {.compileTime.} =
  var shellJson = quoteShell(data)
  echo "SCHEMA CALL: ", data
  let res = staticExec("./checkSchema vega " & shellJson)
  echo "Res is ", res
  result = if res == "true":
      true
    else:
      false

proc traverse(backend: string, n: NimNode, keyP = ""): NimNode {.discardable.} =
  result = nnkTableConstr.newTree()
  var keyPrefix: string = keyP
  var keys: seq[string]
  #echo n.treeRepr
  if not checkKey(backend, $keyPrefix):
    # check after stripping numbers
    # TODO: check for Exception key first!
    let chck = keyPrefix.strip(chars = {'0' .. '9'})
    echo "CHCK IS ", chck, " FFOR ", n.repr
    if chck.splitWhitespace[^1] in ExceptionKeys and not checkKey(backend, chck):
      error("Invalid key: " & n[0].repr)
    else:
      keyPrefix = chck

  for k in n[1]:
    case k.kind
    of nnkCall:
      # call itself
      var newPrefix = ""
      if k[0].repr in SpecialKeys:
        newPrefix = keyPrefix
      else:
        newPrefix = keyPrefix & " " & $k[0]

      result.add nnkExprColonExpr.newTree(k[0].toStrLit,
                                          traverse(backend, k, keyP = newPrefix))

    of nnkAsgn:
      #echo "Check existence of ", k[0].repr
      #echo k.treeRepr
      echo "Assign ", k.repr, "   ", $keyPrefix & " " & $k[0]
      if checkKey(backend, $keyPrefix & " " & $k[0]):
        case k[0].kind
        of nnkIdent:
          result.add nnkExprColonExpr.newTree(k[0].toStrLit,
                                              k[1]) #traverse(k, keyPrefix = newPrefix))
        of nnkAccQuoted:
          result.add nnkExprColonExpr.newTree(k[0][0].toStrLit,
                                              k[1]) #traverse(k, keyPrefix = newPrefix))
        of nnkStrLit:
          result.add nnkExprColonExpr.newTree(k[0],
                                              k[1]) #traverse(k, keyPrefix = newPrefix))
        else:
          error("Unsupported type " & $k[0].repr)
      else:
        error("Invalid key: " & k.repr)
    else:
      echo "Unsupported too ", k.kind, " : ", k.repr
  echo "REAUSLT ", result.treeRepr

macro build(backend: static string, stmts: untyped): untyped =
  let Plotly = if backend == "plotly": true else: false
  echo stmts.repr

  var keys: seq[string]
  echo "Result ", staticExec("./checkSchema schema traces")

  var tree = nnkTableConstr.newTree()
  for k in stmts:
    # check the key for existence
    echo "is ", k[0].repr
    #echo checkKey(backend, k[0].repr)
    case k.kind
    of nnkCall:
      if k[0].repr in SpecialKeys:
        tree.add nnkExprColonExpr.newTree(k[0].toStrLit,
                                          traverse(backend, k, SpecialKeys[k[0].repr]))
        # traverse(k, SpecialKeys[k[0].repr])
      else:
        tree.add nnkExprColonExpr.newTree(k[0].toStrLit,
                                          traverse(backend, k, k[0].repr))
        #traverse(k)
    of nnkAsgn:
      tree.add nnkExprColonExpr.newTree(k[0].toStrLit,
                                        k[1])
    else:
      echo "unsupported ", k.kind

  # first get possible traces
  # get layout
  # combine traces
  # make `PlotJson` from both
  #result =
  # we now know we have a valid tree. Replace `TypeKeys` at top level
  var traces: seq[NimNode]
  var finalTree = nnkTableConstr.newTree()
  for i, k in tree:
    if $k[0] in TypeKeys:
      var tr = k[1]
      tr.add nnkExprColonExpr.newTree(newLit("type"), k[0])
      traces.add tr
    else:
      finalTree.add k

  echo "Traces ", traces.repr
  if Plotly:
    let trIdent = ident"traces"
    let lyIdent = ident"layout"
    let trJson = quote do:
      let `trIdent` = %* `traces`
    let lyJson = quote do:
      var `lyIdent` = %* `finalTree`
      `lyIdent` = `lyIdent`["layout"]
    echo "Final result: ", finalTree.treeRepr
    echo finalTree.repr
    result = quote do:
      # echo (%* `finalTree`).pretty
      `trJson`
      `lyJson`
      echo `trIdent`.pretty
      echo `lyIdent`.pretty
  else:
    let vegaIdent = ident"vega"

    echo "aaaa ", checkVega($tree.toStrLit)

    result = quote do:
      echo (%* `tree`).pretty
      let `vegaIdent` = %* `tree`

  echo result.repr

when isMainModule:

  let someData = [3, 4, 7]

  build("plotly"):
    scatter:
      x = someData
      y = [4, 5, 6]
      marker:
        size = 5
      name = "Oh a name!"
    scatter:
      x = [20, 30, 40]
      y = [50, 60, 70]
      xaxis = "x2"
      yaxis = "y2"
    layout:
      title = "simple subplot!"
      grid:
        rows = 1
        columns = 2
        pattern = "independent"

  let plt = PlotJson(traces: traces,
                     layout: layout)
  plt.show()

  #build("plotly"):
  #  scatter:
  #    x = [1, 2]
  #    y = [1, 2]
  #    name = "(1,1)"
  #
  #  scatter:
  #    x = [1, 2]
  #    y = [1, 2]
  #    name = "(1,2)"
  #    xaxis = "x2"
  #    yaxis = "y2"
  #
  #  scatter:
  #    x = [1, 2]
  #    y = [1, 2]
  #    name = "(1,2)"
  #    xaxis = "x3"
  #    yaxis = "y3"
  #
  #  scatter:
  #    x = [1, 2]
  #    y = [1, 2]
  #    name = "(1,2)"
  #    xaxis = "x4"
  #    yaxis = "y4"
  #
  #  layout:
  #    title = "Mulitple Custom Sized Subplots"
  #    xaxis:
  #      domain = [0, 0.45]
  #      anchor = "y1"
  #
  #    yaxis:
  #      domain = [0.5, 1]
  #      anchor = "x1"
  #
  #    xaxis2:
  #      domain = [0.55, 1]
  #      anchor = "y2"
  #
  #    yaxis2:
  #      domain = [0.8, 1]
  #      anchor = "x2"
  #
  #    xaxis3:
  #      domain = [0.55, 1]
  #      anchor = "y3"
  #
  #    yaxis3:
  #      domain = [0.5, 0.75]
  #      anchor = "x3"
  #
  #    xaxis4:
  #      domain = [0, 1]
  #      anchor = "y4"
  #
  #    yaxis4:
  #      domain = [0, 0.45]
  #      anchor = "x4"

  ## Vega Lite example:
  #const vegaData = staticRead("seattle-weather.csv").splitLines
  var p: CsvParser
  p.open("seattle-weather.csv")
  p.readHeaderRow()
  var vegaData = newJArray()
  while p.readRow():
    echo "new row: "
    var row = newJObject()
    for col in items(p.headers):
      echo "##", col, ":", p.rowEntry(col), "##"
      if col != "weather" and col != "date":
        row[col] = (% (p.rowEntry(col).parseFloat))
      else:
        row[col] = (% p.rowEntry(col))
    vegaData.add row

  p.close()
  # echo vegaData.pretty

  let vegaMoreData = """{
    "data": {"url": "data/seattle-weather.csv"},
    "mark": "bar",
    "encoding": {
      "x": {
        "timeUnit": "month",
        "field": "date",
        "type": "ordinal",
        "axis": {"title": "Month of the year"}
      },
      "y": {
        "aggregate": "count",
        "type": "quantitative"
      },
      "color": {
        "field": "weather",
        "type": "nominal",
        "scale": {
          "domain": ["sun","fog","drizzle","rain","snow"],
          "range": ["#e7ba52","#c7c7c7","#aec7e8","#1f77b4","#9467bd"]
        },
        "legend": {"title": "Weather type"}
      }
    }
  }"""

  #let contentVega = readFile("resources/vegaLitev3.json")
  #let vegaSchema = parseJson(contentVega)
  #echo validate(vegaSchema, vegaMoreData.parseJson)

  build("vega"):
    data:
      values = vegaData
      #url = "seattle-weather.csv"
      format = "csv"
    mark = "bar"
    encoding:
      x:
        timeUnit = "month"
        field = "date"
        `type` = "ordinal"
        axis:
          title = "Month of the year"
      y:
        aggregate = "count"
        `type` = "quantitative"
      color:
        field = "weather"
        `type` = "nominal"
        scale:
          domain = ["sun","fog","drizzle","rain","snow"]
          range = ["#e7ba52","#c7c7c7","#aec7e8","#1f77b4","#9467bd"]
        legend:
          title = "Weather type"

  #var f = open("vegaTest.json", fmWrite)
  #f.write(vega.pretty)
  #f.close()

  echo vega.pretty
  monocle.show(vega)
