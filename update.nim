import json, os, strutils

proc sshToHttp(ssh: string): string =
  result = ssh
  result = result.replace(":", "/")
  result = result.replace("git@", "https://")
 
let packages = readFile("packages.json")
let nodes = packages.parseJson()
var count = 0
var notFound = newSeq[string]()
 
putEnv("GIT_SSH_COMMAND", "ssh -oBatchMode=yes")
putEnv("GIT_TERMINAL_PROMPT", "0")
 
for obj in nodes.items:
  count.inc
  if obj.contains("method"):
    if obj["method"].getStr() == "git":
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
    elif obj["method"].getStr() == "hg":
      echo "Downloading " & obj["name"].getStr() & "... hg #" & $count
      let name = obj["name"].getStr()
      var url = obj["url"].getStr()

      if not dirExists("../hg/" & name):
        let ret = execShellCmd("cd ../hg && hg clone " & url & " ./" & name)
        if ret != 0:
          notFound.add(name)
          echo "Not found " & name
          continue
      else:
        let ret = execShellCmd("cd ../hg/" & name & " && hg pull")
        if ret != 0:
          notFound.add(name)
          echo "Not found " & name

      if not dirExists("../repos/" & name):
        discard execShellCmd("cd ../repos && git init --bare ./" & name)
      let ret = execShellCmd("cd ../hg/" & name & " && hg bookmarks hg && hg push ../../repos/" & name)
      if ret != 0:
        echo "Failed"
      else:
        echo "Done"
 
var notFoundText = ""
for f in notFound.items:
  notFoundText.add(f & "\n")
 
writeFile("../reg/not_found.txt", notFoundText)