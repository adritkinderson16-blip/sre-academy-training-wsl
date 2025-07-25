#!/bin/bash

kubectl apply -f ../exercise4/deployment.yaml
kubectl apply -f ../exercise4/service.yaml
kubectl delete -f ../exercise5/prometheus.yaml
kubectl delete -f ../exercise6/grafana.yaml

kubectl apply -f ./cadvisor.yaml
kubectl apply -f ./prometheus.yaml
kubectl delete -f ./grafana.yaml
