FROM python:3.12-alpine
WORKDIR /app
COPY index.html serve.py ./
COPY vendor ./vendor
EXPOSE 8000
CMD ["python3", "serve.py", "--host", "0.0.0.0", "-p", "8000"]