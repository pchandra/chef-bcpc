# proxy setup
#
# Make sure this file defines CURL in any case
# Only define http_proxy if you will be using a proxy
#
# Sample setup using a local squid cache at 10.0.100.2 - the
# hypervisor. Change to reflect your real proxy info
#export PROXY="10.0.100.2:3128"

export CURL='curl'
if [ -n "$PROXY" ]; then
    
   echo "Setting up and testing proxy"
   
   export http_proxy=http://${PROXY}
   export https_proxy=https://${PROXY}
   
   # to ignore SSL errors
   export GIT_SSL_NO_VERIFY=true
   export CURL="curl -k -x http://${PROXY}"
   
   # sanity check
   $CURL -s --connect-timeout 1 http://www.ubuntu.com > /dev/null
   if [[ $? != 0 ]]; then
       echo "Error: proxy $PROXY not responding"
       exit 1
   else
       echo "Using a proxy at $PROXY"
   fi   
fi
