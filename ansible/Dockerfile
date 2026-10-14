FROM alpine:latest

ARG USERNAME=yoda
ARG USER_HOME=/home/$USERNAME
ARG PUB_KEY_FILE=id_ed25519.pub

RUN apk add --no-cache openssh sudo python3~3.14

RUN ssh-keygen -A

RUN adduser -D -s /bin/sh $USERNAME && \
    echo "$USERNAME:$USERNAME" | chpasswd && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN mkdir -p $USER_HOME/.ssh && \
    chmod 700 $USER_HOME/.ssh

COPY ${PUB_KEY_FILE} $USER_HOME/.ssh/authorized_keys

RUN chmod 600 $USER_HOME/.ssh/authorized_keys && \
    chown -R $USERNAME:$USERNAME $USER_HOME/.ssh

RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]    