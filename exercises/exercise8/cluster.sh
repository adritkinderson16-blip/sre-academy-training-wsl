#!/bin/bash
kubectl delete -f ../exercise4/deployment.yaml;
kubectl delete -f ../exercise4/service.yaml;
kubectl delete -f deployment.yaml;
kubectl delete -f otel-collector.yaml;
kubectl delete -f ../exercise7/grafana.yaml;
sleep 5;
kubectl apply -f deployment.yaml;
kubectl apply -f otel-collector.yaml;
kubectl apply -f jaeger.yaml;
kubectl apply -f ../exercise7/grafana.yaml;
kubectl get pods -A