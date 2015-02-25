set -e;

init_wercker_environment_variables() {
    if [ -z "$GEKKIE_DOKKU_DEPLOY_APP" ]; then
        if [ -n "$DOKKU_APP" ]; then
            export GEKKIE_DOKKU_DEPLOY_APP="$DOKKU_APP";
        else
            fail "Missing or empty option app. $error_suffix";
        fi
    fi

    if [ -z "$GEKKIE_DOKKU_DEPLOY_HOST" ]; then
        if [ -n "$DOKKU_DEPLOY_HOST" ]; then
            export GEKKIE_DOKKU_DEPLOY_HOST="$DOKKU_DEPLOY_HOST";
        else
            fail "Missing or empty option host. $error_suffix";
        fi
    fi

    if [ -z "$GEKKIE_DOKKU_DEPLOY_HOST_PUBLIC_KEY" ]; then
     	if [ -n "$DEPLOY_HOST_PUBLIC_KEY" ]; then
            export GEKKIE_DOKKU_DEPLOY_HOST_PUBLIC_KEY="$DEPLOY_HOST_PUBLIC_KEY";
            debug "option public_key found. Will add it as the public key";
        else
            debug "option public_key not set. Will deploy to the host ignoring the fingerprint. This could be dangerous!";
        fi
    else
        debug "option public_key found. Will add it as the public_key";
    fi

    if [ -z "$GEKKIE_DOKKU_DEPLOY_KEY_NAME" ]; then
        if [ -n "$DOKKU_DEPLOY_KEY_NAME" ]; then
            export GEKKIE_DOKKU_DEPLOY_KEY_NAME="$DOKKU_DEPLOY_KEY_NAME";
        else
            fail "Missing or empty option key_name. $error_suffix";
        fi
    fi

    if [ -z "$GEKKIE_DOKKU_DEPLOY_USER" ]; then
        if [ -n "$DOKKU_USER" ]; then
            export GEKKIE_DOKKU_DEPLOY_USER="$DOKKU_USER";
        else
            export GEKKIE_DOKKU_DEPLOY_USER="dokku";
        fi
    fi

    if [ -z "$GEKKIE_DOKKU_DEPLOY_SOURCE_DIR" ]; then
        export GEKKIE_DOKKU_DEPLOY_SOURCE_DIR="$WERCKER_ROOT";
        debug "option source_dir not set. Will deploy directory $GEKKIE_DOKKU_DEPLOY_SOURCE_DIR";
    else
        warn "Use of source_dir is deprecated. Please make sure that you fix your dokku deploy version on a major version."
        debug "option source_dir found. Will deploy directory $GEKKIE_DOKKU_DEPLOY_SOURCE_DIR";
    fi
}

init_ssh() {
 	local public_key="$1";
 	local host="$2";

    mkdir -p $HOME/.ssh;
    if [ -n "$public_key" ]; then
		touch $HOME/.ssh/known_hosts;
		chmod 600 $HOME/.ssh/known_hosts;
    	echo $public_key >> $HOME/.ssh/known_hosts;
	else
		echo -e "Host $host\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
	fi
}

init_git() {
    local username="$1";

    if ! type git &> /dev/null; then
        debug "git not found; installing it"

        sudo apt-get update;
        sudo apt-get install git-core;
    else
        debug "git is already installed; skipping installation"
    fi

    git config --global user.name "$username";
}

init_gitssh() {
    local gitssh_path="$1";
    local ssh_key_path="$2";

    echo "ssh -e none -i \"$ssh_key_path\" \$@" > $gitssh_path;
    chmod 0700 $gitssh_path;
    export GIT_SSH="$gitssh_path";
}

use_GEKKIE_ssh_key() {
    local ssh_key_path="$1";
    local GEKKIE_ssh_key_name="$2";

    debug "will use specified key in key-name option: ${GEKKIE_ssh_key_name}_PRIVATE";

    local private_key=$(eval echo "\$${GEKKIE_ssh_key_name}_PRIVATE");

    if [ -z "$private_key" ]; then
        fail 'Missing key error. The key-name is specified, but no key with this name could be found. Make sure you generated an key, and exported it as an environment variable.';
    fi

    debug "writing key file to $ssh_key_path";
    echo -e "$private_key" > $ssh_key_path;
    chmod 0600 "$ssh_key_path";
}

push_code() {
    local dokku_host="$1";
    local dokku_user="$2";
    local app_name="$3";

    debug "starting dokku deployment with git push";
    git push -f $dokku_user@$dokku_host:$app_name HEAD:master;
    local exit_code_push=$?;

    debug "git pushed exited with $exit_code_push";
    return $exit_code_push;
}

execute_dokku_command() {
    local dokku_host="$1";
    local dokku_user="$2";
    local command="$3";

    debug "NOT READY YET, SHOULD BE A ssh $dokku_user@$dokku_host $command?";
    return 1;
}

use_current_git_directory() {
    local working_directory="$1";
    local branch="$2";

    local current_working_directory=$(pwd);

    debug "keeping git repository"
    if [ -d "$working_directory/.git" ]; then
        debug "found git repository in $working_directory";
    else
        fail "no git repository found to push";
    fi

    git checkout $branch
}

use_new_git_repository() {
    local working_directory="$1"

    local current_working_directory=$(pwd)

    # If there is a git repository, remove it because
    # we want to create a new git repository to push
    # to dokku.
    if [ -d "$working_directory/.git" ]; then
        debug "found git repository in $working_directory"
        warn "Removing git repository from $working_directory"
        rm -rf "$working_directory/.git"

        #submodules found are flattened
        if [ -f "$working_directory/.gitmodules" ]; then
            debug "found possible git submodule(s) usage"
            while IFS= read -r -d '' file
            do
                rm -f "$file" && warn "Removed submodule $file"
            done < <(find "$working_directory" -type f -name ".git" -print0)
        fi
    fi

    # Create git repository and add all files.
    # This repository will get pushed to dokku.
    git init
    git add .
    git commit -m 'wercker deploy'
}

test_authentication() {
	local gitssh_path="$1";
    local dokku_host="$2";
    local dokku_user="$3";
    local app_name="$4";
#
#    set +e;
#    ssh -t -i $gitssh_path $dokku_user@$dokku_host > /dev/null 2>&1;
#    local exit_code_authentication_test=$?;
#    set -e;
#
#    if [ $exit_code_authentication_test -ne 0 ]; then
#        fail 'Unable to login using your provided credentials, please update your dokku host, username etc';
#    fi
}

# === Main flow starts here ===
ssh_key_path="$(mktemp -d)/id_rsa";
gitssh_path="$(mktemp)";
error_suffix='Please add this option to the wercker.yml or add a dokku deployment target on the website which will set these options for you.';
exit_code_push=0;
exit_code_run=0;

# Initialize some values
init_wercker_environment_variables;
init_ssh "$GEKKIE_DOKKU_DEPLOY_HOST_PUBLIC_KEY" "$GEKKIE_DOKKU_DEPLOY_HOST";
init_git "$GEKKIE_DOKKU_DEPLOY_USER";
init_gitssh "$gitssh_path" "$ssh_key_path";

cd $GEKKIE_DOKKU_DEPLOY_SOURCE_DIR || fail "could not change directory to source_dir \"$GEKKIE_DOKKU_DEPLOY_SOURCE_DIR\""

# Test credentials
use_GEKKIE_ssh_key "$ssh_key_path" "$GEKKIE_DOKKU_DEPLOY_KEY_NAME";
test_authentication "$ssh_key_path" "$GEKKIE_DOKKU_DEPLOY_HOST" "$GEKKIE_DOKKU_DEPLOY_USER" "$GEKKIE_DOKKU_DEPLOY_APP";

# Then check if the user wants to use the git repository or use the files in the source directory
if [ "$GEKKIE_DOKKU_DEPLOY_KEEP_REPOSITORY" == "true" ]; then
    use_current_git_directory "$GEKKIE_DOKKU_DEPLOY_SOURCE_DIR" "$WERCKER_GIT_BRANCH";
else
    use_new_git_repository "$GEKKIE_DOKKU_DEPLOY_SOURCE_DIR";
fi

# Try to push the code
set +e;
push_code "$GEKKIE_DOKKU_DEPLOY_HOST" "$GEKKIE_DOKKU_DEPLOY_USER" "$GEKKIE_DOKKU_DEPLOY_APP";
exit_code_push=$?
set -e;

# Retry pushing the code, if the first push failed and retry was not disabled
if [ $exit_code_push -ne 0 ]; then
    if [ "$GEKKIE_DOKKU_DEPLOY_RETRY" == "false" ]; then
        info "push failed, not going to retry";
    else
        info "push failed, retrying push in 5 seconds";
        sleep 5;

        set +e;
        push_code "$GEKKIE_DOKKU_DEPLOY_HOST" "$GEKKIE_DOKKU_DEPLOY_USER" "$GEKKIE_DOKKU_DEPLOY_APP";
        exit_code_push=$?
        set -e;
    fi
fi

# Run a command, if the push succeeded and the user supplied a run command
if [ -n "$GEKKIE_DOKKU_DEPLOY_RUN" ]; then
    if [ $exit_code_push -eq 0 ]; then
        set +e;
        execute_dokku_command "$GEKKIE_DOKKU_DEPLOY_HOST" "$GEKKIE_DOKKU_DEPLOY_USER" "$GEKKIE_DOKKU_DEPLOY_RUN";
        exit_code_run=$?
        set -e;
    fi
fi

if [ $exit_code_run -ne 0 ]; then
    fail 'dokku run failed';
fi

if [ $exit_code_push -eq 0 ]; then
    success 'deployment to dokku finished successfully';
else
    fail 'git push to dokku failed';
fi
