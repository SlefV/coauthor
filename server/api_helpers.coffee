apiRe = /^\/api\/messages(?:\/(\w+))?$/

export apiPath = (pathname) ->
  match = pathname.match apiRe
  return null unless match?
  message: match[1] ? null

export parseApiLimit = (value) ->
  limit = Math.min parseInt(value ? 100, 10), 500
  limit = 100 unless limit > 0
  limit

export apiMessageFields = [
  '_id', 'group', 'root', 'children', 'title', 'body', 'format', 'file',
  'tags', 'published', 'deleted', 'private', 'minimized', 'pinned',
  'protected', 'creator', 'created', 'coauthors', 'authors', 'updated',
  'updators', 'submessageCount', 'submessageLastUpdate'
]

bearerRe = /^Bearer\s+(.+)$/i

export apiToken = (headers = {}, cookies = {}) ->
  auth = headers.authorization
  token = headers['x-auth-token'] ? cookies['X-Auth-Token']
  if auth? and (match = auth.match bearerRe)
    token = match[1]
  if token? and token != 'null' then token else null

export messageJson = (message) ->
  json = {}
  for field in apiMessageFields when field of message
    json[field] = message[field]
  json
