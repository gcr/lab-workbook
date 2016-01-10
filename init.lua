local config = require 'pl.config'
local path = require 'pl.path'
local json = require 'cjson'
local util = require 'lab-workbook.util'
local fs = require 'luarocks.fs'

local LabWorkbook = {}
function LabWorkbook:newExperiment(newConfig)
   -- Creates a new experiment.

   -- Read config file from ~/.lab-workbook-config
   local config = config.read(path.expanduser("~/.lab-workbook-config")) or {}
   for k,v in pairs(newConfig) do config[k] = v end
   setmetatable(config, {__index = self})

   assert(config.bucketPrefix, "Please specify a bucket prefix to save experiments to")
   -- ^ Should END with '/' if you want to store results into a
   -- folder.

   -- Make some new data for us
   config.timestamp = os.date("%Y%m%d-%H%M")
   config.tag = util.newTag()

   config:testS3()

   print(string.format('\n\n\27[1m---- Experiment Tag: \27[31m%s\27[0m\n\n',
                       config.tag))

   return config
end


function LabWorkbook:testS3()
   local f = io.popen(util.quoteArgs("aws", "s3", "ls", self.bucketPrefix))
   local result = f:read("*a")
   if not f:close() then
      error(string.format("Could not use bucketPrefix '%s'. Are the AWS command line tools set up correctly?", self.bucketPrefix))
   end
end

function LabWorkbook:getS3KeyFor(name)
   return string.format("%s%s-%s/%s",
                        self.bucketPrefix,
                        self.timestamp,
                        self.tag,
                        name
                     )
end


function LabWorkbook:S3PutFile(artifactName, filename)
   -- Save the given filename as the given artifact.
   -- Note that everything happens ASYNCHRONOUSLY. If anything goes
   -- WRONG when saving to S3, we will report errors to stderr.
   local args = util.quoteArgs("aws", "s3", "cp", filename,
                               self:getS3KeyFor(artifactName),
                               "--acl",
                               "public-read",
                               "--quiet"
                            )
   args = args .. string.format(" || echo 'NOTEBOOK WARNING: Could not save '%s' to S3'",
                                fs.Q(artifactName))
   args = "( "..args.." ) &" -- Run asynchronously :-)
   print(args)
   os.execute(args)
end
function LabWorkbook:S3PutTempFile(artifactName, cb)
   -- Calls 'cb' with a filename. When 'cb' finishes, asynchronously
   -- upload the result to S3 and then remove it.

   -- Note that everything happens ASYNCHRONOUSLY. If anything goes
   -- WRONG when saving to S3, we will report errors to stderr.
   local filename = os.tmpname()
   cb(filename)
   local args = util.quoteArgs("aws", "s3", "cp", filename,
                               self:getS3KeyFor(artifactName),
                               "--acl",
                               "public-read",
                               "--quiet"
                            )
   args = args .. string.format(" && rm %s || echo 'NOTEBOOK WARNING: Could not save '%s' to S3. Temporary file is in %s '",
                                fs.Q(filename),
                                fs.Q(artifactName),
                                fs.Q(filename)
                             )
   args = "( "..args.." ) &" -- Run asynchronously :-)
   print(args)
   os.execute(args)
end

-- function LabWorkbook:getTrelloCard()
--    -- Returns either our Trello card, or creates a new Trello card. :-)
--    if self.card then
--       return self.card
--    end
--    -- Otherwise: Gotta make a new card.
--    local board = nil
--    for i,b in ipairs(Trello:connect{token=self.trelloToken}:boards()) do
--       if b.name == self.trelloBoard then
--          board = b
--       end
--    end
--    -- The user specifies a board to search by name. Go through the
--    -- boards and find the right one.
--    assert(board, string.format("Could not find a Trello board with the name '%s'",self.trelloBoard))
--    -- Create a new card at the bottom of the leftmost (first) list
--    local lists = board:lists()
--    assert(#lists > 0, string.format("No lists on %s",self.trelloBoard))
--    self.card = lists[1]:newCard(self.experimentName)
--    return self.card
-- end

-- function LabWorkbook:saveToTrello(artifactName, magic_userscript_prompt)
--    -- Write the artifact into our trello card description if it
--    -- already isn't present. The results are cached to ensure we don't
--    -- hit Trello too often.

--    -- The "magic_userscript_prompt" is a special string that
--    -- identifies the type of the artifact (examples include
--    -- WORKBOOK_PLOT, WORKBOOK_IMAGE, etc). Our userscript will render
--    -- these specially when it notices they're part of a link.

--    local card = self:getTrelloCard()
--    local S3url = self.s3:getUrlFor(self:getS3KeyFor(artifactName))
--    local u = url.parse(S3url) -- warning: do not use this directly!
--    u.query[magic_userscript_prompt]=1
--    S3url = S3url .. "?" .. tostring(u.query) -- avoids terrible escaping bugs!
--    -- If this result is in our cached description, don't hit the Trello API
--    if not string.find(card.desc, S3url, 1, true) then
--       -- If we aren't in the description, refresh the card just to be
--       -- sure... We should refresh the card anyways because the user
--       -- could have edited it.
--       card:refresh()
--       if not string.find(card.desc, S3url, 1, true) then
--          card:writeDesc(card.desc .. "\n" .. S3url)
--       end
--    end
-- end

-- ------------------ Artifacts ------------------

function LabWorkbook:saveJSON(artifactName, value)
   self:S3PutTempFile(artifactName..".json",
                      function(filename)
                         local f = io.open(filename, "w")
                         f:write(json.encode(value))
                         f:close()
                      end)
end

function LabWorkbook:saveTorch(artifactName, value)
   self:S3PutTempFile(artifactName..".t7",
                      function(filename)
                         torch.save(filename, value)
                      end)
end


function LabWorkbook:newTimeSeriesLog(artifactName,
                                      fields,
                                      saveEvery)
   -- Creates a new streaming log to be saved to S3, in CSV format
   local csvFilename = os.tmpname()
   print(csvFilename)
   local f = io.open(csvFilename, "w")
   local counter = saveEvery or 1
   fields[#fields+1] = "Date"
   f:write(table.concat(fields, ",").."\n")
   return function(entries)
             entries.Date = os.date("%+")
             local line = {}
             for _,f in ipairs(fields) do
                line[#line+1] = tostring(entries[f])
             end
             f:write(table.concat(line,",").."\n")
             f:flush()
             counter = counter - 1
             if counter == 0 then
                counter = saveEvery or 1
                self:S3PutFile(artifactName..".csv",
                               csvFilename)
             end
          end

end





return LabWorkbook