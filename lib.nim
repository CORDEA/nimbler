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
# date  :2016-07-05

import json, sequtils

type
    Lib* = object
        name, url, meth, description, license, web: string
        tags: seq[string]

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

proc toLib*(node: JsonNode): Lib =
    var sq: seq[string] = @[]
    if node.hasKey("tags"):
        for n in node["tags"]:
            sq.add n.str
    result = Lib(
        name: node<>"name",
        url: node<>"url",
        meth: node<>"method",
        description: node<>"description",
        license: node<>"license",
        web: node<>"web",
        tags: sq
    )

proc deduplicate*(libs: seq[Lib]): seq[Lib] =
    result = @[]
    for lib in libs:
        if len(result.filter(proc(x: Lib): bool = x.name == lib.name)) == 0:
            result.add lib

proc pretty*(libs: openarray[Lib]): string =
    result = (%libs).pretty
