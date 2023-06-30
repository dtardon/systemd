#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-2.1-or-later
set -ex
set -o pipefail

# shellcheck source=test/units/util.sh
. "$(dirname "$0")"/util.sh

: >/failed

systemd-analyze log-level debug

export SYSTEMD_LOG_LEVEL=debug

run_test() {
    systemd-run --wait -p User=test83 \
        busctl call io.systemd.test.TestBusPolkit /io/systemd/test/TestBusPolkit io.systemd.test.TestBusPolkit "$1"
}

cleanup() {
    set +e

    systemctl stop mock-polkit.service
    systemctl stop test-bus-polkit.service
    userdel -r test83
    rm -f \
        /etc/dbus-1/system.d/io.systemd.test.TestBusPolkit.conf \
        /etc/dbus-1/system.d/org.freedesktop.PolicyKit1.conf \
        /etc/dbus-1/system-services/org.freedesktop.PolicyKit1.service

    return 0
}

mkdir -p /var/spool/cron /var/spool/mail
useradd -m -s /bin/bash test83
#useradd -m -s /bin/bash -N -g nobody test83

trap cleanup EXIT

mkdir -p /etc/dbus-1/system.d /etc/dbus-1/system-services
cp \
    /usr/lib/systemd/tests/testdata/units/io.systemd.test.TestBusPolkit.conf \
    /usr/lib/systemd/tests/testdata/units/org.freedesktop.PolicyKit1.conf \
    /etc/dbus-1/system.d
cp /usr/lib/systemd/tests/testdata/units/org.freedesktop.PolicyKit1.service /etc/dbus-1/system-services

systemctl start test-bus-polkit.service

run_test TestNoPolkit

systemctl start mock-polkit.service

run_test TestAllowed
run_test TestDenied
# run_test TestInteractive
# run_test TestUnknown

touch /testok
rm /failed

exit 0
