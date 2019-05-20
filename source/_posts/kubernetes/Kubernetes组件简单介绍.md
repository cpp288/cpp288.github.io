---
title: Kubernetes组件简单介绍
date: 2019-05-17 16:48:01
tags:
- Kubernetes
categories:
- Kubernetes
---

# Pod

pod是一组并置的容器（由一个或多个组成），代表了 Kubernetes 中的基本构建模块，在实际应用中我们不会单独部署容器，都是针对一组pod的容器进行部署和操作

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