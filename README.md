Envoy ratelimiter demo

```
# fyi I am using python 3.9.6 and assume you have some sort of local kubernetes setup, or have access to EKS, etc. I also assume you have some working knowledge of kubernetes and istio/envoy.

# it's always a good idea to create a virtualenv, and remember to activate it, go into your code repo / root folder
> python3 -m venv ~/.venvs/circuitbreaker
source  ~/.venvs/ratelimiter/bin/activate

If you are are like most of us, you have performed some actions that override default pip - https://confluence.grainger.com/display/PLE/Using+AWS+CodeArtifact#UsingAWSCodeArtifact-PIPPIP

so you must dpctl pip-login first then:

# install flask and requests
> pip3 install flask
> pip3 install requests   

# to depoly onto minikube remember to set the minikube docker context; this is so that your minikube has access to your docker image
> eval $(minikube -p minikube docker-env)  

# then build the docker images for the test apps
# server
> docker build -t pyserver . 

## minikube 
# create a new namespace
> kubectl create namespace ratelimiter

# enable sidecar injection
> kubectl label namespace ratelimiter istio-injection=enabled --overwrite

# check to see if your namespace, circuitbreaker is enabled
> kubectl get namespace -L istio-injection

# deploy the apps, the ratelimiter, and apply the envoyfilter 
> kubectl apply -f deployment/deployment.yml -n ratelimiter
> kubectl apply -f deployment/deployment_ratelimiter.yml -n ratelimiter
> kubectl apply -f deployment/envoy_filter.yml -n ratelimiter

# curl the internal app a few times, you wil get a 429, too many requests
> kubectl exec "$(kubectl get pod -l app=sleep -n ratelimiter -o jsonpath={.items..metadata.name})" -c sleep -n ratelimiter -- curl -vvv  http://pyserver/index
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0*   Trying 10.101.104.112:80...
* Connected to pyserver (10.101.104.112) port 80 (#0)
> GET /index HTTP/1.1
> Host: pyserver
> User-Agent: curl/7.77.0
> Accept: */*
>
<h1>Service Available</h1>* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< content-type: text/html; charset=utf-8
< content-length: 26
< server: envoy
< date: Mon, 09 Aug 2021 19:34:02 GMT
< x-envoy-upstream-service-time: 6
<
{ [26 bytes data]
100    26  100    26    0     0   3190      0 --:--:-- --:--:-- --:--:--  3714
* Connection #0 to host pyserver left intact

> kubectl exec "$(kubectl get pod -l app=sleep -n ratelimiter -o jsonpath={.items..metadata.name})" -c sleep -n ratelimiter -- curl -vvv  http://pyserver/index
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0*   Trying 10.101.104.112:80...
* Connected to pyserver (10.101.104.112) port 80 (#0)
> GET /index HTTP/1.1
> Host: pyserver
> User-Agent: curl/7.77.0
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 429 Too Many Requests
< x-envoy-ratelimited: true
< date: Mon, 09 Aug 2021 19:34:03 GMT
< server: envoy
< content-length: 0
< x-envoy-upstream-service-time: 16
<
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
* Connection #0 to host pyserver left intact

```