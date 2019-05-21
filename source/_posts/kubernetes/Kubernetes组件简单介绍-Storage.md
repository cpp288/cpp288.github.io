---
title: Kubernetes组件简单介绍-Storage
date: 2019-05-21 13:39:51
tags:
- Kubernetes
categories:
- Kubernetes
---

# 卷（Volumes）

[官方文档](https://kubernetes.io/docs/concepts/storage/volumes/)

卷是pod的一个组成部分，定义在pod中，不是独立的kubernetes对象

在官网可以看到有很多Volume类型，这里只介绍其中的几种，其它可以查看官网

## emptyDir

特点：
* 卷从一个空目录开始，运行在pod内的应用程序可以读写
* 卷的生命周期和pod的生命周期相关联，当pod删除时，卷的内容就会丢失

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pd
spec:
  containers:
  - image: k8s.gcr.io/test-webserver
    name: test-container
    # 名为 cache-volume 的卷挂载在容器的 /cache 中
    volumeMounts:
    - mountPath: /cache
      name: cache-volume
  volumes:
    # 定义一个名为 cache-volume 的 emptyDir 卷
  - name: cache-volume
    emptyDir: {}
    # 指定介质，使用内存存储
    # emptyDir: 
    #   medium: Memory
```

## hostPath

大多数pod应该忽略它们的主机节点，因此不应该访问节点文件系统上的文件，但是一些系统级别的pod（通常由DaemonSet管理）需要读取节点的文件

**hostPath是一种持久性存储，不会因为pod的删除而丢失内容**

![](/images/kubernetes/Volume-hostPath.png)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pd
spec:
  containers:
  - image: k8s.gcr.io/test-webserver
    name: test-container
    volumeMounts:
    - mountPath: /test-pd
      name: test-volume
  volumes:
  - name: test-volume
    hostPath:
      # directory location on host
      path: /data
      # this field is optional
      type: Directory
```

## GCE

如果是在GCE（Google Kubernetes Engine）中运行的，那么可以使用GCE持久磁盘作为底层存储机制

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pd
spec:
  containers:
  - image: k8s.gcr.io/test-webserver
    name: test-container
    volumeMounts:
    - mountPath: /test-pd
      name: test-volume
  volumes:
  - name: test-volume
    # This GCE PD must already exist.
    gcePersistentDisk:
      pdName: my-data-disk
      # 文件系统类型
      fsType: ext4
```

# 持久卷（PV）和持久卷声明（PVC）

[官方文档](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

为了使应用能够正常请求存储资源，同时避免处理基础设施细节，引入了两个新的资源：持久卷（PV）和持久卷声明（PVC）

持久卷由集群管理员提供，并被pod通过持久卷声明来消费：

![](/images/kubernetes/PV和PVC.png)

创建持久卷（PV）：

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv0003
spec:
  capacity:
    # 定义大小
    storage: 5Gi
  accessModes:
      # 单个客户端挂载为读写模式
    - ReadWriteOnce
      # 多个客户端挂载为只读模式
    - ReadOnlyMany
  # 回收策略[Retain, Recycle, Delete]
  persistentVolumeReclaimPolicy: Recycle
  gcePersistentDisk:
    pdName: my-data-disk
    fsType: ext4
```

持久卷不属于任何命名空间，它跟节点一样是集群层面的资源：

![](/images/kubernetes/PV.png)

创建持久卷声明（PVC）：

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myclaim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
  selector:
    matchLabels:
      release: "stable"
    matchExpressions:
      - {key: environment, operator: In, values: [dev]}
```

Pod配置：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  containers:
    - name: myfrontend
      image: nginx
      volumeMounts:
      - mountPath: "/var/www/html"
        name: mypd
  volumes:
    - name: mypd
      persistentVolumeClaim:
        claimName: myclaim
```

相关文章：
* [PV、PVC、StorageClass，这些到底在说啥？](/file/kubernetes/PV、PVC、StorageClass，这些到底在说啥？.pdf)
* [PV、PVC体系是不是多此一举？从本地持久化卷谈起](/file/kubernetes/PV、PVC体系是不是多此一举？从本地持久化卷谈起.pdf)