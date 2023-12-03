FROM python:3.11

WORKDIR /app

COPY . /app

RUN pip install -r requirements.txt

# Attempt to remove url_quote references from installed packages
RUN find /usr/local/lib/python3.11/site-packages -type f -name '*.py' -exec sed -i '/url_quote/d' {} +

CMD ["python", "app.py"]
