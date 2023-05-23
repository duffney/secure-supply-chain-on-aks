kubectl delete ConstraintTemplate ratifyverification
kubectl delete ConstraintTemplate ratifyverificationdeployment
helm uninstall gatekeeper -n gatekeeper-system
helm uninstall ratify --namespace gatekeeper-system
docker rmi -f $(docker images -aq)