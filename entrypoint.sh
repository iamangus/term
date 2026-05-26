#!/bin/bash
set -eu

sudo useradd -s $(which zsh) -m ${USER_NAME}

sudo chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME} 

sudo echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USER_NAME}

sudo chsh -s $(which zsh)

[ -d /home/$USER_NAME/.ssh ] || su $USER_NAME --command "mkdir -p ~/.ssh && chmod 700 ~/.ssh"

[ -f /home/$USER_NAME/.ssh/authorized_keys ] || su $USER_NAME --command "curl https://github.com/$GH_USER_NAME.keys | tee -a ~/.ssh/authorized_keys"

# Start OpenChamber as the user if a UI password is provided
su ${USER_NAME} --command "nohup /usr/local/bin/openchamber --host 0.0.0.0 >/dev/null 2>&1 &"

/usr/sbin/sshd -D
