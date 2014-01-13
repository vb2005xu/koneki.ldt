package = 'LuaDocumentor'
version = '0.1.4-1'
description = {
  summary = 'LuaDocumentor allow users to generate HTML and API files from code documented using Lua documentation language.',
  detailed = [[
      This is an example for the LuaRocks tutorial.
      Here we would put a detailed, typically
      paragraph-long description.
   ]],
  homepage = 'http://wiki.eclipse.org/Koneki/LDT/User_Area/LuaDocumentor',
  license = 'EPL'
}
source = {
  url = ''
}
dependencies = {
  'lua ~> 5.1',
  'luafilesystem ~> 1.6',
  'markdown ~> 0.32',
  'metalua-parser ~> 0.7.2',
  'penlight ~> 0.9.8'
}
build = {
  type = 'builtin',
  install = {
    bin = {
      luadocumentor = 'luadocumentor.lua'
    },
    lua = {
      ['models.internalmodelbuilder'] =
        '../modelsbuilder/models/internalmodelbuilder.mlua'
    }
  },
  modules = {
    defaultcss = 'defaultcss.lua',
    docgenerator = 'docgenerator.lua',
    extractors = 'extractors.lua',
    lddextractors = 'lddextractor.lua',
    templateengine = '../templateengine/templateengine.lua',

    ['fs.lfs'] = 'fs/lfs.lua',

    ['models.apimodel'] = '../modelsbuilder/models/apimodel.lua',
    ['models.apimodelbuilder'] = '../modelsbuilder/models/apimodelbuilder.lua',
    ['models.internalmodel'] = '../modelsbuilder/models/internalmodel.lua',
    ['models.ldparser'] = '../modelsbuilder/models/ldparser.lua',

    ['template.file'] = '../doctemplates/template/file.lua',
    ['template.index'] = 'template/index.lua',
    ['template.index.recordtypedef'] =
      '../doctemplates/template/index/recordtypedef.lua',
    ['template.item'] = '../doctemplates/template/item.lua',
    ['template.page'] = 'template/page.lua',
    ['template.recordtypedef'] = '../doctemplates/template/recordtypedef.lua',
    ['template.usage'] = '../doctemplates/template/usage.lua',
    ['template.utils'] = '../doctemplates/template/utils.lua',
  }
}
