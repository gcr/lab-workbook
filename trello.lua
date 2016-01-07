local https = require 'ssl.https'
local url = require 'net.url' -- The net-url package
local json = require 'cjson'
local trelloAPIKey = "d6526507e103f4047887dbd210b9044c"

local Trello = {}
function Trello:connect(config)
   assert(config.token, "Need a Trello token")

   setmetatable(config, {__index = self})
   return config
end
function Trello:call(endpoint, verb, params, body)
   local trUrl = url.parse("https://api.trello.com/1" .. endpoint)
   print("Trello API:",trUrl)
   for k,v in pairs(params or {}) do
      trUrl.query[k] = v
   end
   trUrl.query.key = trelloAPIKey
   trUrl.query.token = self.token
   local responseBody = {}
   local _, resultCode, headers, statusLine = https.request{
      method = verb,
      url = tostring(trUrl),
      source = body,
      sink = ltn12.sink.table(responseBody),
   }
   if resultCode ~= 200 then
      error(string.format("Problem: Trello returned %s\n%s",
                          statusLine,
                          table.concat(responseBody)))
   end
   return json.decode(table.concat(responseBody))
end
function Trello:get(endpoint, params)
   return self:call(endpoint, "GET", params)
end
function Trello:post(endpoint, params, body)
   return self:call(endpoint, "POST", params, body)
end
function Trello:put(endpoint, params, body)
   return self:call(endpoint, "PUT", params, body)
end

--- Skeleton stub classes
local TrelloBoard = {}
function TrelloBoard:new(boardJson, api)
   setmetatable(boardJson, {__index = self})
   boardJson.api = api
   return boardJson
end
local TrelloList = {}
function TrelloList:new(listJson, api)
   setmetatable(listJson, {__index = self})
   listJson.api = api
   return listJson
end
local TrelloCard = {}
function TrelloCard:new(cardJson, api)
   setmetatable(cardJson, {__index = self})
   cardJson.api = api
   return cardJson
end

local function mapFactory(list, factoryClass, api)
   -- Convenience method for returning lists of things
   local results = {}
   for i, element in ipairs(list) do
      table.insert(results, factoryClass:new(element, api))
   end
   return results
end

function Trello:boards()
   return mapFactory(self:get("/members/me/boards"), TrelloBoard, self)
end
function TrelloBoard:lists()
   return mapFactory(
      self.api:get(string.format("/boards/%s/lists", self.id)),
      TrelloList, self.api
   )
end
function TrelloList:cards()
   return mapFactory(
      self.api:get(string.format("/lists/%s/cards", self.id)),
      TrelloCard, self.api
   )
end
function TrelloList:newCard(name)
   return TrelloCard:new(
      self.api:post(string.format("/lists/%s/cards", self.id),
                    {name=name}),
      self.api
   )
end

function TrelloCard:refresh(desc)
   for k,v in pairs(self.api:get(string.format("/cards/%s", self.id))) do
      self[k] = v
   end
end
function TrelloCard:writeDesc(desc)
   self.desc = desc
   self.api:put(string.format("/cards/%s/desc", self.id),
                {value = desc})
end

return Trello