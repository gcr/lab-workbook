package = "lab-workbook-for-trello"
version = "1.0-1"

source = {
   url = "git://github.com/gcr/lua-workbook-for-trello",
}

description = {
   summary = "Use Trello as a workbook for your Torch or Python experiments! Data goes into S3, plots go right into Trello.",
   homepage = "https://github.com/gcr/lua-workbook-for-trello",
}

dependencies = {
    "s3 >= 1.0-3",
}

build = {
   type = "builtin",
   modules = {
      ['lab-workbook-for-trello.init'] = 'init.lua',
   }
}