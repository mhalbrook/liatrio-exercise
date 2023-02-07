ARG BASE_IMAGE_VERSION
ARG PORT

FROM --platform=linux/amd64 python:$BASE_IMAGE_VERSION

WORKDIR /app 

COPY requirements.txt requirements.txt

RUN pip3 install -r requirements.txt 

COPY . .

RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
