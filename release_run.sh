#!/usr/bin/env bash
set -ex

./prod/rel/tsheeter/bin/tsheeter eval "Tsheeter.Release.Migrate"
./prod/rel/tsheeter/bin/tsheeter start