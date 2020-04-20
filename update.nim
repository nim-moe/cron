import json, os, strutils

proc sshToHttp(ssh: string): string =
  let info = ssh.split(":")[1]
  let parts = info.split("/")
  let user = parts[0]
  var repo = parts[1]
  result = "https://github.com/" & user & "/" & repo
 
let packages = readFile("packages.json")
let nodes = packages.parseJson()
var count = 0
var notFound = newSeq[string]()
 
putEnv("GIT_SSH_COMMAND", "ssh -oBatchMode=yes")
putEnv("GIT_TERMINAL_PROMPT", "0")
 
for obj in nodes.items:
  count.inc
  if obj.contains("method"):
    if obj["method"].getStr("") == "git":
      echo "Downloading " & obj["name"].getStr() & "... #" & $count
      let name = obj["name"].getStr()
      var url = obj["url"].getStr().split("?")[0]
      if url.startsWith("git@"):
        url = url.sshToHttp()
      if not dirExists("../repos/" & name):
        let ret = execShellCmd("cd ../repos && git clone --bare " & url & " ./" & name)
        if ret != 0:
          notFound.add(name)
          echo "Not found " & name
      else:
        discard execShellCmd("cd ../repos/" & name & " && git fetch origin +refs/heads/*:refs/heads/* --prune")
      echo "Done"
 
var notFoundText = ""
for f in notFound.items:
  notFoundText.add(f & "\n")
 
writeFile("../reg/not_found.txt", notFoundText)