import httpclient, strutils, os, json

proc sshToHttp(ssh: string): string =
  let info = ssh.split(":")[1]
  let parts = info.split("/")
  let user = parts[0]
  var repo = parts[1]
  result = "https://github.com/" & user & "/" & repo

putEnv("GIT_SSH_COMMAND", "ssh -oBatchMode=yes")
putEnv("GIT_TERMINAL_PROMPT", "0")

let client = newHttpClient()
client.downloadFile("https://raw.githubusercontent.com/nim-lang/packages/master/packages.json", "packages.json")
let current = readFile("packages.json")
var nodes = current.parseJson()

for obj in nodes.items:
  if obj.contains("method"):
    if obj["method"].getStr("") == "git":
      let name = obj["name"].getStr()
      var url = obj["url"].getStr().split("?")[0]
      if url.startsWith("git@"):
        url = url.sshToHttp()
      if not dirExists("../repos/" & name):
        echo "Downloading " & obj["name"].getStr()
        let ret = execShellCmd("cd ../repos && git clone --bare " & url & " ./" & name)
        if ret != 0:
          echo "Not found " & name

for item in nodes.mitems:
  if not item.contains("url"):
    continue
  let name = item["name"].getStr()
  let parts = item["url"].getStr().split("?")
  var url = "https://git.nim.moe/" & name
  if parts.len > 1:
    url.add("?" & parts[1])
  item["url"] = %* url

writeFile("../reg/packages.json", nodes.pretty())