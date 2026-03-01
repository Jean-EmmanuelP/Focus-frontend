# Focus Voice Bot — Pipecat Cloud
# Base image handles bot.py discovery and serving automatically
FROM dailyco/pipecat-base:latest

COPY ./requirements.txt requirements.txt
RUN pip install --no-cache-dir --upgrade -r requirements.txt

COPY ./bot.py bot.py
