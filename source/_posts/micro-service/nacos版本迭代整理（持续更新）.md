---
title: nacos版本迭代整理（持续更新）
date: 2019-03-07 17:50:13
tags:
- nacos
- 微服务
- 阿里技术
categories:
- 微服务
---

官方文档：https://nacos.io/zh-cn/index.html

官方博客：https://nacos.io/zh-cn/blog/index.html

核心功能：
* 注册中心
* 配置中心

nacos服务监控：https://nacos.io/zh-cn/docs/monitor-guide.html

# 0.9.0

发布时间：2019.2.28

* [Nacos 0.9.0 发布，稳定的快速迭代](https://nacos.io/en-us/blog/nacos0.9.0.html)
* [Nacos 0.9.0版本发布啦](https://nacos.io/en-us/blog/nacos0.9-intro.html)

更新内容：
1. Nacos-Sync稳定性提升
2. **Nacos Server功能拆分部署（通过启动参数实现拆分部署）**
    > 启动Nacos server时候，增加-f参数，意思是function mode，和对应模块标示来进行启动，如果不穿，或者传入有误，都将启动全部功能。 配置中心参数对应config，注册中心参数对应naming
3. Nacos python语言体系的支持

# 1.0.0

发布时间：2019.4.10

* [Nacos 发布 1.0.0 GA 版本，可大规模投入到生产环境](https://mp.weixin.qq.com/s/SaS9JBBjiN-ac6nfpq2ACw)

# 相关博客

* [阿里巴巴基于 Nacos 实现环境隔离的实践](https://mp.weixin.qq.com/s/TQDhSMJJcCSJTR7Z0gh4gw) 2019.3.13
* [Spring Cloud Alibaba系列教程-03-搭建生产可用的Nacos集群](https://mp.weixin.qq.com/s/MKMLHK9Yd87_6HFbIU60vA) *2019.04.12*