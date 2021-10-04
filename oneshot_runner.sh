#!/bin/sh -x

VMName=BigSurCI

VBoxManage snapshot $VMName list > /dev/null
snapshot_result=$?
if [ $snapshot_result -ne 0 ]; then
  VBoxManage snapshot $VMName take $VMName-pre
elif VBoxManage snapshot BigSurCI list --machinereadable | grep -q '^CurrentSnapshotName="'$VMName'-pre"'; then
  VBoxManage snapshot $VMName restore $VMName-pre
else
  VBoxManage snapshot $VMName take $VMName-pre
fi

/bin/echo -n "Authorization: token " > token_header
cat gh_token >> token_header

mkdir -p token_dir
echo "Condor-Worker-$RANDOM" > token_dir/worker_name
curl -X POST -H @token_header -H "Accept: application/vnd.github.v3+json"   https://api.github.com/orgs/htcondor/actions/runners/registration-token | jq  .token | tr -d '"' > token_dir/register-token
rm token_image.iso
hdiutil makehybrid -iso -joliet -o token_image.iso token_dir
VBoxManage storageattach $VMName --storagectl SATA --port 1 --device 0 --type dvddrive --medium token_image.iso
VBoxManage startvm $VMName

declare -i last_query
last_query=0

function check_worker_id () {
  if [ "x$worker_id" == "x" ]; then
    worker_id=`curl -X GET -H @token_header -H "Accept: application/vnd.github.v3+json"   https://api.github.com/orgs/htcondor/actions/runners | jq '.runners[] | select(.name  == "'$(cat token_dir/worker_name)'") .id'`
  fi
}

declare -i worker_idle_timeout
max_idle_time=39600
# Uncomment for testing.
# max_idle_time=60
worker_idle_timeout=$max_idle_time+`date '+%s'`

declare -i worker_kill_timeout
max_runtime=46800
# Uncomment for testing.
# max_runtime=180
worker_kill_timeout=$max_runtime+`date '+%s'`

while VBoxManage showvminfo --machinereadable $VMName | grep '^VMState=' | grep -q '"running"'; do
  sleep 5
  last_query=$last_query+5
  if [ $last_query -ge 30 ]; then
    last_query=0

    check_worker_id
    if [ "x$worker_id" != "x" ]; then
      is_busy=`curl -X GET -H @token_header -H "Accept: application/vnd.github.v3+json" https://api.github.com/orgs/htcondor/actions/runners/$worker_id | jq .busy`
      echo "Worker is busy: $is_busy"
      if [ `date '+%s'` -gt $worker_idle_timeout ] && [ "$is_busy" == "false" ]; then
        curl -X DELETE -H @token_header -H "Accept: application/vnd.github.v3+json" https://api.github.com/orgs/htcondor/actions/runners/$worker_id
        unset worker_id
      fi
    fi
    if [ `date '+%s'` -gt $worker_kill_timeout ]; then
      VBoxManage controlvm $VMName poweroff
      exit 1
    fi
  fi
done
VBoxManage showvminfo --machinereadable $VMName | grep '^VMState='


if [ "x$worker_id" != "x" ]; then
  curl -X DELETE -H @token_header -H "Accept: application/vnd.github.v3+json" https://api.github.com/orgs/htcondor/actions/runners/$worker_id
fi

