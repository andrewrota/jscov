fs = require 'fs'
should = require 'should'
esprima = require 'esprima'
wrench = require 'wrench'
_ = require 'underscore'
jscov = require '../lib/coverage'

describe "rewriteSource", ->

  wrench.readdirSyncRecursive('spec/scaffold').forEach (filename) ->

    return if fs.lstatSync('spec/scaffold/' + filename).isDirectory()

    code = fs.readFileSync('spec/scaffold/' + filename, 'utf8')
    newCode = jscov.rewriteSource(code, filename)
    actualParse = esprima.parse(newCode)

    expect = fs.readFileSync('spec/expect/' + filename, 'utf8')
    expectedParse = esprima.parse(expect)

    it "should parse #{filename} the same way as jscoverage", ->
      _.isEqual(actualParse, expectedParse).should.be.true


  it "should throw an exception if the source is not valid", ->
    f = ->
      jscov.rewriteSource("console.log 'test'")
    f.should.throw()



describe "rewriteFolder", ->

  it "should rewrite entire folders recursively", (done) ->

    wrench.rmdirSyncRecursive('spec/scaffold-out', true)

    jscov.rewriteFolder 'spec/scaffold', 'spec/scaffold-out', (err) ->
      should.not.exist err
      fileCounter = 0

      wrench.readdirSyncRecursive('spec/scaffold-out').forEach (filename) ->
        fullpath = 'spec/scaffold-out/' + filename
        return if fs.lstatSync(fullpath).isDirectory()
        fileCounter++
        fs.readFileSync(fullpath, 'utf8').split('\n')[0].should.eql '/* automatically generated by jscov - do not edit */'

      fileCounter.should.eql 7
      done()


  it "should rewrite both javascript and coffee-script, but nothing else", (done) ->

    wrench.rmdirSyncRecursive('spec/coffee-out', true)

    jscov.rewriteFolder 'spec/coffee', 'spec/coffee-out', (err) ->
      should.not.exist err
      fileCounter = 0

      wrench.readdirSyncRecursive('spec/coffee-out').forEach (filename) ->
        fileCounter++
        fs.readFileSync('spec/coffee-out/' + filename, 'utf8').split('\n')[0].should.eql '/* automatically generated by jscov - do not edit */'
        filename.should.match /\.js$/

      fileCounter.should.eql 2
      done()


  it "should not create a directory if it encounters an error when processing coffee-script", (done) ->

    jscov.rewriteFolder 'spec/invalids/cs', 'spec/invalids-out', (err) ->
      should.exist err
      fs.lstat 'spec/invalids-out', (err) ->
        err.code.should.eql 'ENOENT'
        done()


  it "should not create a directory if it encounters an error when processing javascript", (done) ->

    jscov.rewriteFolder 'spec/invalids/js', 'spec/invalids-out', (err) ->
      should.exist err
      fs.lstat 'spec/invalids-out', (err) ->
        err.code.should.eql 'ENOENT'
        done()


  it "should overwrite the target directory and remove/replace all files in it", (done) ->

    wrench.mkdirSyncRecursive('spec/existing/subdir')
    fs.writeFileSync('spec/existing/foo.js', 'content', 'utf8')
    fs.writeFileSync('spec/existing/for.js', 'content', 'utf8')
    fs.writeFileSync('spec/existing/subdir/bar.js', 'content', 'utf8')

    jscov.rewriteFolder 'spec/scaffold', 'spec/existing', (err) ->
      should.not.exist err
      fileCounter = 0

      wrench.readdirSyncRecursive('spec/existing').forEach (filename) ->
        fullpath = 'spec/existing/' + filename
        return if fs.lstatSync(fullpath).isDirectory()
        fileCounter++
        fs.readFileSync(fullpath, 'utf8').split('\n')[0].should.eql '/* automatically generated by jscov - do not edit */'

      fileCounter.should.eql 7
      done()
