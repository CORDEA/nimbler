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
# date  :2016-07-07

import strutils

type SearchResponse* = ref object
    fullName*: string
    path*: string

proc toSearchResponse*(tsvString: string): SearchResponse =
    let tsv = tsvString.split("\t")
    assert len(tsv) == 2
    return SearchResponse(fullName: tsv[0], path: tsv[1])

proc toSearchResponses*(tsvLines: string): seq[SearchResponse] =
    result = @[]
    for line in tsvLines.splitLines:
        if line == "":
            continue
        let sr = line.toSearchResponse()
        result.add sr
