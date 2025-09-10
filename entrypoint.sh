#!/bin/sh

# Enable strict mode (exit on error).
set -e

# Copy all ssh keys to the home directory, as the temporary directory will be
# cleared within seconds afters starting the container.
cp -R /tmp/.ssh/* /root/.ssh/

# Ensure proper line breaks and line endings in all SSH key files.
find /root/.ssh -type f -name "id_*" -exec dos2unix -q {} +

# Set the required permissions for SSH key files.
chmod 700 /root/.ssh
find /root/.ssh/ -type f -name "id_*" -exec chmod 600 {} +
find /root/.ssh/ -type f -name "id_*.pub" -exec chmod 644 {} +

# Start the ssh agent and add the keys to the current session.
eval "$(ssh-agent)" > /dev/null
find /root/.ssh -type f -name "id_*" ! -name "*.pub" -exec ssh-add -q {} \;

# Execute the command passed as arguments.
exec "$@"
