package = "lab-workbook"
version = "scm-0"

source = {
   url = "git://github.com/gcr/lab-workbook",
}

description = {
   summary = "Monitor your experiments, stream results to S3, and then view results on Trello.",
   homepage = "https://github.com/gcr/lab-workbook",
}

dependencies = {
    "lua-cjson",
    "penlight",
}

build = {
   type = "builtin",
   modules = {
      ['lab-workbook.init'] = 'init.lua',
      ['lab-workbook.util'] = 'util.lua',
   }
}
