FROM perl:5

# Note that workdir is overridden during ordinary usage, i.e.
# docker run --rm -it -v "$PWD:$PWD" -w "$PWD" tvrenamer
WORKDIR /usr/src/app/

# Dependencies
COPY cpanfile  /usr/src/app/
RUN cpanm --cpanfile cpanfile --installdeps .

# Application
ENTRYPOINT ["/usr/src/app/tvrenamer.pl"]
COPY tvrenamer.pl /usr/src/app/