---
title: Kubernetes架构
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