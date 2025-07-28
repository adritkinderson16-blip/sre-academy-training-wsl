from flask import Flask, Response # Added Response for metrics endpoint
import random
import time
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.wsgi import OpenTelemetryMiddleware

# Prometheus client imports
from prometheus_client import generate_latest, Counter, Histogram, Gauge # Added Gauge for goo_call_count

import logging
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry._logs import set_logger_provider
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor

logger = logging.getLogger(__name__)
logging.basicConfig(filename='./logs/sre-app.log', encoding='utf-8', level=logging.DEBUG)
logger.debug('This message should go to the log file with Debug level')
logger.info('This message should go to the log file with Info level')
logger.warning('This message should go to the log file with Warn level')
logger.error('This message should go to the log file with Err level')

# Set up OpenTelemetry tracing with service name
resource = Resource.create({"service.name": "sre-abc-training-app"})

span_exporter = OTLPSpanExporter(
    endpoint="otel-collector.opentelemetry.svc.cluster.local:4317",
    insecure=True
)

tracer_provider = TracerProvider(resource=resource)
span_processor = BatchSpanProcessor(span_exporter)
tracer_provider.add_span_processor(span_processor)
trace.set_tracer_provider(tracer_provider)

# Get tracer
tracer = trace.get_tracer(__name__)

# Create and set the logger provider
logger_provider = LoggerProvider()
set_logger_provider(logger_provider)

# Set up OTLP Log Exporter for logs
log_exporter = OTLPLogExporter(
    endpoint="otel-collector.opentelemetry.svc.cluster.local:4317",
    insecure=True
)

# Set up log emitter provider and processor
log_processor = BatchLogRecordProcessor(log_exporter)
logger_provider.add_log_record_processor(log_processor)

# Set up logging to forward to OpenTelemetry Collector
otel_handler = LoggingHandler(logger_provider=logger_provider)
logging.getLogger().addHandler(otel_handler)

# Create Flask app
app = Flask(__name__)

# Instrument Flask with OpenTelemetry
FlaskInstrumentor().instrument_app(app)
app.wsgi_app = OpenTelemetryMiddleware(app.wsgi_app)

# --- Prometheus Metrics Setup ---
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP Requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'HTTP Request Latency', ['method', 'endpoint'])
GOO_CALL_COUNT = Gauge('goo_function_calls_total', 'Total calls to the goo function') # Gauge to track goo calls

# Counter to track calls to goo (for both internal logic and Prometheus)
goo_call_count_internal = 0

@app.route('/')
def hello_world():
    return 'Hello, World!'

stores = [
    {
        "name": "My Store",
        "items": [
            {
                "name": "Chair",
                "price": 15.99
            }
        ]
    }
]

# Helper functions with OpenTelemetry tracing
def zoo():
    with tracer.start_as_current_span("zoo") as span:
        delay = random.uniform(0, 5)  # Random delay between 0 and 5 seconds
        span.set_attribute("delay", delay)
        time.sleep(delay)
        logger.info(f"zoo executed with delay: {delay:.2f} seconds")
        return f"zoo executed in {delay:.2f} seconds"

def goo():
    global goo_call_count_internal
    goo_call_count_internal += 1
    GOO_CALL_COUNT.set(goo_call_count_internal) # Update Prometheus Gauge

    with tracer.start_as_current_span("goo") as span:
        try:
            if goo_call_count_internal % 5 == 0:
                raise ValueError(f"Exception raised in goo() on call {goo_call_count_internal}")
            
            result = zoo()
            span.add_event("Called zoo")
            logger.info("goo successfully called zoo")
            return f"goo called -> {result}"

        except Exception as e:
            span.record_exception(e)
            span.set_status(trace.status.Status(trace.status.StatusCode.ERROR, str(e)))
            logger.error(f"goo encountered an error: {e}")
            return f"goo encountered an error: {e}"

def foo():
    with tracer.start_as_current_span("foo") as span:
        result = goo()
        span.add_event("Called goo")
        logger.info("foo successfully called goo")
        return f"foo called -> {result}"

@app.get('/store')
def get_stores():
    start_time = time.time() # Start timer for latency
    REQUEST_COUNT.labels(method='GET', endpoint='/store').inc() # Increment request counter

    result = foo()
    
    latency = time.time() - start_time # Calculate latency
    REQUEST_LATENCY.labels(method='GET', endpoint='/store').observe(latency) # Observe latency

    return {"stores": stores, "operation": result}

# --- NEW: Prometheus metrics endpoint ---
@app.route('/metrics')
def metrics():
    # This route exposes the metrics collected by prometheus_client
    return Response(generate_latest(), mimetype='text/plain')

if __name__ == '__main__':
    # Ensure logs directory exists for the app.py
    import os
    logs_dir = './logs'
    if not os.path.exists(logs_dir):
        os.makedirs(logs_dir)
    
    app.run(host='0.0.0.0', port=5000)

