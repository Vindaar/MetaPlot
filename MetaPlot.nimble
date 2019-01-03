# Package

version       = "0.1.0"
author        = "Vindaar"
description   = "An experimental plotting wrapper targeting JSON based libs w/ CT schema checking"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["MetaPlot"]


# Dependencies

requires "nim >= 0.19.9"
requires "plotly"
requires "https://github.com/numforge/monocle/"
requires "https://github.com/vindaar/JsonSchemaValidator"

task buildCheck, "Build the schema checker":
  exec "nim c -d:release -r checkSchema.nim"
