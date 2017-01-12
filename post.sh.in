#!/bin/bash
# Use a post.sh script to put the generated list at the right location and
# reload DNSmasq. The first parameter is the full path ot the generated block
# list. The block.hosts file should be used in DNSmasq configuration with
# the addn-hosts parameter.

echo "Block list:" $1

# Example for DNSmasq on the same host. So use this create /etc/adblock folder
# and make sure it is writeable by the user running build.sh.
#cp -v "$1" /etc/adblock/block.hosts
#systemctl reload dnsmasq

# Example to transfer by SSH to a remote server with restart of DNSmasq. To
# use this, adapt the user and target IP according to your setup and make sure
# you have SSH key authentication (password less) in place.
#DST="root@192.168.1.3"
#scp "$1" $DST:/tmp/block.hosts
#ssh $DST "killall -HUP dnsmasq"
