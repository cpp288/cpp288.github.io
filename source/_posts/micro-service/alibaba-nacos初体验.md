---
title: alibaba nacos初体验
date: 2019-03-06 19:19:46
tags: 
- 微服务
- 阿里技术
categories:
- 微服务
---

Nacos 是一个更易于帮助构建云原生应用的动态服务发现、配置和服务管理平台，提供「注册中心」、「配置中心」和「动态DNS服务」三大功能。

使用的相关版本：

- nacos server：0.9.0
- nacos client：0.9.1
- spring boot：1.5.17.RELEASE
- spring cloud：Edgware.SR4
- spring-cloud-starter-alibaba-nacos-discovery：0.1.1.RELEASE（对应spring boot 1.x版本）
- spring-cloud-starter-alibaba-nacos-config：0.1.1.RELEASE（对应spring boot 1.x版本）

nacos官方文档：https://nacos.io

部署nacos server，按照官方文档部署就行（分为单机部署和集群部署，两者的启动方式稍有不同）

下面介绍的是和spring cloud做集成

# 注册中心

## 对比

|比较点|Eureka|Zookeeper|Consul|Nacos|
|---|---|---|---|---|
|运维熟悉度|相对陌生|熟悉|更陌生|陌生|
|一致性（CAP）|AP|CP|AP|AP|
|一致性协议|HTTP 定时轮训|ZAB|RAFT|～|
|通讯方式|HTTP REST|自定义协议|HTTP REST|～|
|更新机制|Peer 2 Peer（服务器之间） + Scheduler（服务器和客户端）|ZK Watch|Agent 监听的方式|～|
|适用规模|< 30K|<20K|<5K|100K+|
|性能问题|简单的更新机制、复杂设计、规模较大时 GC 频繁  |扩容麻烦、规模较大时 GC 频繁 | 3K 节点以上，更新列表缓慢 |刚开源|
|dashboard|有|没有，可以自己实现|有|有|

各自缺点：

**Eureka：**

1. 客户端注册服务上报所有信息，节点多的情况下，网络，服务端压力过大，且浪费内存
2. 客户端更新服务信息通过简单的轮询机制，当服务数量巨大时，服务器压力过大。
3. 集群伸缩性不强，服务端集群通过广播式的复制，增加服务器压力
4. Eureka2.0 闭源（Spring Cloud最新版本还是使用的1.X版本的Eureka）

**Zookeeper：**

1. 维护成本较高，客户端，session状态，网络故障等问题，会导致服务异常
2. 集群伸缩性限制，内存，GC和连接
3. 主节点挂的情况下，会进行leader选举，在此过程中服务将不可用
4. 无控制台管理

**Consul：**

1. 未经大规模市场验证，无法保证可靠性
2. Go语言编写，内部异常排查困难

**Nacos：**

1. 刚刚开源不久，社区热度不够，依然存在bug

上面对比摘自与 [小马哥技术周报](https://github.com/mercyblitz/tech-weekly)

## 简单使用

加入依赖：

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
    <!-- spring boot 1.x使用0.1.x版本，spring boot 2.x使用0.2.x版本 -->
    <version>0.1.1.RELEASE</version>
    <exclusions>
        <exclusion>
            <groupId>com.alibaba.nacos</groupId>
            <artifactId>nacos-client</artifactId>
        </exclusion>
    </exclusions>
</dependency>
<!-- 这里需要替换 nacos-client 版本 -->
<dependency>
    <groupId>com.alibaba.nacos</groupId>
    <artifactId>nacos-client</artifactId>
    <version>0.9.1</version>
</dependency>
```

注意点：

1. spring-cloud-starter-alibaba-nacos-discovery 依赖的版本和 spring boot 版本有关
2. spring-cloud-starter-alibaba-nacos-discovery 默认使用的 nacos-client 的版本较低，会有问题（比如namespace设置无效），这里替换了较高的版本

application.properties：

```properties
spring.application.name=nacos-test
server.port=8525
# nacos server地址
spring.cloud.nacos.discovery.server-addr=192.168.173.80:8848
# namespace id
spring.cloud.nacos.discovery.namespace=077d70f7-e430-4b4c-926a-44a9bfef003c
```

其它配置可以参考官网

![](/images/micro-service/nacos/namespace.png)

注意：这里设置的namespace是界面上显示的id，不设置会进入public默认的命名空间

> namespace：常用场景之一是不同环境的注册的区分隔离，例如开发测试环境和生产环境的资源（如配置、服务）隔离等

启动服务：

![](/images/micro-service/nacos/nacos服务发现.png)

