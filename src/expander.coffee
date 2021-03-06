_ = require 'underscore'
estools = require './estools'
tools = require './tools'
esprima = require 'esprima'
escodegen = require 'escodegen'

noopDef = (name) ->
  kind: 'var'
  type: 'VariableDeclaration'
  declarations: [{
    type: 'VariableDeclarator'
    id: { type: 'Identifier', name: name }
    init:
      type: 'FunctionExpression'
      id: null
      params: []
      defaults: []
      body: 
        type: 'BlockStatement'
        body: [{
          type: 'ReturnStatement'
          argument: { type: 'Literal', value: null }
        }]
    rest: null
    generator: false
    expression: false
  }]

noopExpression = (name) ->
  type: 'ExpressionStatement'
  expression:
    arguments: []
    type: 'CallExpression'
    callee:
      type: 'Identifier'
      name: name

wrapPred = (test, left, right) ->
  type: 'CallExpression'
  arguments: [{
    type: 'ThisExpression'
  }, {
    type: 'Identifier'
    name: 'arguments'
  }]
  callee:
    type: 'MemberExpression'
    computed: false
    property:
      type: 'Identifier'
      name: 'call'
    object:
      type: 'FunctionExpression'
      id: null
      rest: null
      generator: false
      expression: false
      params: [{ type: 'Identifier', name: 'arguments' }]
      defaults: []
      body:
        type: 'BlockStatement'
        body: [{
          type: 'IfStatement'
          test: test
          consequent:
            type: 'ReturnStatement'
            argument: left
          alternate:
            type: 'ReturnStatement'
            argument: right
        }]

wrapLogic = (isAnd, left, right, tmpvar) ->
  l = if  isAnd then right else { type: 'Identifier', name: tmpvar }
  r = if !isAnd then right else { type: 'Identifier', name: tmpvar }
  res = wrapPred({ type: 'Identifier', name: tmpvar }, l, r)
  res.callee.object.body.body = [{
    kind: 'var'
    type: 'VariableDeclaration'
    declarations: [{
      type: 'VariableDeclarator'
      id: { type: 'Identifier', name: tmpvar }
      init:  left
    }]
  }].concat(res.callee.object.body.body)
  res



exports.expand = (ast) ->

  return escodegen.generate(exports.expand(esprima.parse(ast, { loc: false })), { indent: "  " }) if typeof ast == 'string'

  addNoop = false

  estools.traverse ast, ['IfStatement'], (node) ->
    if !node.alternate?
      addNoop = true
      node.alternate = noopExpression('__noop__')

  estools.traverse ast, ['LogicalExpression'], (node) ->
    if node.operator == '&&' || node.operator == '||'
      if node.left.type == 'Literal' || node.left.type == 'Identifier'
        if node.operator == '&&'
          tools.replaceProperties(node, wrapPred(node.left, node.right, node.left))
        else
          tools.replaceProperties(node, wrapPred(node.left, node.left, node.right))
      else
        tools.replaceProperties(node, wrapLogic(node.operator == '&&', node.left, node.right, '__lhs__'))

      delete node.operator
      delete node.left
      delete node.right

  estools.traverse ast, ['ConditionalExpression'], (node) ->
    tools.replaceProperties(node, wrapPred(node.test, node.consequent, node.alternate))

    delete node.test
    delete node.consequent
    delete node.alternate

  if addNoop
    estools.traverse ast, ['Program'], (node) ->
      node.body = [noopDef('__noop__')].concat(node.body)

  ast
