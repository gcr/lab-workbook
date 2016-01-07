local s3 = require 's3'
local config = require 'pl.config'
local path = require 'pl.path'
local json = require 'cjson'
local Trello = require 'trello'
local url = require 'net.url'

local LabWorkbook = {}
function LabWorkbook:newExperiment(newConfig)
   -- Creates a new experiment.

   -- Read config file from ~/.lab-workbook-config
   local config = config.read(path.expanduser("~/.lab-workbook-config")) or {}
   for k,v in pairs(newConfig) do config[k] = v end

   -- Connect to S3
   config.s3 = s3:connect{awsId = config.awsId,
                          awsKey = config.awsKey,
                          awsRole = config.awsRole,
                          bucket = config.bucket}

   config.bucketPrefix = config.bucketPrefix or ""
   -- ^ Should NOT start with '/'. Should END with '/' if you want to
   -- store results into a 'folder'.

   -- Assert that we can connect to Trello
   assert(config.trelloToken, "Please get a Trello token (see the README file)")
   assert(config.trelloBoard, "Please specify the name of the Trello board")

   config.timestamp = os.date("%Y%m%d")
   config.tag = newTag()
   config.experimentName = config.experimentName or "Experiment"

   setmetatable(config, {__index = self})
   return config
end

function LabWorkbook:getS3KeyFor(name)
   return string.format("%s%s-%s-%s/%s",
                        self.bucketPrefix,
                        self.timestamp,
                        self.tag,
                        self.experimentName,
                        name
                     )
end

function LabWorkbook:S3Put(title, data)
   local key = self:getS3KeyFor(title)
   local result = self.s3:put(key, data, "public-read")
   if result.resultCode == 500 then
      sys.sleep(1)
      return self:S3Put(title,data)
   end
   assert(result.resultCode == 200, string.format("Could not save result to S3. Result was %s",json.encode(result)))
   return key
end

function LabWorkbook:getTrelloCard()
   -- Returns either our Trello card, or creates a new Trello card. :-)
   if self.card then
      return self.card
   end
   -- Otherwise: Gotta make a new card.
   local board = nil
   for i,b in ipairs(Trello:connect{token=self.trelloToken}:boards()) do
      if b.name == self.trelloBoard then
         board = b
      end
   end
   assert(board, string.format("Could not find a Trello board with the name '%s'",self.trelloBoard))
   local lists = board:lists()
   assert(#lists > 0, string.format("No lists on %s",self.trelloBoard))
   self.card = lists[1]:newCard(self.experimentName)
   return self.card
end

function LabWorkbook:saveToTrello(title, type)
   -- Save this result to Trello.
   local card = self:getTrelloCard()
   local S3url = self.s3:getUrlFor(self:getS3KeyFor(title))
   local u = url.parse(S3url) -- warning: do not use this directly!
   u.query[type]=1
   S3url = S3url .. "?" .. tostring(u.query) -- avoids terrible escaping bugs!
   -- If this result is in our cached description, don't hit the Trello API
   if not string.find(card.desc, S3url, 1, true) then
      -- Save it!
      card:refresh()
      if not string.find(card.desc, S3url, 1, true) then
         card:writeDesc(card.desc .. "\n" .. S3url)
      end
   end
end

function LabWorkbook:plot(title, data, opts)
   opts = opts or {}
   local dataset = {}
   if torch.typename(data) then
      for i = 1, data:size(1) do
         local row = {}
         for j = 1, data:size(2) do
            table.insert(row, data[{i, j}])
         end
         table.insert(dataset, row)
      end
   else
      dataset = data
   end
   -- clone opts into options
   local options = {}
   for k,v in pairs(opts) do options[k] = v end
   options.file = dataset
   if options.labels then
      options.xlabel = options.xlabel or options.labels[1]
   end

   -- Save to S3 and Trello
   self:S3Put(title, json.encode(options))
   self:saveToTrello(title, "WORKBOOK_PLOT")
end


------------------------------------

function newTag()
   -- Generate a random tag
   local result = {}
   local choices = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
   math.randomseed(tostring(os.time())..tostring(os.clock()))
   for i=1,10 do
      local j = math.ceil(math.random()*#choices)
      result[i] = string.sub(choices,j,j)
   end
   return table.concat(result)
end










return LabWorkbook