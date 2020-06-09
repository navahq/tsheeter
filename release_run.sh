#!/usr/bin/env bash
set -ex

./prod/rel/tsheeter/bin/tsheeter eval "Tsheeter.Release.migrate"
./prod/rel/tsheeter/bin/tsheeter start