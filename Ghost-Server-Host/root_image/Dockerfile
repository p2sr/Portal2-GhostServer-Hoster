FROM ubuntu

# Install dependencies
RUN \
    apt-get update && \
    apt-get install -y libsfml-dev g++ make curl nginx build-essential pkg-config python3 python3-setuptools
    
# Install Node.js
RUN \
	curl -sL https://deb.nodesource.com/setup_16.x | bash - && \
    apt-get -y install nodejs && \
    # Configure nodejs + install global dependencies
    # npm config set unsafe-perm true && \
    npm install -g typescript node-gyp
