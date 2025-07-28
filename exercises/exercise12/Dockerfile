FROM python:3.10

# Expose the Flask app port
EXPOSE 5000

# Set the working directory inside the container
WORKDIR /app

# Install Flask and OpenTelemetry libraries
RUN pip install flask==3.0.3 \
    opentelemetry-api==1.27.0 \
    opentelemetry-sdk==1.27.0 \
    opentelemetry-exporter-otlp-proto-grpc==1.27.0 \
    opentelemetry-instrumentation-flask==0.48b0 \
    opentelemetry-instrumentation-wsgi==0.48b0 \
    opentelemetry-instrumentation-logging==0.48b0 \
    opentelemetry-exporter-otlp==1.27.0

# Copy the application code into the container
COPY . .

# Ensure the log directory exists
RUN mkdir -p /app/logs

# Make sure the application has write permission to the log file
RUN chmod -R 777 /app/logs

# Set the default command to run the Flask app
CMD ["flask", "run", "--host", "0.0.0.0"]
