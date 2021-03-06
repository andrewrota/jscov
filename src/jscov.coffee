fs = require 'fs'
path = require 'path'
_ = require 'underscore'
esprima = require 'esprima'
escodegen = require 'escodegen'
wrench = require 'wrench'
coffee = require 'coffee-script'
tools = require './tools'
estools = require './estools'
conditionals = require './conditionals'
expander = require './expander'
jscoverageFormatting = require './jscoverage-formatting'



isHidden = (filename) -> filename[0] == '.'



writeFile = do ->
  sourceMappings = [
    (x) -> x.replace(/&/g, '&amp;')
    (x) -> x.replace(/</g, '&lt;')
    (x) -> x.replace(/>/g, '&gt;')
    (x) -> x.replace(/\\/g, '\\\\')
    (x) -> x.replace(/"/g, '\\"')
    (x) -> tools.strToNumericEntity(x)
    (x) -> '"' + x + '"'
  ]

  (originalCode, coveredCode, filename, trackedLines, coverageVar) ->

    originalSource = originalCode.split(/\r?\n/g).map (line) -> sourceMappings.reduce(((src, f) -> f(src)), line)
    originalSource = originalSource.slice(0, -1) if _.last(originalSource) == '""'

    output = []
    output.push "/* automatically generated by jscov - do not edit */"
    output.push "if (typeof #{coverageVar} === 'undefined') #{coverageVar} = {};"
    output.push "if (! #{coverageVar}['#{filename}']) {"
    output.push "  #{coverageVar}['#{filename}'] = [];"
    trackedLines.forEach (line) ->
      output.push "  #{coverageVar}['#{filename}'][#{line}] = 0;"
    output.push "}"
    output.push coveredCode
    output.push "#{coverageVar}['#{filename}'].source = [" + originalSource.join(",") + "];"

    output.join('\n') # should maybe windows style line-endings be used here in some cases?



exports.rewriteSource = (code, filename) ->

  injectList = {}
  coverageVar = '_$jscoverage'

  ast = esprima.parse(code, { loc: true })

  jscoverageFormatting.formatTree(ast)

  estools.addBeforeEveryStatement ast, (node) ->
    injectList[node.loc.start.line] = 1
    estools.coverageNode(node, filename, coverageVar)

  jscoverageFormatting.postFormatTree(ast)

  trackedLines = _.sortBy(Object.keys(injectList).map((x) -> parseInt(x, 10)), _.identity)
  outcode = escodegen.generate(ast, { indent: "  " })
  writeFile(code, outcode, filename, trackedLines, coverageVar)


exports.rewriteFile = (sourceFileBase, sourceFile, targetDir, options) ->
  data = fs.readFileSync(path.join(sourceFileBase, sourceFile), 'utf8')
  data = conditionals.expand(data, { lang: (if sourceFile.match(/\.coffee$/) then 'coffee' else 'js') }) if options.conditionals
  data = coffee.compile(data) if sourceFile.match(/\.coffee$/)
  data = expander.expand(data) if options.expand
  output = exports.rewriteSource(data, sourceFile)
  outfile = path.join(targetDir, sourceFile).replace(/\.coffee$/, '.js')
  wrench.mkdirSyncRecursive(path.dirname(outfile))
  fs.writeFileSync(outfile, output, 'utf8')



exports.rewriteFolder = (source, target, options, callback) ->
  errors = []

  try
    if !callback?
      callback = options
      options = {}

    wrench.rmdirSyncRecursive(target, true)

    wrench.readdirSyncRecursive(source).forEach (file) ->
      return if fs.lstatSync(path.join(source, file)).isDirectory() || !file.match(/\.(coffee|js)$/)

      dirs = path.dirname(file).split(path.sep)
      dirs = dirs.slice(1) if dirs[0] == '.'
      return if (dirs.some(isHidden) || isHidden(path.basename(file))) && !options.hidden

      try
        console.log("Rewriting #{source}/#{file} to #{target}...") if options.verbose
        exports.rewriteFile(source, file, target, options)
      catch ex
        errors.push({ file: file, ex: ex })

  catch ex
    callback(ex)
    return

  if errors.length > 0
    failures = _.sortBy(errors, (x) -> x.file).map((x) -> x.file + ": " + (x.ex.message || 'UNKNOWN')).join('\n')
    callback(new Error(failures))
  else
    callback()



exports.cover = (start, dir, file) ->
  path.join(start, process.env.JSCOV || dir, file)
