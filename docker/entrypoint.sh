#!/bin/sh

# Enable strict mode (exit on error).
set -e

# The /tmp/.ssh directory is used to pass SSH keys to the container. If it is empty
# or does not exist, no SSH keys will be imported.
if [ -d "/tmp/.ssh" ] && [ "$(ls -A /tmp/.ssh 2>/dev/null)" ]; then

    # Copy all SSH keys from the temporary directory to the root's SSH directory.
    cp -R /tmp/.ssh/* /root/.ssh/

    # Ensure proper line breaks and line endings in all SSH key files.
    find /root/.ssh -type f -name "id_*" -exec dos2unix -q {} +

    # Set the required permissions for SSH key files.
    find /root/.ssh/ -type f -name "id_*" -exec chmod 600 {} +
    find /root/.ssh/ -type f -name "id_*.pub" -exec chmod 644 {} +

    # Start the ssh agent and add the keys to the current session.
    eval "$(ssh-agent)" > /dev/null
    find /root/.ssh -type f -name "id_*" ! -name "*.pub" -exec ssh-add -q {} \;
fi

# Set the required permissions for the SSH directory.
chmod 700 /root/.ssh

# Execute the command passed as arguments.
exec "$@"
