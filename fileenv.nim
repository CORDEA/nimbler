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
# date  :2016-07-04

import os, subexes

const
    nimbleBaseDir = getEnv("HOME") / "/.nimble/"
    tmpFilePath = "_tmp"

type
    FileEnv* = ref object
        fmtFileName: string
        configFileDir: string
        fileName*: string
        absTmpPath*: string
        absPath*: string

proc getAbsFmtPath(fmtFileName, configFileDir, fmt: string): string =
    let path = nimbleBaseDir / configFileDir
    if not path.existsDir:
        path.createDir()
    result = path / (subex(fmtFileName) % [fmt])

proc getAbsFmtPath*(self: FileEnv, fmt: string, configFileDir: string = self.configFileDir): string =
    return getAbsFmtPath(self.fmtFileName, configFileDir, fmt)

proc getAbsTmpPath(fmtFileName, configFileDir: string): string =
    return getAbsFmtPath(fmtFileName, configFileDir, tmpFilePath)

proc getAbsPath(fmtFileName, configFileDir: string): string =
    return getAbsFmtPath(fmtFileName, configFileDir, "")

proc getFileName(fmtFileName: string): string =
    return subex(fmtFileName) % [""]

proc initFileEnv*(fmtFileName, configFileDir: string): FileEnv =
    result = FileEnv(fmtFileName: fmtFileName,
                        configFileDir: configFileDir,
                        fileName: getFileName(fmtFileName),
                        absPath: getAbsPath(fmtFileName, configFileDir),
                        absTmpPath: getAbsTmpPath(fmtFileName, configFileDir))
