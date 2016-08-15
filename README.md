# nimbler

package.json merger.

## Usage

```bash
% nimble search oauth
No package found.
% # Merge package.json of "CORDEA/nimbler" repository into ./nimble/package.json
% nimbler add "CORDEA/nimbler"
% nimble search oauth
oauth:
  url:         git@github.com:CORDEA/oauth.git (git)
  tags:        library
  description: OAuth library for nim
  license:     Apache License 2.0
  website:     http://cordea.github.io/oauth
```
