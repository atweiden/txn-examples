#!/bin/bash

_dirs=($(find . -mindepth 1                     \
                -maxdepth 1                     \
                -type d ! \(    -name '.git'    \
                             -o -name '.peru'   \
                             -o -name '.subgit' \
                             -o -name '.subhg'  \
                             -o -name '.hg' \)  \
                             | sed 's,^./,,'))

for _dir in "${_dirs[@]}"; do
  find "$_dir" -mindepth 1 -maxdepth 1 -type f -name "*.tar.gz*" -exec rm '{}' +
  tar --exclude=PKGBUILD -cvzf "$_dir.tar.gz" "$_dir"
  gpg -u 0x3DBB92CDB1B08DAB --armor --sign "$_dir.tar.gz"
  mv "$_dir".tar.gz* "$_dir"
done
