FROM jenkins/jenkins:lts

USER root

# ==========================================
# Basic dependencies
# ==========================================

RUN apt-get update && \
    apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    unzip \
    git && \
    rm -rf /var/lib/apt/lists/*


# ==========================================
# Docker CLI
# ==========================================

RUN install -m 0755 -d /etc/apt/keyrings

RUN curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

RUN chmod a+r /etc/apt/keyrings/docker.gpg

RUN echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
    > /etc/apt/sources.list.d/docker.list

RUN apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*


# ==========================================
# Terraform
# ==========================================

ARG TERRAFORM_VERSION=1.15.8

RUN curl -fsSL \
    https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    -o /tmp/terraform.zip && \
    unzip /tmp/terraform.zip -d /usr/local/bin && \
    rm /tmp/terraform.zip


# ==========================================
# kubectl
# ==========================================

RUN curl -LO \
    "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

RUN install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

RUN rm kubectl


# ==========================================
# Verify tools
# ==========================================

RUN git --version
RUN docker --version
RUN terraform version
RUN kubectl version --client


USER jenkins
