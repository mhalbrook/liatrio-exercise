ARG BASE_IMAGE_VERSION

FROM --platform=linux/amd64 python:3.10-slim

ARG PORT
ENV PORT=$PORT
ENV FLASK_APP="handler.py"

WORKDIR /app 

COPY requirements.txt requirements.txt

RUN pip3 install -r requirements.txt 

COPY . .

RUN chmod +x entrypoint.sh

ENTRYPOINT ./entrypoint.sh ${PORT}
