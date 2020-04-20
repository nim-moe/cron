import httpclient, strutils, os, json

proc sshToHttp(ssh: string): string =
  result = ssh
  result = result.replace(":", "/")
  result = result.replace("git@", "https://")

putEnv("GIT_SSH_COMMAND", "ssh -oBatchMode=yes")
putEnv("GIT_TERMINAL_PROMPT", "0")

let client = newHttpClient()
client.downloadFile("https://raw.githubusercontent.com/nim-lang/packages/master/packages.json", "packages.json")
let current = readFile("packages.json")
var nodes = current.parseJson()
var count = 0
var fail = newSeq[string]()

for obj in nodes.items:
  count.inc
  if obj.contains("method"):
    if obj["method"].getStr("") == "git":
      let name = obj["name"].getStr()
      var url = obj["url"].getStr().split("?")[0]
      if url.startsWith("git@"):
        url = url.sshToHttp()
      if not dirExists("../repos/" & name):
        echo "Downloading " & obj["name"].getStr() & "... #" & $count
        let ret = execShellCmd("cd ../repos && git clone --bare " & url & " ./" & name)
        if ret != 0:
          echo "Not found " & name
    elif obj["method"].getStr() == "hg":
      echo "Downloading " & obj["name"].getStr() & "... hg #" & $count
      let name = obj["name"].getStr()
      var url = obj["url"].getStr()

      if not dirExists("../hg/" & name):
        let ret = execShellCmd("cd ../hg && hg clone " & url & " ./" & name)
        if ret != 0:
          fail.add(name)
          echo "Not found " & name
          continue
      else:
        let ret = execShellCmd("cd ../hg/" & name & " && hg pull")
        if ret != 0:
          fail.add(name)
          echo "Not found " & name

      if not dirExists("../repos/" & name):
        discard execShellCmd("cd ../repos && git init --bare ./" & name)
      let ret = execShellCmd("cd ../hg/" & name & " && hg bookmarks hg && hg bookmark -f master && hg push ../../repos/" & name)
      if ret != 0:
        fail.add(name)
        echo "Failed"
      else:
        echo "Done"

for item in nodes.mitems:
  if not item.contains("url") or fail.contains(item["name"].getStr()):
    continue
  let name = item["name"].getStr()
  let parts = item["url"].getStr().split("?")
  var url = "https://git.nim.moe/" & name
  if parts.len > 1:
    url.add("?" & parts[1])
  item["url"] = %* url
  item["method"] = %* "git"

writeFile("../reg/packages.json", nodes.pretty())