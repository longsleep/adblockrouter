#!/bin/bash
#
# Adblockrouter script to grab and sort a list of adservers and
# malware, suitable for use in a DNS server like dnsmasq.
#
# Copyright (C) 2014  Simon Eisenmann <simon@longsleep.org>
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

# Get folders.
FOLDER=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TMPDIR=/tmp

# Delete the old block.hosts to make room for the update.
rm -f "$FOLDER/block.hosts"

echo 'Downloading hosts lists...'

# Download and process the files needed to make the lists (add more, if you want).
wget -qO- http://www.mvps.org/winhelp2002/hosts.txt| awk '/^0.0.0.0/' > /tmp/block.build.list
wget -qO- http://www.malwaredomainlist.com/hostslist/hosts.txt|awk '{sub(/^127.0.0.1/, "0.0.0.0")} /^0.0.0.0/' >> /tmp/block.build.list
wget -qO- "http://hosts-file.net/.\ad_servers.txt"|awk '{sub(/^127.0.0.1/, "0.0.0.0")} /^0.0.0.0/' >> /tmp/block.build.list

# This needs GNU wget since BusyBox wget doesn't handle https.
wget -qO- --no-check-certificate "https://adaway.org/hosts.txt"|awk '{sub(/^127.0.0.1/, "0.0.0.0")} /^0.0.0.0/' >> /tmp/block.build.list

# Add black list, if non-empty.
if [ -s "$FOLDER/black.list" ]
then
    echo 'Adding blacklist...'
    awk '/^[^#]/ { print "0.0.0.0",$1 }' "$FOLDER/black.list" >> "$TMPDIR/block.build.list"
fi

# Sort the download/black lists.
echo 'Sorting lists...'
awk '{sub(/\r$/,"");print $1,$2}' "$TMPDIR/block.build.list" | sort -u > "$TMPDIR/block.build.before"

# Add ipv6 support
echo 'Adding IPV6 support...'
sed -i -re 's/^(0\.0\.0\.0) (.*)$/\1 \2\n:: \2/g' "$TMPDIR/block.build.before"

if [ -s "$FOLDER/white.list" ]
then
    # Filter the blacklist, supressing whitelist matches.
    echo 'Filtering white list...'
    awk '/^[^#]/ {sub(/\r$/,"");print $1}' "$FOLDER/white.list" | grep -vf - "$TMPDIR/block.build.before" > "$FOLDER/block.hosts"
else
    cat "$TMPDIR/block.build.before" > "$FOLDER/block.hosts"
fi

# Delete files used to build list.
echo 'Cleaning up...'
rm -f "$TMPDIR/block.build.before"
rm -f "$TMPDIR/block.build.list"

if [ -x "$FOLDER/post.sh" ]
then
	. "$FOLDER/post.sh" "$FOLDER/block.hosts"
fi

echo "Done."
exit 0
