FROM node:8-jessie
RUN touch /etc/inside-container
WORKDIR /jps-explained
CMD ["bash"]
