# Base image
FROM pytorch/pytorch:1.9.0-cuda10.2-cudnn7-runtime

# Ensure noninteractive apt installs and use bash for RUN so conda works later
ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]

# Copy files (Singularity %files)
COPY cli.sh /cli.sh

COPY old_requirements.txt /requirements.txt

# Environment (Singularity %environment)
ENV SINGULARITY=true \
PATH="$PATH:/GloVe/build"

# Make CLI executable (part of %post)
RUN chmod u+x /cli.sh

# Update & base packages
RUN apt-get update && \
apt-get install -y --no-install-recommends \
wget curl git build-essential cmake \
graphviz zip unzip vim libexpat1-dev \
gnupg bash sudo && \
rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir dgl-cu102 -f https://data.dgl.ai/wheels/repo.html 
RUN pip install --no-cache-dir -r /requirements.txt


# Install GloVe (from source)
RUN cd / && \
    git clone https://github.com/stanfordnlp/GloVe.git && \
    cd GloVe && make

# Build & install cppcheck 2.5 from source
RUN cd / && \
    curl -L https://github.com/danmar/cppcheck/archive/refs/tags/2.5.tar.gz -o cppcheck2.5.tar.gz && \
    mkdir -p /cppcheck && mv cppcheck2.5.tar.gz /cppcheck && \
    cd /cppcheck && tar -xzf cppcheck2.5.tar.gz && \
    cd cppcheck-2.5 && mkdir build && cd build && \
    cmake .. && cmake --build . && make install && \
    rm -rf /cppcheck

# Install Joern (non-interactive script drive similar to %post)
# Note: Running as root in Docker, so no sudo needed.
RUN apt-get update && apt-get install -y --no-install-recommends openjdk-8-jdk && \
    rm -rf /var/lib/apt/lists/* && \
    cd / && \
    wget https://github.com/ShiftLeftSecurity/joern/releases/latest/download/joern-install.sh && \
    chmod +x ./joern-install.sh && \
    printf 'Y\n/bin/joern\ny\n/usr/local/bin\n\n' | ./joern-install.sh --interactive && \
    rm -f /joern-install.sh

# Install Miniconda (silent) and put it on PATH
ENV CONDA_DIR=/root/miniconda3
ENV PATH=$CONDA_DIR/bin:$PATH
RUN cd / && \
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash Miniconda3-latest-Linux-x86_64.sh -b -p "$CONDA_DIR" && \
    rm -f Miniconda3-latest-Linux-x86_64.sh && \
    conda clean -y --all

# Install RATS (from archived tarball)
RUN cd / && \
    curl -L https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/rough-auditing-tool-for-security/rats-2.4.tgz -o rats-2.4.tgz && \
    tar -xzf rats-2.4.tgz && \
    cd rats-2.4 && ./configure && make && make install && \
    cd / && rm -rf rats-2.4 rats-2.4.tgz

# Python tools & dependencies
# - flawfinder via pip
# - requirements (kept same name mapping as Singularity)
# - DGL CUDA 10.2 wheel
# - pygraphviz via conda (conda-forge for reliability)
# - NLTK + punkt
RUN pip install --no-cache-dir flawfinder
# RUN conda install -y -c conda-forge pygraphviz 
RUN pip install --no-cache-dir nltk

RUN python -c 'import nltk; nltk.download("punkt")' && \
    conda clean -y --all && \
    rm -rf /root/.cache/pip

# Default working directory
RUN mkdir -p linevd
WORKDIR /linevd

# Run script (Singularity %runscript)
# ENTRYPOINT ["/bin/bash", "/cli.sh"]
# ENTRYPOINT ["bash"]
# If you prefer to allow overriding while still defaulting, you could use:
# CMD []
