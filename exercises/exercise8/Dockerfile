FROM python:3.10

# Expose the Flask app port
EXPOSE 5000

# Set the working directory inside the container
WORKDIR /app

# Install Flask and OpenTelemetry libraries
RUN pip install flask \
    opentelemetry-api \
    opentelemetry-sdk \
    opentelemetry-exporter-otlp-proto-grpc \
    opentelemetry-instrumentation-flask

# Copy the application code into the container
COPY . .

# Set the default command to run the Flask app
CMD ["flask", "run", "--host", "0.0.0.0"]
