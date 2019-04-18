---
title: Nginx进程模型
date: 2019-04-18 10:54:14
tags:
- nginx
categories:
- nginx
---

# 进程模型

Nginx是经典的多进程模型，Nginx启动后以daemon的方式在后台运行，后台进程包含一个master进程和多个worker进程，具体如下图：

![image](/images/nginx/nginx进程模型.png)

master进程主要用来管理worker进程，具体包括如下4个主要功能：
1. 接收来自外界的信号
2. 向各worker进程发送信号
3. 监控woker进程的运行状态
4. 当woker进程退出后（异常情况下），会自动重新启动新的woker进程

woker进程主要用来处理网络事件，各个woker进程之间是对等且相互独立的，它们同等竞争来自客户端的请求，一个请求只可能在一个woker进程中处理，woker进程个数一般设置为机器CPU核数。

# 进程控制

对Nginx进程的控制主要是通过master进程来做到的，主要有两种方式：
1. 手动发送信号

>master接收信号以管理众woker进程，那么，可以通过kill向master进程发送信号，比如kill -HUP pid用以通知Nginx从容重启。所谓从容重启就是不中断服务：master进程在接收到信号后，会先重新加载配置，然后再启动新进程开始接收新请求，并向所有老进程发送信号告知不再接收新请求并在处理完所有未处理完的请求后自动退出

2. 自动发送信号

>可以通过带命令行参数启动新进程来发送信号给master进程，比如./nginx -s reload用以启动一个新的Nginx进程，而新进程在解析到reload参数后会向master进程发送信号（新进程会帮我们把手动发送信号中的动作自动完成）。当然也可以这样./nginx -s stop来停止Nginx

# 网络事件

Nginx采用异步非阻塞的方式来处理网络事件，类似于Libevent，具体过程如下图：

![image](/images/nginx/nginx网络事件.png)

master进程先建好需要listen的socket后，然后再fork出多个woker进程，这样每个work进程都可以去accept这个socket。当一个client连接到来时，所有accept的work进程都会受到通知，但只有一个进程可以accept成功，其它的则会accept失败。Nginx提供了一把共享锁accept_mutex来保证同一时刻只有一个work进程在accept连接，从而解决惊群问题。当一个worker进程accept这个连接后，就开始读取请求，解析请求，处理请求，产生数据后，再返回给客户端，最后才断开连接，这样一个完成的请求就结束了。