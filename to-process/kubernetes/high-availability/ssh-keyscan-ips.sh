IPS=( "$@" )

for IP in ${IPS[@]}
do
  ssh-keyscan -H "${IP}" >> ~/.ssh/known_hosts
done
