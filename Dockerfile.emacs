FROM silex/emacs:master

# Install Python and trafilatura for URL capture
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    python3 \
    python3-pip \
    git \
    cron \
    && rm -rf /var/lib/apt/lists/*


# Cron stuff
RUN mkfifo --mode 0666 /var/log/cron.log

# https://github.com/moby/moby/issues/5663#issuecomment-42550548
RUN sed --regexp-extended --in-place \
    's/^session\s+required\s+pam_loginuid.so$/session optional pam_loginuid.so/' \
    /etc/pam.d/cron

# Install uv
COPY --from=ghcr.io/astral-sh/uv:0.10.9 /uv /uvx /bin/

# Install trafilatura
RUN uv tool install -q "trafilatura>=2.0.0,<3.0.0"

# Create app directory
WORKDIR /app

# Copy elisp source files
COPY app/elisp/ /app/elisp/

# Copy crontab
COPY crontab /etc/cron.d/sem-cron

# Set permissions for crontab
RUN chmod 0744 /etc/cron.d/sem-cron

# Copy start-cron wrapper script
COPY dev/start-cron /usr/local/bin/start-cron
RUN chmod +x /usr/local/bin/start-cron

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Create data directories
RUN mkdir -p /data/org-roam /data/elfeed /data/morning-read

# Install packages at build time - build fails if any package fails
RUN emacs --batch --no-site-file \
    --load /app/elisp/bootstrap-packages.el

# Set entrypoint to start cron and emacs in daemon mode
CMD ["/usr/local/bin/start-cron"]
