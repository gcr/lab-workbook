local s3=require 's3'
local config=require 'pl.config'
local path=require 'pl.path'
local json=require 'cjson'



local LabWorkbook = {}
function LabWorkbook:newExperiment(newConfig)
   -- Creates a new experiment.

   -- Read config file from ~/.lab-notebook-config
   local config = config.read(path.expanduser("~/.lab-notebook-config")) or {}
   for k,v in pairs(newConfig) do config[k] = v end

   -- Connect to S3
   config.s3 = s3:connect{awsId = config.awsId,
                          awsKey = config.awsKey,
                          awsRole = config.awsRole,
                          bucket = config.bucket}

   config.bucketPrefix = config.bucketPrefix or ""
   -- ^ Should NOT start with '/'. Should END with '/' if you want to
   -- store results into a 'folder'.

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
   assert(result.resultCode == 200, string.format("Could not save result to S3. Result was %s",json.encode(result)))
   print(result)
   return key
end

function LabWorkbook:saveToTrello(title, type)
   print(" TODO : Save "..title.." to trello!")
   print("For now, use the following URL:")
   print(self.s3:getUrlFor(self:getS3KeyFor(title)).."?"..type)
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
   for i=1,10 do
      local j = math.ceil(math.random()*#choices)
      result[i] = string.sub(choices,j,j)
   end
   return table.concat(result)
end










return LabWorkbook