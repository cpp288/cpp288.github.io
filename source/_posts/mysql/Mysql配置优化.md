---
title: Mysql配置优化
date: 2019-02-28 09:20:04
tags: 
- Mysql
- 笔记
- 性能优化
categories: 
- 数据库
---

# 参数作用域

- 全局参数（global）：	

  ```
  set global autocommit = ON/OFF;
  ```

- 会话参数（session），会话参数不单独设置则会采用全局参数：

  ```
  set session autocommit = ON/OFF;
  ```

注意点：

1. 全局参数的设定对于已经存在的会话无法生效（需要重新开启会话）
2. 会话参数的设定随着会话的销毁而失效
3. 全局类的统一配置建议配置在默认配置文件中，否则重启服务会导致配置失效

# 配置文件

`mysql --help` 寻找配置文件的位置和加载顺序：

```
Default options are read from the following files in the given order:
/etc/my.cnf /etc/mysql/my.cnf /usr/etc/my.cnf ~/.my.cnf
```

因为参数比较多，可以通过命令过滤：

```
mysql --help | grep -A 1 'Default options are read from the following files in the given order'
```

## 连接数配置

设置 `max_connections` 可配置最大连接数，mysql5.6 默认是151个连接：

```
+--------------------+-------+
| Variable_name      | Value |
+--------------------+-------+
| max_connections    | 151   |
+--------------------+-------+
```

这个设置受其它两个配置影响：

1. 系统句柄数配置

   使用 `ulimit -a` 或者查看 `/etc/security/limits.conf` 配置文件

   ```
   open files                      (-n) 65535
   ```

2. mysql句柄数配置

   查看 `/usr/lib/systemd/system/mysqld.service` 配置文件

   ```
   LimitNOFILE = 6000
   ```

## 内存参数配置

- `sort_buffer_size` connection 排序缓冲区大小 

  当查询语句中有需要文件排序功能时，马上为 connection 分配配置的内存大小，建议256K（默认值）～ 2M之内

- `join_buffer_size` connection关联查询缓冲区大小

  当查询语句中有关联查询时，马上分配配置大小的内存用这个关联查询，所以有可能在一个查询语句中会分配很多个关联查询缓冲区 ，建议256K（默认值）～1M之间

- `Innodb_buffer_pool_size` innodb buffer/cache 的大小（默认128M）

  innodb buffer/cache中存着数据缓存、索引缓存、缓冲数据、内部结构这些数据，所以大的缓冲池可以减小多次磁盘I/O访问相同的表数据以提高性能

  计算公式：

  ```
  Innodb_buffer_pool_size = (总物理内存 - 系统运行所用 - connection 所用) * 90%
  ```

## 其它参数配置

参考帖子：https://www.cnblogs.com/wyy123/p/6092976.html