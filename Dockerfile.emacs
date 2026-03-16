FROM silex/emacs:master

# Install Python and trafilatura for URL capture
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install trafilatura
RUN pip3 install --no-cache-dir trafilatura>=2.0.0,<3.0.0

# Create app directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# Copy elisp source files
COPY app/elisp/ /app/elisp/

# Copy crontab
COPY crontab /etc/cron.d/sem-cron

# Set permissions for crontab
RUN chmod 0644 /etc/cron.d/sem-cron

# Create data directories
RUN mkdir -p /data/org-roam /data/elfeed /data/morning-read

# Install packages at build time - build fails if any package fails
RUN emacs --batch --no-site-file \
    --load /app/elisp/bootstrap-packages.el

# Set entrypoint to start cron and emacs in daemon mode
CMD ["sh", "-c", "service cron start && emacs --daemon"]
