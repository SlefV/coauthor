import {Accounts} from 'meteor/accounts-base'
import {DDP} from 'meteor/ddp'
import {DDPCommon} from 'meteor/ddp-common'
import {Meteor} from 'meteor/meteor'
import {WebApp} from 'meteor/webapp'
import {check, Match} from 'meteor/check'

import {descendantMessagesQuery} from '../lib/messages'
import {apiPath, apiToken, messageJson, parseApiLimit} from './api_helpers'

cookie = require 'cookie'
url = require 'url'

apiHeaders = (req) ->
  'Content-Type': 'application/json; charset=utf-8'
  'Cache-Control': 'no-store'
  'Access-Control-Allow-Origin': req.headers['origin'] ? '*'
  'Access-Control-Allow-Credentials': 'true'
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Auth-Token'
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
  'Vary': 'Origin'

sendJson = (req, res, status, object) ->
  res.writeHead status, apiHeaders req
  res.end JSON.stringify object

apiError = (req, res, status, error, reason) ->
  sendJson req, res, status,
    error: error
    reason: reason

readBody = (req, callback) ->
  body = ''
  req.on 'data', (chunk) ->
    body += chunk
    if body.length > 1024 * 1024
      req.destroy()
  req.on 'end', ->
    try
      callback null, if body.length then JSON.parse body else {}
    catch error
      callback error

apiUser = (req) ->
  cookies = if req.headers.cookie? then cookie.parse req.headers.cookie else null
  token = apiToken req.headers, cookies
  if token?
    user = Meteor.users?.findOne
      'services.resume.loginTokens':
        $elemMatch:
          hashedToken: Accounts?._hashLoginToken token
    throw new Meteor.Error 'api.invalidToken', 'Invalid API token' unless user?
    user
  else
    null

callMethodAsUser = (name, userId, args...) ->
  handler = Meteor.server.method_handlers[name]
  throw new Meteor.Error 'api.noMethod', "Unknown method '#{name}'" unless handler?
  invocation = new DDPCommon.MethodInvocation
    name: name
    isSimulation: false
    userId: userId
    connection: null
    randomSeed: null
  if DDP?._CurrentMethodInvocation?.withValue?
    DDP._CurrentMethodInvocation.withValue invocation, ->
      handler.apply invocation, args
  else
    handler.apply invocation, args

handleGet = (req, res, path, query, user) ->
  if path.message?
    message = Messages.findOne path.message
    unless message? and canSee message, false, user
      return apiError req, res, (if user? then 403 else 401), 'api.unauthorized', 'Insufficient permissions to read message'
    sendJson req, res, 200, message: messageJson message
  else
    group = query.group
    unless group?
      return apiError req, res, 400, 'api.missingGroup', 'Query parameter group is required'
    findQuery = accessibleMessagesQuery group, user, false
    if query.root?
      findQuery = $and: [findQuery, descendantMessagesQuery query.root]
    messages = Messages.find(findQuery,
      sort:
        updated: -1
      limit: parseApiLimit query.limit
    ).map messageJson
    sendJson req, res, 200, {messages}

handlePost = (req, res, path, user) ->
  readBody req, Meteor.bindEnvironment (error, body) ->
    if error?
      return apiError req, res, 400, 'api.invalidJson', 'Request body must be valid JSON'
    unless user?
      return apiError req, res, 401, 'api.unauthorized', 'Authentication is required to post messages'
    try
      if path.message?
        check body, Object
        callMethodAsUser 'messageUpdate', user._id, path.message, body
        sendJson req, res, 200, id: path.message
      else
        check body,
          group: String
          parent: Match.Optional Match.OneOf String, null
          position: Match.Optional Match.OneOf Number, null
          message: Match.Optional Object
        id = callMethodAsUser 'messageNew', user._id, body.group, body.parent ? null, body.position ? null, body.message ? {}
        sendJson req, res, 201, {id}
    catch error
      status = if /unauthorized|anonymous/i.test(error.error ? '') then 403 else 400
      apiError req, res, status, error.error ? 'api.error', error.reason ? error.message

export apiHandler = Meteor.bindEnvironment (req, res, next) ->
  parsed = url.parse req.url, true
  path = apiPath parsed.pathname
  return next() unless path?

  if req.method == 'OPTIONS'
    res.writeHead 204, apiHeaders req
    return res.end()

  unless req.method in ['GET', 'POST']
    return apiError req, res, 405, 'api.methodNotAllowed', 'Only GET, POST, and OPTIONS are supported'

  try
    user = apiUser req
  catch error
    return apiError req, res, 401, error.error ? 'api.invalidToken', error.reason ? error.message

  if req.method == 'GET'
    handleGet req, res, path, parsed.query, user
  else
    handlePost req, res, path, user

export registerApi = ->
  WebApp.rawConnectHandlers.use apiHandler
