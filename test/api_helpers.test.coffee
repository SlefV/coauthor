assert = require 'node:assert/strict'
test = require 'node:test'

{apiMessageFields, apiPath, apiToken, messageJson, parseApiLimit} = require '../server/api_helpers.coffee'

test 'apiPath recognizes the messages collection route', ->
  assert.deepEqual apiPath('/api/messages'), message: null

test 'apiPath recognizes a single message route', ->
  assert.deepEqual apiPath('/api/messages/abc123'), message: 'abc123'

test 'apiPath rejects non-API paths', ->
  assert.equal apiPath('/file/abc123'), null

test 'apiToken accepts bearer tokens before other token sources', ->
  assert.equal apiToken({authorization: 'Bearer bearer-token', 'x-auth-token': 'header-token'}, {}), 'bearer-token'

test 'apiToken accepts X-Auth-Token header and cookie tokens', ->
  assert.equal apiToken({'x-auth-token': 'header-token'}, {'X-Auth-Token': 'cookie-token'}), 'header-token'
  assert.equal apiToken({}, {'X-Auth-Token': 'cookie-token'}), 'cookie-token'
  assert.equal apiToken({}, {'X-Auth-Token': 'null'}), null

test 'parseApiLimit defaults and caps list limits', ->
  assert.equal parseApiLimit(undefined), 100
  assert.equal parseApiLimit('25'), 25
  assert.equal parseApiLimit('999'), 500
  assert.equal parseApiLimit('-1'), 100
  assert.equal parseApiLimit('not-a-number'), 100

test 'messageJson only returns the public API fields', ->
  created = new Date '2026-06-27T00:00:00Z'
  result = messageJson
    _id: 'm1'
    group: 'g'
    title: 'Title'
    body: ''
    root: null
    deleted: false
    created: created
    services:
      secret: true
    privateImplementationDetail: 'omit me'
  assert.deepEqual result,
    _id: 'm1'
    group: 'g'
    title: 'Title'
    body: ''
    root: null
    deleted: false
    created: created
  assert.ok apiMessageFields.includes 'updated'
