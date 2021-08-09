FROM python:3.9.6-alpine
WORKDIR /project
ADD ./server.py /project
ADD ./requirements.txt /project
RUN pip install -r requirements.txt

EXPOSE 5000

ENTRYPOINT [ "python" ]
CMD [ "server.py" ]