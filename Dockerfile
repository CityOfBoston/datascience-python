FROM ubuntu:18.04
MAINTAINER albert@boston.gov

# Ensure UTF-8 locale.
RUN apt-get clean && apt-get update && apt-get install -y --no-install-recommends apt-utils
RUN apt-get install -y locales
RUN apt-get update && apt-get install -y --no-install-recommends apt-utils
RUN locale-gen en_US.UTF-8

# Set environment variables for UTF-8, conda, and shell environments
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    CONDARC=/opt/conda/.condarc \
    BASH_ENV=/etc/profile \
    PATH=/opt/conda/bin:$PATH \
    CIVIS_CONDA_VERSION=4.3.30 \
    CIVIS_PYTHON_VERSION=3.6.4

RUN DEBIAN_FRONTEND=noninteractive apt-get update -y --no-install-recommends && \
  apt-get install -y --no-install-recommends software-properties-common && \
  apt-get install -y --no-install-recommends \
        make \
        automake \
        libpq-dev \
        libffi-dev \
        gfortran \
        g++ \
        git \
        libboost-program-options-dev \
        libtool \
        libxrender1 \
        wget \
        ca-certificates \
        curl && \
  apt-get clean -y && \
  rm -rf /var/lib/apt/lists/*

# Conda install.
RUN echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${CIVIS_CONDA_VERSION}-Linux-x86_64.sh && \
    /bin/bash /Miniconda3-${CIVIS_CONDA_VERSION}-Linux-x86_64.sh -b -p /opt/conda && \
    rm Miniconda3-${CIVIS_CONDA_VERSION}-Linux-x86_64.sh && \
    /opt/conda/bin/conda install --yes conda==${CIVIS_CONDA_VERSION} && \
    echo "conda ==${CIVIS_CONDA_VERSION}" > /opt/conda/conda-meta/pinned && \
    conda install --yes python==${CIVIS_PYTHON_VERSION} && \
    echo "python ==${CIVIS_PYTHON_VERSION}" >> /opt/conda/conda-meta/pinned && \
    conda clean --all -y && \
    ln -s /opt/conda/lib/libopenblas.so /opt/conda/lib/libblas.so && \
    ln -s /opt/conda/lib/libopenblas.so /opt/conda/lib/liblapack.so && \
    ln -s /opt/conda/lib/libssl.so /opt/conda/lib/libssl.so.6 && \
    ln -s /opt/conda/lib/libcrypto.so /opt/conda/lib/libcrypto.so.6

# Install boto in the base environment for private s3 channel support.
# Install Python Packages
COPY .condarc /opt/conda/.condarc
COPY environment.yml environment.yml
RUN conda install -y boto && \
    conda install -y nomkl && \
    conda env update -f environment.yml -n root && \
    conda clean --all -y && \
    rm -rf ~/.cache/pip

# We aren't running a GUI, so force matplotlib to use
# the non-interactive "Agg" backend for graphics.
# Run matplotlib once to build the font cache.
ENV MATPLOTLIBRC=${HOME}/.config/matplotlib/matplotlibrc
RUN mkdir -p ${HOME}/.config/matplotlib && \
    echo "backend      : Agg" > ${HOME}/.config/matplotlib/matplotlibrc && \
    python -c "import matplotlib.pyplot"

# Enable widgetsnbextension for jupyter widgets.
# See https://ipywidgets.readthedocs.io/en/stable/user_install.html.
# This enables the extension in the conda environment. The conda-forge version
# does this upon installation, but the default channel version doesn't seem to,
# so we'll run this (again) just in case.
RUN jupyter nbextension enable --py widgetsnbextension

# Instruct joblib to use disk for temporary files. Joblib defaults to
# /shm when that directory is present. In the Docker container, /shm is
# present but defaults to 64 MB.
# https://github.com/joblib/joblib/blob/0.11/joblib/parallel.py#L328L342
ENV JOBLIB_TEMP_FOLDER=/tmp

ENV VERSION=4.2.0 \
    VERSION_MAJOR=4 \
    VERSION_MINOR=2 \
    VERSION_MICRO=0
