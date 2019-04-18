---
title: Nginx之Openresty最佳实践
date: 2019-04-18 10:58:43
tags:
- nginx
categories:
- nginx
---

我们都知道Nginx有很多的特性和好处，但是在Nginx上开发成了一个难题，Nginx模块需要用C开发，而且必须符合一系列复杂的规则，最重要的用C开发模块必须要熟悉Nginx的源代码，使得开发者对其望而生畏。为了开发人员方便，所以接下来我们要介绍一种整合了Nginx和lua的框架，那就是OpenResty，它帮我们实现了可以用lua的规范开发，实现各种业务，并且帮我们弄清楚各个模块的编译顺序。关于OpenResty，我想大家应该不再陌生，随着系统架构的不断升级、优化，OpenResty在被广泛的应用。

Openresty是一个通过Lua扩展Nginx实现的可伸缩的Web平台，内部集成了大量精良的Lua库、第三方模块以及大多数的依赖项。用于方便的搭建能够处理超高并发、扩展性极高的动态Web应用、Web服务和动态网关。

官网：http://openresty.org

官方中文文档：https://openresty.org/download/agentzh-nginx-tutorials-zhcn.html

案例汇总：https://blog.csdn.net/forezp/article/details/78616856

执行模块流程：

![image](/images/nginx/Openresty执行模块流程.png)

Nginx本身在处理一个用户请求时，会按照不同的阶段进行处理，总共分为11个阶段。而Openresty的执行指令，就是在这11个步骤中挂载lua脚本实现扩展：

1. init_by_lua：当Nginx master进程加载配置文件时会运行该lua脚本，一般用来注册全局变量或者预加载lua模块
2. init_worker_by_lua：每个Nginx worker进程启动时会执行的lua脚本，可以用来做健康检查
3. set_by_lua：设置变量
4. rewrite_by_lua：在rewrite阶段执行，为每个请求执行指定的lua脚本
5. access_by_lua：为每个请求在访问阶段调用lua脚本
6. content_by_lua：通过lua脚本生成content输出给http响应
7. balancer_by_lua：实现动态负载均衡，如果不走conten_by_lua，则走proxy_pass，在通过upstream进行转发
8. header_filter_by_lua：通过lua来设置headers或者cookie
9. body_filter_by_lua：对响应数据进行过滤
10. log_by_lua：在log阶段执行的脚本，一般用来做数据统计，将请求数据传输到后端进行分析