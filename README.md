Envoy ratelimiter demo

Rate limiting globally via GRPC for istio 1.7.8
todo:// add local ratelimiter example

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


# to get metrics
> kubectl get -n ratelimiter
NAME                         READY   STATUS    RESTARTS   AGE
pyserver-5748b6d6c7-6wffr    2/2     Running   0          6m49s
ratelimit-57ffc99799-5m2vk   2/2     Running   2          14m
redis-7d757c948f-r8zg8       2/2     Running   0          14m
sleep-6bcb59b5bf-dgpwm       2/2     Running   0          6m49s

# the following stats are candidates to track
❯ kubectl exec sleep-6bcb59b5bf-dgpwm   -n ratelimiter -c istio-proxy -- pilot-agent request GET stats | grep pyserver      
...
cluster.outbound|80||pyserver.ratelimiter.svc.cluster.local.upstream_rq_200: 11
cluster.outbound|80||pyserver.ratelimiter.svc.cluster.local.upstream_rq_2xx: 11
cluster.outbound|80||pyserver.ratelimiter.svc.cluster.local.upstream_rq_429: 208
cluster.outbound|80||pyserver.ratelimiter.svc.cluster.local.upstream_rq_4xx: 208
cluster.outbound|80||pyserver.ratelimiter.svc.cluster.local.upstream_rq_active: 0
cluster.outbound|80||pyserver.ratelimiter.svc.cluster.local.upstream_rq_cancelled: 0
cluster.outbound|80||pyserver.ratelimiter.svc.cluster.local.upstream_rq_completed: 219
cluster.outbound|80||pyserver.ratelimiter.svc.cluster.local.upstream_rq_maintenance_mode: 0
cluster.outbound|80||pyserver.ratelimiter.svc.cluster.local.upstream_rq_max_duration_reached: 0
cluster.outbound|80||pyserver.ratelimiter.svc.cluster.local.upstream_rq_pending_active: 0
cluster.outbound|80||pyserver.ratelimiter.svc.cluster.local.upstream_rq_pending_failure_eject: 0
cluster.outbound|80||pyserver.ratelimiter.svc.cluster.local.upstream_rq_pending_overflow: 0
cluster.outbound|80||pyserver.ratelimiter.svc.cluster.local.upstream_rq_pending_total: 2
...

```