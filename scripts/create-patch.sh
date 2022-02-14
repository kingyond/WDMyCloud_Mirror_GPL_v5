#!/bin/bash

cd files/kernel/linux4.14.22
git diff --quiet --exit-code .config || git diff --relative --src-prefix=a/ --dst-prefix=b/ .config > config-20220122.patch
cd ../../..

cd files/firmware/module
git diff --quiet --exit-code crfs/script/iptables_install.sh || git diff --relative --src-prefix=a/ --dst-prefix=b/ crfs/script/iptables_install.sh > iptables_install-20220209.patch
cd ../../..

