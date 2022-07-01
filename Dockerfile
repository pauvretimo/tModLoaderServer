######## DOWNLOAD BUILDER ########

FROM ubuntu as build

ARG TMOD_VERSION=2022.06.96.3
ARG TERRARIA_VERSION=1436

RUN apt update
RUN apt install -y dirmngr gnupg apt-transport-https ca-certificates software-properties-common
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
RUN apt-add-repository -y 'deb https://download.mono-project.com/repo/ubuntu stable-focal main'
RUN apt install -y mono-complete 
RUN apt install -y curl unzip

WORKDIR /terraria-server/terraria

RUN cp /usr/lib/libMonoPosixHelper.so .

RUN curl -SLO "https://terraria.org/api/download/pc-dedicated-server/terraria-server-${TERRARIA_VERSION}.zip" &&\
    unzip terraria-server-*.zip &&\
    rm terraria-server-*.zip &&\
    cp --verbose -a "${TERRARIA_VERSION}/Linux/." . &&\
    rm -rf "${TERRARIA_VERSION}" &&\
    rm TerrariaServer.exe

WORKDIR ../tModLoader

RUN curl -SLO "https://github.com/tModLoader/tModLoader/releases/download/v${TMOD_VERSION}/tModLoader.zip" &&\
    unzip tModLoader.zip &&\
    chmod u+x start-tModLoaderServer.sh &&\
    chmod u+x start-tModLoader.sh


######## FINAL IMAGE ########

### .NET Windows official image
FROM mcr.microsoft.com/dotnet/aspnet:6.0.6-bullseye-slim-amd64

# Set environment variables
ENV USER root
ENV HOME /root

# Set working directory
WORKDIR $HOME

# Insert Steam prompt answers
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN echo steam steam/question select "I AGREE" | debconf-set-selections \
 && echo steam steam/license note '' | debconf-set-selections

# Update the repository and install SteamCMD
ARG DEBIAN_FRONTEND=noninteractive
RUN dpkg --add-architecture i386 \
 && apt-get update -y \
 && apt-get install -y --no-install-recommends ca-certificates locales steamcmd \
 && rm -rf /var/lib/apt/lists/*

# Add unicode support
RUN locale-gen en_US.UTF-8
ENV LANG 'en_US.UTF-8'
ENV LANGUAGE 'en_US:en'

# Create symlink for executable
RUN ln -s /usr/games/steamcmd /usr/bin/steamcmd

# Update SteamCMD and verify latest version
RUN steamcmd +quit



WORKDIR /tmod-util

COPY Setup_tModLoaderServer.sh install.txt ./
RUN chmod u+x Setup_tModLoaderServer.sh &&\
    ./Setup_tModLoaderServer.sh


WORKDIR ../terraria-server
COPY --from=build /terraria-server ./

RUN apk update &&\
    apk add --no-cache procps tmux
RUN ln -s ${HOME}/.local/share/Terraria/ /terraria
COPY inject.sh /usr/local/bin/inject
COPY handle-idle.sh /usr/local/bin/handle-idle

EXPOSE 7777
ENV TMOD_SHUTDOWN_MSG="Shutting down!"
ENV TMOD_AUTOSAVE_INTERVAL="*/10 * * * *"
ENV TMOD_IDLE_CHECK_INTERVAL=""
ENV TMOD_IDLE_CHECK_OFFSET=0

COPY config.txt entrypoint.sh ./
RUN chmod +x entrypoint.sh /usr/local/bin/inject /usr/local/bin/handle-idle

ENTRYPOINT [ "/terraria-server/entrypoint.sh" ]
