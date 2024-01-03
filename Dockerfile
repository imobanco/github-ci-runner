FROM python:3.9-slim-buster


# Set python environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV PIP_NO_CACHE_DIR 0
ENV PIP_DISABLE_PIP_VERSION_CHECK 1

ENV USER app_user

WORKDIR /home/app_user

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -y \
    ca-certificates \
 && apt-get -y autoremove \
 && apt-get -y clean  \
 && rm -rf /var/lib/apt/lists/*

RUN addgroup app_group \
 && adduser \
    --quiet \
    --disabled-password \
    --shell /bin/bash \
    --home /home/app_user \
    --gecos "User" app_user \
    --ingroup app_group \
 && chmod 0700 /home/app_user \
 && chown --recursive app_user:app_group /home/app_user

CMD ["/bin/bash"]
