#!/bin/sh

if [ -x /usr/lib/duck-keyboard/system-setup.sh ]; then
    /usr/lib/duck-keyboard/system-setup.sh post-install /usr/bin/duck-keyboard || true
fi
exit 0
