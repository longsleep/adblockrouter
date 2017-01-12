#!/bin/bash
#
# Adblockrouter script to grab and sort a list of adservers and
# malware, suitable for use in a DNS server like dnsmasq.
#
# Copyright (C) 2014-2017  Simon Eisenmann <simon@longsleep.org>
#
# Adblockrouter is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# Adblockrouter is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

set -e

FOLDER=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

BLACKLIST="$FOLDER/black.list"
WHITELIST="$FOLDER/white.list"
POSTSCRIPT="$FOLDER/post.sh"
MODE=dnsmasq
TARGET="$FOLDER/block.hosts"

function usage {
    echo "Usage: $0 [-m dnsmasq|unbound] [-t <target>]"
}

# Parse parameters
while [[ $# -gt 0 ]]; do
key="$1"
case $key in
    -m|--mode)
        MODE="$2"
        shift
        ;;
    -t|--target)
        TARGET="$2"
        shift
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        # unknown option
    ;;
esac
shift # past argument or value
done

# Tmp.
TMPDIR=$(mktemp -d -t adblockrouter.XXXXXXXXXX)
function cleanup {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

# Download and process the files needed to make the lists (add more, if you want).
echo '> Downloading hosts lists'
wget -qO- http://www.mvps.org/winhelp2002/hosts.txt| awk '/^0.0.0.0/' > $TMPDIR/block.build.list
wget -qO- http://www.malwaredomainlist.com/hostslist/hosts.txt|awk '{sub(/^127.0.0.1/, "0.0.0.0")} /^0.0.0.0/' >> $TMPDIR/block.build.list
wget -qO- "http://hosts-file.net/.\ad_servers.txt"|awk '{sub(/^127.0.0.1/, "0.0.0.0")} /^0.0.0.0/' >> $TMPDIR/block.build.list
wget -qO- --no-check-certificate "https://adaway.org/hosts.txt"|awk '{sub(/^127.0.0.1/, "0.0.0.0")} /^0.0.0.0/' >> $TMPDIR/block.build.list
wget -qO- "http://someonewhocares.org/hosts/hosts"|awk '{sub(/^127.0.0.1/, "0.0.0.0")} /^0.0.0.0/' >> $TMPDIR/block.build.list

# Add black list, if non-empty.
if [ -s "$BLACKLIST" ]
then
    echo '> Adding blacklist'
    awk '/^[^#]/ { print "0.0.0.0",$1 }' "$BLACKLIST" >> $TMPDIR/block.build.list
fi

# Sort the download/black lists.
echo '> Sorting'
awk '{sub(/\r$/,"");print $1,$2}' $TMPDIR/block.build.list | sort -u > $TMPDIR/block.build.before

if [ -s "$WHITELIST" ]
then
    # Filter according to whitelist matches.
    echo '> Applying whitelist'
    awk '/^[^#]/ {sub(/\r$/,"");print $1}' "$WHITELIST" | grep -vf - $TMPDIR/block.build.before > $TMPDIR/block.build
else
    cat "$TMPDIR/block.build.before" > $TMPDIR/block.build
fi

echo "> Output mode: $MODE"
case "$MODE" in
    dnsmasq)
        # Add ipv6 support
        sed -re 's/^(0\.0\.0\.0) (.*)$/\1 \2\n:: \2/g' $TMPDIR/block.build >$TMPDIR/block.hosts
        ;;
    unbound)
        sed -re 's/^(0\.0\.0\.0) (.*)$/local-data: \"\2 A \1\"\nlocal-data: \"\2 AAAA ::\"/g' $TMPDIR/block.build >$TMPDIR/block.hosts
        ;;
    *)
        echo "E: Unknown mode '$MODE'"
        exit 1
        ;;
esac

# Write output.
cp -f $TMPDIR/block.hosts "${TARGET}.new"
mv -f "${TARGET}.new" "$TARGET"

# Notify.
if [ -x "$POSTSCRIPT" ]
then
	. "$POSTSCRIPT" "$TARGET"
fi

echo "> Done"
exit 0
