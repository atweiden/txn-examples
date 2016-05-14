#!/bin/bash

_fail=0
_dirs=($(find . -mindepth 1                     \
                -maxdepth 1                     \
                -type d ! \(    -name '.git'    \
                             -o -name '.peru'   \
                             -o -name '.subgit' \
                             -o -name '.subhg'  \
                             -o -name '.hg'     \)))

for _dir in "${_dirs[@]}"; do
  pushd $_dir
  makepkg -Acs -f
  [[ $? != 0 ]] && _fail+=1
  popd
done

[[ $_fail > 0 ]] && echo failed
