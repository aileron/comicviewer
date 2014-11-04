sys = require('sys')
fs = require('fs')
path = require('path')
express = require('express')
flatten = require('flatten')
AdmZip = require('adm-zip')
RarFile = require('rarfile').RarFile

md5 = (->
  crypto = require('crypto')

  (value)->
    hash = crypto.createHash('md5')
    hash.update value
    hash.digest('hex')

)()

name2code = {}
code2name = {}

filelist = (dir)->
  fs.readdirSync(dir).map (item)->
    filepath = path.join(dir,item)
    stat = fs.statSync filepath
    return filelist( filepath ) if stat.isDirectory()
    code = md5(filepath)
    name2code[ filepath ] = code
    code2name[ code ] = filepath

    filepath

filelist = flatten(filelist('/z/Comic'))

app = express()
app.get '/', (req,res)->
  res.set 'Content-Type','text/html'

  view = ''
  for filename in filelist
    view += "<a href='/page/#{name2code[filename]}'>#{filename}</a><br/>"

  res.send view

app.get '/page/:id/:code',(req,res)->
  filepath = code2name[req.params.id]
  extname = path.extname filepath
  return res.status(404) unless filepath
  switch extname
    when '.rar'
      rar = new RarFile(filepath)
      rar.showFile().then ()->
        for name in rar.names
          code = md5(name)
          if code == req.params.code
            return rar.readFile name,(data)->
              res.send data

    when '.zip'
      zip = new AdmZip(filepath)
      for entry in zip.getEntries()
        name = entry.entryName
        code = md5(name)

        if code == req.params.code
          entry.getDataAsync (data)->
            res.send data

app.get '/page/:id',(req,res)->
  res.set 'Content-Type','text/html'
  filepath = code2name[req.params.id]
  extname = path.extname filepath

  return res.status(404) unless filepath
  view = """#{filepath}...<br/>
    <style>
      img{ height: 100% }
    </style>
    """

  link = (code,idx)->
    """
      <a name="#{idx}" href="##{idx+1}">
        <img src="/page/#{req.params.id}/#{code}" align="right" />
      </a>
    """

  switch extname
    when '.rar'
      rar = new RarFile(filepath)
      rar.showFile().then ()->
        idx=0
        for name in rar.names when name.slice(-1) isnt '/'
          code = md5(name)
          view+=link(code,idx++)
        return res.send view

    when '.zip'
      zip = new AdmZip(filepath)
      idx=0
      for entry in zip.getEntries() when entry.entryName.slice(-1) isnt '/'
        name = entry.entryName
        code = md5(name)
        view+=link(code,idx++)
      return res.send view


app.listen(3000)
