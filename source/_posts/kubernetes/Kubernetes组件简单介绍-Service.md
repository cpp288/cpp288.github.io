---
title: Kubernetes组件简单介绍-Service
date: 2019-05-21 11:51:36
tags:
- Kubernetes
categories:
- Kubernetes
---

# 服务（Service）

[官方文档](https://kubernetes.io/docs/concepts/services-networking/service/)

由于一下原因，我们需要引入Service：
* pod是短暂的，它们随时会启动或者关闭
* Kubernetes在pod启动前会给已经调度到节点上的pod分配IP地址，因此客户端不能提前知道提供服务的pod的IP地址
* 水平伸缩意味着多个pod可能会提供相同的服务，每个pod都有自己的IP

![](/images/kubernetes/Service.png)

YAML描述文件：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  # ClientIP：特定客户端产生的所有请求每次都指向同一个pod
  # None：default
  sessionAffinity: ClientIP
  # 使得服务成为headless的
  # clusterIP: None
  # 通过标签选择器匹配pod
  selector:
    app: MyApp
  ports:
    # TCP（default）
  - name: http
    protocol: TCP
    # Service port
    port: 80
    # 转发到的容器端口
    targetPort: 9376
  - name: https
    protocol: TCP
    port: 443
    targetPort: 8443
```

**pod中可以使用端口命名，所以在Service中配置 `targetPort` 可以使用pod端口名称，方便端口维护**

我们也可以不使用标签选择器，而使用 `ExternalName` 来连接外部服务：

```yaml
...
spec: 
  type: ExternalName
  ExternalName: someapi.somcompany.com
  ports:
  - port: 80
...
```

ExternalName 服务仅在DNS级别实施（为Service创建了简单的CNAME DNS）

## endpoint

使用命令 `kubectl describe svc <service-name>` 可以看到 `Endpoint` 信息：

```yaml
...
Endpoints: 10.108.1.4:8080,10.108.2.5:8080
...
```

当service中定义了pod标签选择器，选择器用于构建IP和端口列表，存储在Endpoint资源中，如果service没有定义寻择期则不会创建Endpoint，我们可以手动创建：

```yaml
apiVersion: v1
kind: Endpoint
metadata:
  # Endpoint名称必须和Service的名称相匹配
  name: my-service
subsets: 
  - addresses: 
    - ip: 11.11.11.11
    - ip: 22.22.22.22
    ports: 
    - port: 80
```

![](/images/kubernetes/手动创建Endpoint.png)

## 暴露服务

向外部公开服务

### NodePort

每个集群节点都会在节点上打开一个端口，并将在该端口上接收到的流量重定向到基础服务，该服务仅在内部集群IP和端口上才可访问，但也可以通过所有节点上的专用端口访问

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec: 
  # 设置为 NodePort 服务类型
  type: NodePort
  selector:
      app: MyApp
  ports: 
  - port: 80
    targetPort: 8080
    # 通过集群节点的30123端口可以访问该服务，如果不指定会选择一个随机端口
    nodePort: 30123
```

这时EXTERNAL-IP显示<nodes>，我们可以通过 `EXTERNAL-IP:30123` 或者 `CLUSTER-IP:30123` 来访问服务

```
kubectl get svc my-service
NAME            CLUSTER-IP        EXTERNAL-IP   PORT(S)             AGE
my-service      10.111.254.223    <nodes>       80:30123/TCP        2m
```

![](/images/kubernetes/Service-NodePort.png)

### LoadBalancer

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec: 
  # 设置为 LoadBalancer 服务类型
  type: LoadBalancer
  selector:
      app: MyApp
  ports: 
  - port: 80
    targetPort: 8080
```

```
kubectl get svc my-service
NAME            CLUSTER-IP        EXTERNAL-IP          PORT(S)             AGE
my-service      10.111.254.223    130.211.53.173       80:30123/TCP        2m
```

可以通过负载均衡IP：130.211.53.173访问服务

![](/images/kubernetes/Service-LoadBalancer.png)

### Ingress

[官方文档](https://kubernetes.io/docs/concepts/services-networking/ingress/)

相比与 LoadBalancer 服务都需要自己的负载均衡器以及独有的公有IP地址，Ingress 只需要一个公网IP就能为许多服务提供访问

![](/images/kubernetes/Ingress暴露多个服务.png)

```yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: test-ingress
spec:
  # TLS配置
  tls:
  - hosts: 
    - test.example.com
    # 从 tls-secret 中获得私钥和证书
    secretName: tls-secret
  rules:
  # 将该域名映射到服务
  - host: test.example.com
    http:
      paths:
      # 将该路径的请求发送到test服务的80端口
      - path: /testpath
        backend:
          serviceName: test
          servicePort: 80
  - host: test2.example.com
      http:
        paths:
        - path: /testpath2
          backend:
            serviceName: test2
            servicePort: 80
```

Ingress执行流程：

![](/images/kubernetes/Ingress执行流程.png)