#!/bin/bash

# Change this to change the default message committed to Gitlab
DEFAULT_COMMIT_MSG="Minor change - debugging or syntax"

# Colours
CRESET="\033[0m"
CBOLD="\033[1m"
CGRN="\033[0;32m"
CYEL="\033[0;33m"
CBLU="\033[0;34m"
CLBLU="\033[0;36m"

# Main logic
function dst() {
	if [[ -n $1 ]]; then
		case "$1" in
			reset )
				dst_cmd_reset
				;;
			set )
				case "$2" in
					cfg)
						dst_cmd_set_cfg
						;;
					env)
						dst_cmd_set_env
						;;
					*)
						dst_cmd_help
						;;
				esac
				;;
			run )
				dst_cmd_run
				;;
			push )
				if [[ -n $2 ]]; then
					dst_cmd_push $2
				else
					dst_cmd_push $DEFAULT_COMMIT_MSG
				fi
				;;
			*)
				dst_cmd_help
				;;
		esac
	else
		dst_cmd_help
	fi
}

function dst_cmd_help() {
	# add reset cfg
	echo
	echo "${CGRN}Available commands:${CRESET}"
	echo "  dst \t${CBOLD}set${CRESET}"
	echo "\t\t${CBOLD}cfg${CRESET}\t${CYEL}->${CRESET} Set permanent variables such as LDAP username, active Datalake server etc."
	echo "\t\t${CBOLD}env${CRESET}\t${CYEL}->${CRESET} Set variables related to the script(s) currently being worked on"
	echo "\t${CBOLD}run${CRESET}\t\t${CYEL}->${CRESET} Without committing any files to Gitlab, run our script remotely"
	echo "\t${CBOLD}push${CRESET}\t\t${CYEL}->${CRESET} Run \"git add\", \"git commit\" and \"git push\" before then running \"dst run\""
	echo "\t${CBOLD}reset${CRESET}\t\t${CYEL}->${CRESET} Unset all environment variables and delete all files related to this set of commands"
	echo "\t${CBOLD}help${CRESET}\t\t${CYEL}->${CRESET} This short manual page"
	echo
	echo "For more information, view the README.md file at this URL: ${CBOLD}https://gitlab.com/repo/shell-aliases${CRESET}"
}

function dst_cmd_reset() {
	dst_int_header "Reset all configuration"

	echo "This command will unset all variables related to \"dst\" commands, including your .dstenv file. Are you sure you want to do this?"
	echo "  (Type \"Y\" to proceed, any other key to cancel):"
	read truevar
	if [[ $truevar == "Y" ]]; then
		if echo $SHELL | grep zsh; then
			SHELL_PROFILE=$HOME/.zshrc
		else
			SHELL_PROFILE=$HOME/.bashrc
		fi

		rm -f $DST_CFG_ENV_FILE
		unset DST_CFG_LDAP_USERNAME
		unset DST_CFG_ENV_FILE
		unset DST_CFG_TMP_SCRIPT_FILE
		if [[ "$OSTYPE" == "linux-gnu" ]]; then
			sed -i.bak "\:source $DST_CFG_FILE:d" $SHELL_PROFILE
		else
			sed -i.bak '' "\:source $DST_CFG_FILE:d" $SHELL_PROFILE
		fi
		rm -f $DST_CFG_FILE
		unset DST_CFG_FILE
		
		echo "Environment variables have been unset and all traces of this set of commands has been removed from your profile files, etc."
	fi
}

function dst_cmd_set_cfg() {
	dst_int_header "Set configuration variables"

	echo "What is your LDAP username? E.g. firstname.surname"
	read LDAP_USERNAME
	echo "Where would you like to store the environment files related to these DST_x commands?"
	echo "  Default is your home directory, ${CBOLD}${HOME}${CRESET}"
	read ENV_DIR

	if [[ -n $LDAP_USERNAME ]]; then
		# Deal with environment variable storage
		if [[ -z $ENV_DIR ]]; then
			ENV_DIR=$HOME
		fi

		ENV_FILE=$ENV_DIR/.dstenv
		CFG_FILE=$ENV_DIR/.dstcfg
		TMP_SCRIPT_FILE=$ENV_DIR/.dsttmpscript.sh

		touch $CFG_FILE

		# Add config file location to shell profile
		if echo $SHELL | grep zsh; then
			SHELL_PROFILE=$HOME/.zshrc
		else
			SHELL_PROFILE=$HOME/.bashrc
		fi

		echo "source ${CFG_FILE}" >> $SHELL_PROFILE

		# Add environment variables to config file
		echo "export DST_CFG_LDAP_USERNAME=${LDAP_USERNAME}" >> $CFG_FILE
		echo "export DST_CFG_ENV_FILE=${ENV_FILE}" >> $CFG_FILE
		echo "export DST_CFG_FILE=${CFG_FILE}" >> $CFG_FILE
		echo "export DST_CFG_TMP_SCRIPT_FILE=${TMP_SCRIPT_FILE}" >> $CFG_FILE

		# Load environment variables into current shell
		source $CFG_FILE

		dst_int_create_env_file

		echo "Configuration file and environment file have been created; all variables have been sourced into current shell."
		echo "Please run 'dst set env' to continue."
	else
		dst_int_error "LDAP username is required for SSH"
		return
	fi
}

function dst_cmd_set_env() {
	dst_int_header "Set environment variables"
	dst_int_check_env

	echo "What branch are you working on?"
	read BRANCH
	echo "Which server does this script run on? (Just 'server-1' or 'server-2' etc, no need for full domain)"
	read ACTIVE_SERVER
	echo "Which directory is the repository stored in on the remote server?"
	read REMOTE_DIR
	echo "What command do you use to run this script?"
	read SCRIPT_CMD

	if [[ $BRANCH == "master" ]]; then
		dst_int_error "master branch can't be used with these commands. Please use a feature branch"
		return
	fi

	if [[ -n $BRANCH ]] && [[ -n $ACTIVE_SERVER ]] && [[ -n $SCRIPT_CMD ]] && [[ -n $REMOTE_DIR ]]; then
		if [[ $BRANCH == "master" ]]; then
			dst_int_error "master branch can't be used with these commands. Please use a feature branch"
			return
		fi

		# Create clean environment file
		dst_int_create_env_file

		echo "DST_ENV_BRANCH=${BRANCH}" >> $DST_CFG_ENV_FILE
		echo "DST_ENV_REMOTE_DIR=${REMOTE_DIR}" >> $DST_CFG_ENV_FILE
		echo "DST_ENV_ACTIVE_SERVER=${ACTIVE_SERVER}" >> $DST_CFG_ENV_FILE
		echo "DST_ENV_SCRIPT_CMD=\"${SCRIPT_CMD}\"" >> $DST_CFG_ENV_FILE
		
		echo "Environment variables have been set and stored in $DST_CFG_ENV_FILE"
	else
		dst_int_error "Answers are required on all questions"
		return
	fi
}

function dst_cmd_run() {
	dst_int_header "Run"
	dst_int_check_env

	source $DST_CFG_ENV_FILE

	if [[ -n $DST_CFG_LDAP_USERNAME ]]; then
		if [[ -n $DST_ENV_ACTIVE_SERVER ]] && [[ -z $DST_ENV_REMOTE_DIR ]] || [[ -z $DST_ENV_BRANCH ]] || [[ -z $DST_ENV_SCRIPT_CMD ]]; then
			dst_int_error "Environment variables aren't set. Please run 'dst set env' before this command"
			return
		fi
			
		# Create a temporary script file to send over SSH
		echo "cd $DST_ENV_REMOTE_DIR" > $DST_CFG_TMP_SCRIPT_FILE
		echo "git pull origin $DST_ENV_BRANCH" >> $DST_CFG_TMP_SCRIPT_FILE
		echo "git checkout $DST_ENV_BRANCH" >> $DST_CFG_TMP_SCRIPT_FILE
		echo "$DST_ENV_SCRIPT_CMD" >> $DST_CFG_TMP_SCRIPT_FILE

		# Send commands from local script over SSH
		echo "Running commands over SSH..."
		ssh $DST_CFG_LDAP_USERNAME@$DST_ENV_ACTIVE_SERVER.fqdn 'bash -s' < $DST_CFG_TMP_SCRIPT_FILE

		# Clear up our temporary script file
		rm $DST_CFG_TMP_SCRIPT_FILE
	else
		dst_int_error "Required config variables aren't set. Please run 'dst set cfg' before this command"
		return
	fi
}

function dst_cmd_push() {
	dst_int_header "Push"
	dst_int_check_env

	source $DST_CFG_ENV_FILE

	if [[ -d .git ]]; then
		dst_int_error "This directory is not a root-level Git repository"
		return
	fi

	if [[ `git branch --list $DST_ENV_BRANCH` ]]; then
		git checkout $DST_ENV_BRANCH
		git add .
		git commit -m "$1"
		git push origin $DST_ENV_BRANCH

		echo "Changes committed"

		dst_cmd_run
	else
		dst_int_error "Branch ${DST_ENV_BRANCH} doesn't exist in this repository. Please re-run dst set env and specify the correct branch, or make sure you're in the right directory"
		return
	fi
}

function dst_int_header() {
	echo
	echo "${CBOLD}Function: ${CYEL}${1}${CRESET}"
	echo
}

function dst_int_error() {
	echo
	echo "${CRED}Error: ${CBOLD}${1}${CRESET}"
	echo "Exiting..."
	echo
}

function dst_int_check_env() {
	if [[ -z $DST_CFG_ENV_FILE ]]; then
		dst_int_error "No DST-related environment variable storage files can be found. Please run 'dst set cfg' before this command"
		return
	fi
}

function dst_int_create_env_file() {
	# Remove any existing environment files; start afresh
	rm -f $DST_CFG_ENV_FILE
	touch $DST_CFG_ENV_FILE
	echo "# dst command environment storage file" > $DST_CFG_ENV_FILE
	echo "#   created `date`\n" >> $DST_CFG_ENV_FILE
}
