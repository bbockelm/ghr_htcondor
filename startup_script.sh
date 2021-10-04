cd /Users/condor/actions-runner
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

function timeout() { perl -e 'alarm shift; exec @ARGV' "$@"; }

while [ ! -e /Volumes/token_dir/register-token ];
do
  sleep 5
done

./config.sh --url https://github.com/htcondor --token $(cat /Volumes/token_dir/register-token) --ephemeral --name $(cat /Volumes/token_dir/worker_name) --unattended
hdiutil detach disk2
timeout 43200 ./run.sh
sleep 30
sudo shutdown -h now
