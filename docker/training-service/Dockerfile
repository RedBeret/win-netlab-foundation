FROM python:3.12-slim

WORKDIR /app
COPY app.py /app/app.py

EXPOSE 8080

HEALTHCHECK CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=2).read()"

CMD ["python", "/app/app.py"]

