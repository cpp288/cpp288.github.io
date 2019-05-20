---
title: Kubernetes组件简单介绍
date: 2019-05-17 16:48:01
tags:
- Kubernetes
categories:
- Kubernetes
---

# Pod

[官方文档](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/)

pod是一组并置的容器（由一个或多个组成），代表了 Kubernetes 中的基本构建模块，在实际应用中我们不会单独部署容器，都是针对一组pod的容器进行部署和操作

重要概念：
* 标签：使用标签进行pod的分组（通过标签选择器列出 `kubectl get po -l key=value`）
* 注解：与标签不同的是，注解可以容纳更多内容，主要用于工具使用，没有标签那样的选择器
* 命名空间：对资源进行分组

YAML描述文件创建pod：

```yaml
# 必选，版本号，例如v1
apiVersion: v1
# 必选，Pod
kind: Pod
# 必选，元数据
metadata: 
  # 必选，Pod名称
  name: string
  # 必选，Pod所属的命名空间
  namespace: string
  #	自定义标签
  labels: 
  - name: string
  # 自定义注释列表
  annotations: 
  - name: string
# 必选，Pod中容器的详细定义
spec:
  # 必选，Pod中容器列表
  containers: 
    # 必选，容器名称
  - name: string
    # 必选，容器的镜像名称
    image: string
    # 获取镜像的策略 Alawys表示下载镜像 IfnotPresent表示优先使用本地镜像，否则下载镜像，Nerver表示仅使用本地镜像
    imagePullPolicy: [Always | Never | IfNotPresent]
    # 容器的启动命令列表，如不指定，使用打包时使用的启动命令
    command: [string]
    # 容器的启动命令参数列表
    args: [string]
    # 容器的工作目录
    workingDir: string
    # 挂载到容器内部的存储卷配置
    volumeMounts: 
      # 引用pod定义的共享存储卷的名称，需用volumes[]部分定义的的卷名
    - name: string
      # 存储卷在容器内mount的绝对路径，应少于512字符
      mountPath: string
      # 是否为只读模式
      readOnly: boolean
    # 需要暴露的端口库号列表
    ports: 
      # 端口号名称
    - name: string
      # 容器需要监听的端口号
      containerPort: int
      # 容器所在主机需要监听的端口号，默认与Container相同
      hostPort: int
      # 端口协议，支持TCP和UDP，默认TCP
      protocol: string
    # 容器运行前需设置的环境变量列表
    env: 
      # 环境变量名称
    - name: string
      # 环境变量的值
      value: string
    # 资源限制和请求的设置
    resources: 
      # 资源限制的设置
      limits: 
      # cpu的限制，单位为core数，将用于docker run --cpu-shares参数
      cpu: string
      # 内存限制，单位可以为Mib/Gib，将用于docker run --memory参数
      memory: string
    # 资源请求的设置
    requests: 
      # cpu请求，容器启动的初始可用数量
      cpu: string
      # 内存请求，容器启动的初始可用数量
      memory: string
    # 对Pod内个容器健康检查的设置，当探测无响应几次后将自动重启该容器，检查方法有exec、httpGet和tcpSocket，对一个容器只需设置其中一种方法即可
    livenessProbe: 
      # 对Pod容器内检查方式设置为exec方式
      exec: 
        # exec方式需要制定的命令或脚本
        command: [string]
      # 对Pod内个容器健康检查方法设置为HttpGet，需要制定Path、port
      httpGet: 
        path: string
        port: number
        host: string
        scheme: string
        HttpHeaders:
        - name: string
          value: string
      # 对Pod内个容器健康检查方式设置为tcpSocket方式
      tcpSocket: 
         port: number
    # 容器启动完成后首次探测的时间，单位为秒
    initialDelaySeconds: 0
    # 对容器健康检查探测等待响应的超时时间，单位秒，默认1秒
    timeoutSeconds: 0
    # 对容器监控检查的定期探测时间设置，单位秒，默认10秒一次
    periodSeconds: 0
    successThreshold: 0
    failureThreshold: 0
    securityContext:
      privileged: false
  # Pod的重启策略，Always表示一旦不管以何种方式终止运行，kubelet都将重启，OnFailure表示只有Pod以非0退出码退出才重启，Nerver表示不再重启该Pod
  restartPolicy: [Always | Never | OnFailure] 
  # 设置NodeSelector表示将该Pod调度到包含这个label的node上，以key：value的格式指定
  nodeSelector: obeject   　　
  # Pull镜像时使用的secret名称，以key：secretkey格式指定
  imagePullSecrets: 
  - name: string
  # 是否使用主机网络模式，默认为false，如果设置为true，表示使用宿主机网络
  hostNetwork: false      　　
  # 在该pod上定义共享存储卷列表
  volumes: 
    # 共享存储卷名称 （volumes类型有很多种）
  - name: string
    # 类型为emtyDir的存储卷，与Pod同生命周期的一个临时目录。为空值
    emptyDir: {}
    # 类型为hostPath的存储卷，表示挂载Pod所在宿主机的目录
    hostPath: string
      # Pod所在宿主机的目录，将被用于同期中mount的目录
      path: string
    # 类型为secret的存储卷，挂载集群与定义的secret对象到容器内部
    secret: 
      scretname: string
      items: 
      - key: string
        path: string
    # 类型为configMap的存储卷，挂载预定义的configMap对象到容器内部
    configMap: 
      name: string
      items:
      - key: string
        path: string
```

# 控制器（Controllers）

## ReplicationController

[官方文档](https://kubernetes.io/docs/concepts/workloads/controllers/replicationcontroller/)

确保它的pod始终保持运行状态，如果pod因任何原因小时，ReplicationController会注意到缺少的pod并创建替代pod，原有pod将完全丢失

![](/images/kubernetes/ReplicationController协调流程.png)

YAML描述文件：

```yaml
apiVersion: v1
# ReplicationController类型
kind: ReplicationController
metadata:
  # ReplicationController名称
  name: nginx
spec:
  # pod实例的目标数据
  replicas: 2
  # pod选择器决定了RC的操作对象
  selector:                 
    app: nginx
  # 定义pod模板，在这里不需要定义pod名字，就算定义创建的时候也不会采用这个名字而是.metadata.generateName+5位随机数。
  template: 
    metadata:
      # 定义标签，这里必须和selector中定义的KV一样
      labels: 
        app: nginx
    spec:
      containers:
      - image: nginx
        name: nginx
        ports: 
        - containerPort: 80
```

注意：
* 修改RC中的pod模版只会影响后面创建的pod，原有pod不会更改
* 删除RC时，不会删除对应的pod，原因是RC创建的pod不是RC的组成部分，只是由其进行管理

## ReplicaSet

[官方文档](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)

可以完全替代 ReplicationController，ReplicaSet拥有更强的选择器表达能力

YAML描述文件：

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend
  labels:
    app: guestbook
    tier: frontend
spec:
  # modify replicas according to your case
  replicas: 3
  selector:
    matchLabels:
      tier: frontend
  template:
    metadata:
      labels:
        tier: frontend
    spec:
      containers:
      - name: php-redis
        image: gcr.io/google_samples/gb-frontend:v3
```

使用 matchExpressions 属性重写选择器：

```yaml
selector: 
  matchExpressions: 
  - key: app
    operator: In
    values: 
    - tier
```

操作符：
* In：Label的值必须与其中一个指定的values匹配
* NotIn：Label的值与任何指定的values不匹配
* Exists：pod必须包含一个指定名称的标签（值不重要），不需要指定values字段
* DoesNotExist：与Exists相反

## DaemonSet

[官方文档](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)

确保在集群的每个节点上运行一个pod（比如日志收集器、资源监控器），如果节点下线，DaemonSet不会在其它地方重建pod，但是当一个新节点加入时，DaemonSet会立刻部署一个新的pod实例在新节点上

![](/images/kubernetes/DaemonSet.png)

YAML描述文件：

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
  namespace: kube-system
  labels:
    k8s-app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec: 
      nodeSelector: 
        # 节点选择器，会选择有disk=ssd标签的节点
        disk: ssd
      containers:
      - name: fluentd-elasticsearch
        image: gcr.io/fluentd-elasticsearch/fluentd:v2.5.1
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
```

## Deployment

Deployment 是一种更高阶资源，用于部署应用并以声明的方式升级应用，而不是通过 ReplicationController 或 ReplicaSet 进行部署（更底层）

![](/images/kubernetes/Deployment.png)

Deployment 由 ReplicaSet 组成，并由它接管 Deployment 的 pod

YAML描述文件：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  # 指定新创建的pod至少要成功运行多久之后，才能将其视为可用，需要容器配置就绪探针
  # 当所有容器的就绪探针返回成功时，pod就被标记为就绪状态
  minReadySeconds: 10
  # 设置升级的超时时间
  progressDeadlineSeconds: 60
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80
        # 定义就绪探针
        readlinessProbe: 
          periodSeconds: 1
          httpGet: 
            path: /
            port: 8080
      strategy: 
        # 升级策略：[RollingUpdate(Default), Recreate]
        type: RollingUpdate
        RollingUpdate: 
          maxSurge: 1
          maxUnavailable: 0
```

升级策略：
* RollingUpdate（默认）：滚动更新
    * maxSurge
        > 决定了 Deployment 配置中期望的副本数之外，最多允许超出的pod实例的数量，默认值为25%（也可以是绝对值，比如最多多处一个或两个pod）
    * maxUnavailable
        > 决定了在滚动升级期间，相对于期望副本数能够允许有多少pod实例处于不可用状态，默认值为25%
* Recreate：一次性删除所有旧pod，创建新的pod

## Job

### Job（run to completion）

[官方文档](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/)

运行完成工作后即终止任务

![](/images/kubernetes/Job.png)

由Job管理的pod会一直被重新安排，直到它们成功完成任务

YAML描述文件：

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  template:
    spec:
      containers:
      - name: pi
        image: perl
        command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      # 重启策略：[OnFailure, Never, Always(Default)]
      restartPolicy: Never
  # 配置job在标记为失败之前可以重试的次数，默认为6
  backoffLimit: 4
  # 一个job运行多次，将顺序运行5个pod，如果其中一个pod发生故障，job会创建一个新的pod，所以job总共可以创建5个以上pod
  competions: 5
  # 最多2个pod可以平行运行
  parallelism: 2
  # 限制pod的时间，如果pod运行时间超过该时间，系统将尝试终止pod，并将job标记为失败
  activeDeadlineSeconds: 50
```

### Corn Job

[官方文档](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)

特定的时间运行或者在指定的时间间隔内重复运行

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: pi
spec:
  # 每天在每小时0，15，30，45分钟运行
  schedule: "0,15,30,45 * * * *"
  # pod最迟必须在预定时间后15秒开始运行，如果没有运行则任务将不会运行，并显示为Failed
  startingDeadlineSeconds: 15
  jobTemplate:
    spec:
      template: 
        metadata: 
          labels: 
            app: corn-job
        spec: 
          containers:
          - name: pi
            image: perl
            command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
          # 重启策略：[OnFailure, Never, Always(Default)]
          restartPolicy: Never
```