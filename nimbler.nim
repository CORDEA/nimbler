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

import os, parseopt2
import pegs, subexes
import httpclient, json
import strutils, sequtils
import searchresp, fileenv, lib

const
    defaultRepo = "nim-lang/packages"
    reposFileName = "repos$#.tsv"
    configFileDir = "/nimbler/"
    nimbleFileName = "packages$#.json"
    apiBaseUrl = "https://api.github.com"
    rawBaseUrl = "https://raw.githubusercontent.com/$#/master$#"
    searchCodeApiPath = "/search/code?q=$#+in:path+extension:$#+repo:$#"
    httpStatusOk = "200 OK"

let
    reposEnv = initFileEnv(reposFileName, configFileDir)
    nimbleEnv = initFileEnv(nimbleFileName, "")

proc getTmpDbListFile(): File =
    result = reposEnv.absTmpPath.open(fmWrite)

proc getDbListFile(): File =
    let fileName = reposEnv.absPath
    if fileName.existsFile:
        result = fileName.open(fmRead)

proc getDbFilePath(fullName: string): string =
    return nimbleEnv.getAbsFmtPath("_" & fullName.replace("/", "-"), configFileDir)

proc overwriteDbListFile(): bool =
    let fileName = reposEnv.absTmpPath
    result = fileName.existsFile
    if result:
        fileName.moveFile reposEnv.absPath

proc searchFile(q, ext, repo: string): JsonNode =
    let
        url = apiBaseUrl & subex(searchCodeApiPath) % [q, ext, repo]
        res = get(url)
    if res.status == httpStatusOk:
        return parseJson(res.body)

proc mergeFile(src, trg: JsonNode): string =
    var libs: seq[Lib] = @[]
    if src != nil:
        for t in src:
            libs.add toLib(t)
    if trg != nil:
        for t in trg:
            libs.add toLib(t)
    result = deduplicate(libs).pretty()

proc downloadDbFile(resp: SearchResponse): bool =
    let
        path = getDbFilePath(resp.fullName)
        writef = path.open(fmWrite)
        rawUrl = subex(rawBaseUrl) % [resp.fullName, resp.path]
        res = get(rawUrl)

    result = false
    if res.status == httpStatusOk:
        let json = parseJson res.body
        writef.write json
        writef.close()
        result = true

proc mergeDbFile(req: seq[SearchResponse], isOverwrite: bool): bool =
    let
        path = nimbleEnv.absPath
        tmpPath = nimbleEnv.absTmpPath

    if isOverwrite:
        path.copyFile tmpPath
    else:
        if tmpPath.existsFile:
            tmpPath.removeFile()

    result = false
    if len(req) == 0:
        let writef = tmpPath.open(fmWrite)
        writef.write "[]"
        writef.close()
    else:
        for r in req:
            let
                src = if tmpPath.existsFile: parseJson tmpPath.readFile() else: nil
                trg = parseJson getDbFilePath(r.fullName).readFile()
                writef = tmpPath.open(fmWrite)
            writef.write mergeFile(src, trg)
            writef.close()
    result = tmpPath.existsFile
    if result:
        tmpPath.moveFile path

proc searchDbFile(repos: seq[string]): seq[SearchResponse] =
    result = @[]
    for line in repos:
        let
            jn = searchFile(nimbleEnv.fileName, "json", line)
        if jn == nil:
            result.add nil
            continue
        let
            its = jn["items"]
        if len(its) == 1:
            let
                path = its[0]["path"].str
                fullName = its[0]["repository"]["full_name"].str
                resp = SearchResponse(path: path, fullName: fullName)
            result.add resp

proc updateRepo(): bool =
    let readf = getDbListFile()
    if readf == nil:
        return true
    defer: readf.close()

    let sr = readf.readAll().toSearchResponses()
    for r in sr:
        if r != nil and downloadDbFile(r):
            echo r.fullName & " update completed."
        else:
            stderr.writeLine r.fullName & " update failure."
    result = mergeDbFile(sr, false)

proc registerRepo(repo: string): bool =
    let
        writef = getTmpDbListFile()
        readf = getDbListFile()
    var repos: seq[string] = @[repo]
    defer: writef.close()
    if readf == nil:
        if repo != defaultRepo:
            repos.add defaultRepo
    else:
        defer: readf.close()
        for line in readf.readAll().splitLines:
            if line.split("\t")[0] == repo:
                echo repo & " already exists."
                quit 0

    let sr = searchDbFile(repos)
    for r in sr:
        if r != nil and downloadDbFile(r):
            writef.writeLine(r.fullName & "\t" & r.path)
    discard mergeDbFile(sr, true)
    result = overwriteDbListFile()

proc removeRepo(repo: string): bool =
    result = false
    let
        writef = getTmpDbListFile()
        readf = getDbListFile()
    if readf == nil:
        return true
    defer: readf.close()
    defer: writef.close()

    var repos: seq[SearchResponse] = @[]

    for line in readf.readAll().splitLines:
        if line == "":
            continue
        let resp = line.toSearchResponse()
        if resp.fullName == repo:
            result = true
            continue
        repos.add resp
        writef.writeLine line

    discard overwriteDbListFile()
    discard mergeDbFile(repos, false)

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

    if sub == nil:
        stderr.writeLine "Please specify a sub-command."
        quit 1

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
