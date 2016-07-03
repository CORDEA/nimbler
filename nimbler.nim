# Copyright 2016 Yoshihiro Tanaka
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

  # http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Author: Yoshihiro Tanaka <contact@cordea.jp>
# date  :2016-06-23

import os
import httpclient, parseopt2
import pegs, strutils, subexes, json, sequtils

const
    defaultRepo = "nim-lang/packages"
    nimbleBaseDir = getEnv("HOME") / "/.nimble/"
    configFileDir = "/nimbler/"
    dbListFileName = "repos$#.txt"
    nimbleFileName = "packages$#.json"
    libFileName = "$#.nimble"
    tmpFilePath = "_tmp"
    apiBaseUrl = "https://api.github.com"
    rawBaseUrl = "https://raw.githubusercontent.com/$#/master$#"
    searchCodeApiPath = "/search/code?q=$#+in:path+extension:$#+repo:$#"
    httpStatusOk = "200 OK"
    test = true

type
    Lib = object
        name, url, meth, desc, license, web: string
        tags: seq[string]

proc getFmtDbListFileName(arg: string): string =
    let path = nimbleBaseDir / configFileDir
    if not path.existsDir:
        path.createDir()
    return path / (subex(dbListFileName) % [arg])

proc getTmpDbListFileName(): string =
    return getFmtDbListFileName(tmpFilePath)

proc getDbListFileName(): string =
    return getFmtDbListFileName("")

proc getFmtNimbleFileName(arg: string): string =
    return nimbleBaseDir / (subex(nimbleFileName) % [arg])

proc getTmpNimbleFileName(): string =
    return getFmtNimbleFileName(tmpFilePath)

proc getNimbleFileName(): string =
    return getFmtNimbleFileName("")

proc getTmpDbListFile(): File =
    result = getTmpDbListFileName().open(fmWrite)

proc getDbListFile(): File =
    if getDbListFileName().existsFile:
        result = getDbListFileName().open(fmRead)

proc overwriteDbListFile(): bool =
    result = getTmpDbListFileName().existsFile
    if result:
        getTmpDbListFileName().moveFile getDbListFileName()

proc `<>`(node: JsonNode, q: string): string =
    return if node.hasKey(q): node[q].str else: nil

proc `%`(lib: Lib): JsonNode =
    result = newJObject()
    for k, v in lib.fieldPairs:
        var key = k
        if key == "meth":
            key = "method"
        if v != nil:
            result[key] = %v

proc toData(node: JsonNode): Lib =
    var sq: seq[string] = @[]
    if node.hasKey("tags"):
        for n in node["tags"]:
            sq.add n.str
    result = Lib(
        name: node<>"name",
        url: node<>"url",
        meth: node<>"method",
        desc: node<>"description",
        license: node<>"license",
        web: node<>"web",
        tags: sq
    )

proc downloadDbFile(fullName, path: string): string =
    let
        rawUrl = subex(rawBaseUrl) % [fullName, path]
        res = get(rawUrl)
    if res.status == httpStatusOk:
        result = res.body

proc searchFile(q, ext, repo: string): JsonNode =
    if test:
        return parseJson("res-test.json".readFile())
    let
        url = apiBaseUrl & subex(searchCodeApiPath) % [q, ext, repo]
        res = get(url)
    if res.status == httpStatusOk:
        return parseJson(res.body)

proc mergeFile(targ: JsonNode, isOverwrite: bool): string =
    var
        libs: seq[Lib] = @[]
        deduplicates: seq[Lib] = @[]
    if isOverwrite:
        let body = getNimbleFileName().readFile()
        for j in parseJson(body):
            libs.add toData(j)
    for t in targ:
        libs.add toData(t)
    for lib in libs:
        if len(deduplicates.filter(proc(x: Lib): bool = x.name == lib.name)) == 0:
            deduplicates.add lib
    result = (%deduplicates).pretty

proc fetchDbFile(repos: seq[string], isOverwrite: bool): bool =
    let writef = getTmpNimbleFileName().open(fmWrite)
    if not getNimbleFileName().existsFile:
        stderr.writeLine(getNimbleFileName() & " does not exist.")
        quit 1

    let readf = getNimbleFileName().open(fmRead)
    defer: close(readf)

    result = false
    for line in repos:
        var
            jn = searchFile(nimbleFileName, "json", line)
            its = jn["items"]
        if len(its) == 1:
            let
                path = its[0]["path"].str
                fullName = its[0]["repository"]["full_name"].str
            let body = downloadDbFile(fullName, path)
            if body != nil:
                let json = parseJson body
                writef.write mergeFile(json, isOverwrite)
                writef.close()
                result = getTmpNimbleFileName().existsFile
                if result:
                    getTmpNimbleFileName().moveFile getNimbleFileName()

proc updateRepo(): bool =
    let readf = getDbListFile()
    defer: readf.close()
    var cont = readf.readAll().splitLines
    let existDefRepo = len(cont.filter(proc (x: string): bool = x == defaultRepo)) > 0

    if not existDefRepo:
        cont.add defaultRepo
    result = fetchDbFile(cont, false)

proc registerRepo(repo: string): bool =
    let
        writef = getTmpDbListFile()
        readf = getDbListFile()
    defer: writef.close()
    defer: readf.close()
    if readf != nil:
        for line in readf.readAll().splitLines:
            if $line == repo:
                return
    if fetchDbFile(@[repo], true):
        writef.writeLine repo
    result = overwriteDbListFile()

proc removeRepo(repo: string): bool =
    result = false
    let
        writef = getTmpDbListFile()
        readf = getDbListFile()
    defer: readf.close()
    defer: writef.close()
    for line in readf.readAll().splitLines:
        if $line == "":
            continue
        if $line == repo:
            result = true
            continue
        writef.writeLine line
    discard overwriteDbListFile()

when isMainModule:
    var
        sub: string
        sarg: string
        i = 0

    for kind, key, val in getopt():
        case kind
        of cmdArgument:
            if i == 0:
                sub = key
            else:
                sarg = key
        else: discard
        inc i

    case sub
    of "add":
        if sarg == nil:
            stderr.writeLine "Please specify a repository."
            quit 1
        if not registerRepo(sarg):
            quit 1
    of "remove":
        if sarg == nil:
            stderr.writeLine "Please specify a repository."
            quit 1
        if not removeRepo(sarg):
            stderr.writeLine "Repository not found."
            quit 1
    of "update":
        if not updateRepo():
            quit 1
    else:
        stderr.writeLine "Sub-command '" & sub & "' does not exist."
        quit 1
