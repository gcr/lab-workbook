local fs = require 'luarocks.fs'

local util = {}

function util.quoteArgs(command, ...)
   local out = { command }
   for _, arg in ipairs({...}) do
      assert(type(arg) == "string")
      out[#out+1] = fs.Q(arg)
   end
   return table.concat(out, " ")
end

function util.newTag()
   -- Generate a random tag
   local result = {
      os.date("!%Y%m%d%H%M"),
      "-"
   }
   local choices = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
   math.randomseed(tostring(os.time())..tostring(os.clock()))
   for i=1,10 do
      local j = math.ceil(math.random()*#choices)
      result[#result+1] = string.sub(choices,j,j)
   end
   return table.concat(result)
end

return util