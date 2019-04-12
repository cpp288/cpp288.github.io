---
title: skywalking 6.0.0-GA安装
date: 2019-04-12 14:09:24
tags:
- skywalking
- APM
- 微服务
categories:
- 微服务
---

版本：

- skywalking：6.0.0-GA
- elasticsearch：6.5.4
- rocketbot：最新（master分支）2019.04.12

[skywalking官网](http://skywalking.apache.org/)

skywalking 可以使用 H2、elasticsearch、MySql做为数据存储，推荐使用 elasticsearch

网上有相关的 docker-compose （[参考](https://www.jianshu.com/p/c0dde94585bb)），但是只有 5.0.0 版本的

# Install

## 安装 elasticsearch

本次安装的版本：6.5.4（单机部署），使用 docker 安装

skywalking 6.0.0-GA 支持 6.x 版本以上 elasticsearch（用过 5.x 版本，安装失败，未使用 7.x 版本）

官方安装文档：https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html

```
docker pull elasticsearch:6.5.4
docker run -p 9200:9200 -p 9300:9300 -v esdata:/usr/share/elasticsearch/data -d --name es 93109ce1d590
```

docker images：

```
elasticsearch       6.5.4               93109ce1d590        3 months ago        774MB
```

**设置阿里镜像，不然很慢**

## 安装 skywalking

skywalking 使用本地单机方式安装

### 下载

在 apache 官网下载：https://www.apache.org/dyn/closer.cgi/incubator/skywalking/6.0.0-GA/apache-skywalking-apm-incubating-6.0.0-GA.tar.gz

传至服务器并解压：

```
tar -zxvf apache-skywalking-apm-incubating-6.0.0-GA.tar.gz
```

### 配置

配置 `./config/application.yml` 

设置地址信息和TTL信息：

```yaml
core:
  default:
    restHost: 0.0.0.0
    restPort: 12800
    restContextPath: /
    gRPCHost: 192.168.173.113
    gRPCPort: 11800
    downsampling:
    - Hour
    - Day
    - Month
    # Set a timeout on metric data. After the timeout has expired, the metric data will automatically be deleted.
    recordDataTTL: ${SW_CORE_RECORD_DATA_TTL:90} # Unit is minute
    minuteMetricsDataTTL: ${SW_CORE_MINUTE_METRIC_DATA_TTL:90} # Unit is minute
    hourMetricsDataTTL: ${SW_CORE_HOUR_METRIC_DATA_TTL:36} # Unit is hour
    dayMetricsDataTTL: ${SW_CORE_DAY_METRIC_DATA_TTL:45} # Unit is day
    monthMetricsDataTTL: ${SW_CORE_MONTH_METRIC_DATA_TTL:18} # Unit is month
```

使用 `elasticsearch` 做为 storage，注释掉默认的 H2 配置

```yml
storage:
#  h2:
#    driver: ${SW_STORAGE_H2_DRIVER:org.h2.jdbcx.JdbcDataSource}
#    url: ${SW_STORAGE_H2_URL:jdbc:h2:mem:skywalking-oap-db}
#    user: ${SW_STORAGE_H2_USER:sa}
  elasticsearch:
    # nameSpace: ${SW_NAMESPACE:""}
    clusterNodes: ${SW_STORAGE_ES_CLUSTER_NODES:localhost:9200}
    indexShardsNumber: ${SW_STORAGE_ES_INDEX_SHARDS_NUMBER:2}
    indexReplicasNumber: ${SW_STORAGE_ES_INDEX_REPLICAS_NUMBER:0}
    # Batch process setting, refer to https://www.elastic.co/guide/en/elasticsearch/client/java-api/5.5/java-docs-bulk-processor.html
    # Execute the bulk every 2000 requests
    bulkActions: ${SW_STORAGE_ES_BULK_ACTIONS:2000} 
    # flush the bulk every 20mb
    bulkSize: ${SW_STORAGE_ES_BULK_SIZE:20} 
    # flush the bulk every 10 seconds whatever the number of requests
    flushInterval: ${SW_STORAGE_ES_FLUSH_INTERVAL:10} 
    # the number of concurrent requests
    concurrentRequests: ${SW_STORAGE_ES_CONCURRENT_REQUESTS:2} 

```

相关告警规则设置：`./config/alarm-settings.yml`

### 启动

在 `./bin` 目录下，有相关的启动脚本，主要的是：

- `startup.sh` 启动 server 和 UI
- `oapService.sh` 单独启动 server
- `webappService.sh` 单独启动UI

### Agent

[官方文档](https://github.com/apache/incubator-skywalking/blob/v6.0.0-GA/docs/en/setup/service-agent/java-agent/README.md)

将 `/agent` 目录 copy 至需要监控服务的服务器，目录结构：

- activations
- config：配置
- logs：日志
- optional-plugins：可选插件
- plugins：启用的插件
- skywalking-agent.jar：执行jar文件

#### 配置

配置文件：`./config/agent.config`

```properties
# 配置应用的名称 The service name in UI
agent.service_name=${SW_AGENT_NAME:Your_ApplicationName}
# 配置server collector地址
collector.backend_service=${SW_AGENT_COLLECTOR_BACKEND_SERVICES:192.168.173.113:11800}
# 日志级别
logging.level=${SW_LOGGING_LEVEL:DEBUG}
```

#### 启动

这里使用的是用 jar 启动的方式（tomcat war启动的方式见官方文档）

在 `java -jar` 中增加 skywalking agent 参数（必须在 `-jar` 前面）:

```
java -javaagent:/home/wl/skywalking-agent/skywalking-agent.jar -DSW_AGENT_NAME=xxx -jar xxx.jar
```

## 安装 Rocketbot

由于 skywalking 自带的UI不是特别友好，这里选择使用 Rocketbot

GitHub地址：https://github.com/TinyAllen/rocketbot

这里使用的是 docker 安装的方式，按照 GitHub 的教程安装即可（此次安装由于 Rocketbot 的 shell 脚本问题，搞的久了点）

按照步骤：

```
npm install
npm run build
docker build -t rocketbot .
docker run -p 8080:80 -d -e SKYWALKING_URL=192.168.173.113:12800 rocketbot
```

注意：在 docker run 的时候，由于 rockerbot 容器中没有 skywalking，指定的 `SKYWALKING_URL` 必须是ip地址

# 相关参考

- [elasticsearch 官网](https://www.elastic.co/)
- [skywalking 官网](http://skywalking.apache.org/)
- [APM巅峰对决：skywalking P.K. Pinpoint](http://skywalking.apache.org/zh/blog/2019-02-24-skywalking-pk-pinpoint.html)