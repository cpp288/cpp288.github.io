---
title: Kubernetes架构介绍
date: 2019-05-23 11:33:15
tags:
- Kubernetes
categories:
- Kubernetes
---

Kubernetes集群分为两部分（[官网介绍](https://kubernetes.io/docs/concepts/overview/components/)）：
* 控制平面（Master components provide the cluster’s control plane）
    * etcd分布式持久化存储
    * API服务器（kube-apiserver）
    * 调度器（kube-scheduler）
    * 控制器管理器（kube-controller-manager）
* 工作节点（Node components run on every node）
    * kubelet
    * kube-proxy
    * 容器运行时（Container Runtime）

附加组件：
* Kubernetes DNS服务器
* Web UI (Dashboard)
* Ingress Controller
* 容器集群监控（Heapster）
* 容器网络接口插件

组件关系图：

![](/images/kubernetes/k8s组件关系图.png)

# etcd

Kubernetes所创建的对象（Pod、ReplicationController、Service、Secret等）需要以持久化方式存储到某个地方，这样它们在API服务器重启或者失败的时候才不会丢失，因此引入了etcd

etcd是一个响应快、分布式、一致的kv存储，可以运行多个etcd实例来获取高可用性和更好的性能，**etcd 是Kubernetes存储集群状态和元数据的唯一的地方**

唯一能直接和 etcd 通信的是API服务器，所有其他组件通过API服务器间接地读取、写入数据到 etcd，这带来一些好处：
* 增强乐观锁系统、验证系统的健壮性
* 通过把实际存储机制从其他组件抽离，未来替换起来也更容易

etcd 使用 RAFT 一致性算法（要求集群大部分节点参与才能进行到下一个状态），确保在任何时间点，每个节点的状态要么是大部分节点的当前状态，要么是之前确认过的状态

![](/images/kubernetes/etcd集群一致性.png)

# api server

api server 作为中心组件，其他组件或者客户端（如kubectl）都会去调用它（以Restful API形式）：

![](/images/kubernetes/apiserver调用流程示例.png)

* 通过认证插件认证客户端
> API 服务器会轮流调用这些插件，直到有一个能确认是谁发送了该请求，这是通过检查HTTP请求实现的
* 通过授权插件授权客户端
> 它们的作用是决定认证的用户是否可以对请求资源执行请求操作
* 通过准入控制插件验证AND/OR修改资源请求
> 如果请求尝试创建、修改或者删除一个资源，请求需要经过准入控制插件的验证，服务器会配置多个准入控制插件，这些插件会因为各种原因修改资源，可能会初始化资源定义中漏配的字段为默认值甚至重写它们，插件甚至会去修改并不在请求中的相关资源，同时也会因为某些原因拒绝一个请求。资源需要经过所有准入控制插件的验证（读取数据不会做准入控制的验证）
> 准入控制插件包括：AlwaysPullImages、ServiceAccount、NamespaceLifecycle等，具体查看[官网](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
* 验证资源以及持久化存储

其它客户端通过创建到 api server 的 HTTP 连接来监听变更，每当更新对象，api server会将新对象发送给监听了该对象的客户端（比如Controller、Kubectl等等），客户端接收到后执行相应任务

![](/images/kubernetes/apiserver-watch.png)

# 调度器（schedule）

通常我们不会去指定pod应该运行在哪个集群节点上，而是交给调度器来完成，调度器不会命令选中的节点（或者节点上的Kubelet）去运行pod，而是通过api server更新pod的定义，然后通知kubelet去创建并且运行pod的容器

调度器最为重要的是调度算法，找到pod最优节点，这个其它篇幅中说明

在集群中可以运行多个调度器，在pod中可以通过设置 `schedulerName` 属性来指定调度器，未设置由默认调度器调度（default-scheduler）