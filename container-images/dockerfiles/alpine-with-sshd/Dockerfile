FROM alpine:3.14
RUN apk add --no-cache openssh-server

# Use the ssh-demo image's legacy keys. To generate new ones, can do something
# like:
# RUN ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -P ""
COPY keys/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
COPY keys/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub

# Allow root login via authorized keys only; explicitly disable password auth.
RUN printf '%s\n' \
        'PasswordAuthentication no' \
        'PermitRootLogin prohibit-password' \
        'PermitEmptyPasswords no' >> /etc/ssh/sshd_config \
    && passwd -d root

# Use the ssh-demo user/client's legacy keys. To generate new ones, can do
# something like:
# $ ssh-keygen -t ed25519 -f ccv0-ssh -P "" -C ""
COPY keys/ssh/ccv0-ssh.pub /root/.ssh/authorized_keys
RUN chmod 600 /etc/ssh/ssh_host_ed25519_key /root/.ssh/authorized_keys \
    && chmod 644 /etc/ssh/ssh_host_ed25519_key.pub \
    && chmod 700 /root/.ssh
ENTRYPOINT ["/usr/sbin/sshd", "-D"]
