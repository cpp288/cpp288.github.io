---
title: Redis集群主从复制原理
date: 2019-04-18 10:30:51
tags:
- redis
categories:
- redis
---

复制的作用是把redis的数据复制多个副本部署在不同的服务器上，如果其中一台服务器出现故障，也能快速迁移到其它服务器上提供服务。

主从复制就是我们常见的master/slave模式，主redis可以进行读写操作，当写操作导致数据发生变化时，会讲数据同步到从reids，而一般情况下，从redis是只读的，并接收主redis同步过来的数据。一个主redis可以有多个从redis

# 配置

在redis中配置master/slave是非常容易的，只需要在slave的配置文件中加入slaveof主redis的地址、端口。而master不需要做任何变化

比如两台服务器，分别安装redis：server01和server02，将server01作为master，server02作为slave，配置如下：
1. 在从节点server02的redis.conf文件中增加`slaveof server01-ip server01-port`
2. 将主节点server01的bindip注释掉，允许所有ip访问
3. 访问从节点server02的redis客户端，输入`INFO replication`，可以查看节点信息

# 原理（复制方式）

redis提供了3中主从复制方式：
1. 全量复制
2. 增量复制
3. 无硬盘复制

## 全量复制

Redis全量复制一般发生在Slave初始化阶段，这时Slave需要将Master上的所有数据都复制一份

![全量复制过程](/images/redis/全量复制过程.png)

完成上面几个步骤后就完成了slave服务器数据初始化的所有操作，savle服务器此时可以接收来自用户的读请求。

master/slave复制策略是采用乐观复制，也就是说可以容忍在一定时间内master/slave数据的内容是不同的，但是两者的数据会最终同步。具体来说，redis的主从同步过程本身是异步的，意味着master执行完客户端请求的命令后会立即返回结果给客户端，然后异步的方式把命令同步给slave。这一特征保证启用master/slave后master的性能不会受到影响。

另一方面，如果在这个数据不一致的窗口期间，master/slave因为网络问题断开连接，而这个时候，master 是无法得知某个命令最终同步给了多少个slave数据库。不过redis提供了一个配置项来限制只有数据至少同步给多少个slave的时候，master才是可写的:
* `min-slaves-to-write 3`：表示只有当3个或以上的slave连接到master，master才是可写的
* `min-slaves-max-lag 10`：表示允许slave最长失去连接的时间，如果10秒还没收到slave的响应，则master认为该slave以断开

## 增量复制

从redis 2.8开始，就支持主从复制的断点续传，如果主从复制过程中，网络连接断掉了，那么可以接着上次复制的地方，继续复制下去，而不是从头开始复制一份

master node会在内存中创建一个`backlog`，master和slave都会保存一个`replica offset`还有一个`master id`，offset就是保存在backlog中的。如果master和slave网络连接断掉了，slave会让master从上次的`replica offset`开始继续复制

但是如果没有找到对应的offset，那么就会执行一次全量同步

## 无硬盘复制

Redis复制的工作原理基于RDB方式的持久化实现的，也就是master在后台保存RDB快照，slave接收到rdb文件并载入，但是这种方式会存在一些问题：
1. 当master禁用RDB时，如果执行了复制初始化操作，Redis依然会生成RDB快照，当master下次启动时执行该 RDB文件的恢复，但是因为复制发生的时间点不确定，所以恢复的数据可能是任何时间点的。就会造成数据出现问题
2. 当硬盘性能比较慢的情况下(网络硬盘)，那初始化复制过程会对性能产生影响

因此2.8.18以后的版本，Redis引入了无硬盘复制选项，可以不需要通过RDB文件去同步，直接发送数据，通过以下配置来开启该功能：
```
repl-diskless-sync yes
```
master在内存中直接创建rdb，然后发送给slave，不会在落地到自己本地磁盘