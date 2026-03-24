#!/bin/sh

if [ -x /usr/lib/duck-keyboard/system-setup.sh ]; then
    /usr/lib/duck-keyboard/system-setup.sh pre-remove /usr/bin/duck-keyboard || true
fi
exit 0
