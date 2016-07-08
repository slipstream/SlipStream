#!/bin/bash

set -x
set -e

curl -fsSL -o /usr/bin/boot \
   https://github.com/boot-clj/boot-bin/releases/download/latest/boot.sh
chmod 755 /usr/bin/boot

export BOOT_AS_ROOT=yes
boot -h

cat > ~/.boot/profile.boot <<EOF
(configure-repositories!
 (fn [{:keys [url] :as repo-map}]
   (->> (condp re-find url
          #"^http://nexus\.sixsq\.com/"
          {:username "<<username>>"
           :password "<<password>>"}
          #".*" nil)
        (merge repo-map))))
EOF
