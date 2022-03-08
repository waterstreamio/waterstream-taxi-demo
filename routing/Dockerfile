FROM io.simplematter/openrouteservice-misses-libraries

USER root
# install missing libraries needed to build the graph, etc from the .pbf file
RUN apt-get update -qq && apt-get install -qq -y libxext6 libxrender1 libxtst6 libxi6
