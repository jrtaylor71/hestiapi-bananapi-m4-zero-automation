#!/usr/bin/expect -f
#
# start a process and background it after it reaches a certain stage
#
# From https://stackoverflow.com/questions/17916201/background-spawned-process-in-expect#32545624
#
spawn perl -e "\$SIG{HUP} = 'IGNORE'; for (\$a='A';; \$a++) {print qq/value is \$a\\n/; sleep 1;}"

set timeout 600

# Detailed log so we can debug (uncomment to enable)
# exp_internal -f /tmp/expect.log 0

# wait till the subprocess gets to "G"
expect -ex "value is G"

send_user "\n>>> expect: got G\n"

# when we get to G, background the process
expect_background

send_user ">>> spawned process backgrounding successful\n"
exit 0