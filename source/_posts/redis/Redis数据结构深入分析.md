---
title: Redis数据结构深入分析
date: 2019-04-18 09:38:28
tags:
- redis
categories:
- redis
---

Redis提供了丰富的数据类型，包括了字符串、列表、hash、集合、有序集合。redis相关命令可查阅：http://doc.redisfans.com/

# 字符串（String）

字符串类型是redis中最基本的数据类型，它是二进制安全的（意思是redis的string可以包含任何数据，比如jpg图片或者序列化的对象）。一个字符类型键允许存储的最大容量是512M

## 内部数据结构

在Redis内部，String类型通过int、SDS(simple dynamic string)作为结构存储：
* int用来存放整型数据
* sds存放字节/字符串和浮点型数据

在C的标准字符串结构下进行了封装，用来提升基本操作的性能，同时也充分利用已有的 C的标准库，简化实现逻辑。我们可以在redis的源码中【sds.h】中看到具体实现

redis3.2分支引入了五种sdshdr类型，目的是为了满足不同长度字符串可以使用不同大小的Header，从而节省内存，每次在创建一个sds时根据sds的实际长度判断应该选择什么类型的sdshdr，不同类型的sdshdr占用的内存空间不同。这样细分一下可以省去很多不必要的内存开销，下面是3.2的sdshdr定义

```c
/* 8表示字符串最大长度是2^8-1 (长度为255) */
struct __attribute__ ((__packed__)) sdshdr8 {
    uint8_t len;/*表示当前sds的长度(单位是字节)*/
    uint8_t alloc;/*表示已为sds分配的内存大小(单位是字节)*/
    /*用一个字节表示当前sdshdr的类型，因为有sdshdr有五种类型，所以至少需要3位来表示*/
    /*000:sdshdr5，001:sdshdr8，010:sdshdr16，011:sdshdr32，100:sdshdr64。高5位用不到所以都为0。*/
    unsigned char flags;
    char buf[];/*sds实际存放的位置*/
};
```

# 列表（List）

列表类型(list)可以存储一个有序的字符串列表，常用的操作是向列表两端添加元素或者获得列表的某一个片段。

列表类型内部使用双向链表实现，所以向列表两端添加元素的时间复杂度为O(1)，获取越接近两端的元素速度就越快。这意味着即使是一个有几千万个元素的列表，获取头部或尾部的10条记录也是很快的

## 内部数据结构

redis版本不同，实现列表的方式是不同的：
* redis3.2之前，List类型的value对象内部以`linkedlist`或者`ziplist`来实现，当list的元素个数和单个元素的长度比较小的时候，Redis会采用`ziplist`(压缩列表)来实现来减少内存占用。否则就会采用`linkedlist`(双向链表)结构。
* redis3.2之后，采用的一种叫`quicklist`的数据结构来存储list，列表的底层都由`quicklist`实现。

这两种存储方式都有优缺点：
* 双向链表在链表两端进行push和pop操作，在插入节点上复杂度比较低，但是内存开 销比较大; 
* ziplist存储在一段连续的内存上，所以存储效率很高，但是插入和删除都需要频繁申请和释放内存;

`quicklist`仍然是一个双向链表，只是列表的每个节点都是一个`ziplist`，其实就是`linkedlist`和`ziplist`的结合，`quicklist`中每个节点`ziplist`都能够存储多个数据元素。其数据结构图如下：

![quicklist数据结构](/images/redis/quicklist数据结构.png)

quicklist由quicklistnode组成，quicklistnode可以存放ziplist，也可以存放quicklistLZF，ziplist能够存储多个数据元素

## 列表结构的应用场景

我们可以根据列表的数据结构特点，以及redis对列表操作来应用到以下几个场景：
* 栈（FILO）：使用LPUSH、LPOP命令实现
* 队列（FIFO）：使用LPUSH、RPOP命令实现
* 消息队列：使用LPUSH、BRPOP命令实现

具体的命令可以查看：http://doc.redisfans.com/

# hash

Redis hash 是一个string类型的field和value的映射表，hash特别适合用于存储对象。

Redis 中每个 hash 可以存储 232 - 1 键值对（40多亿）。

![image](/images/redis/hash结构.png)

## 数据结构

map提供两种结构来存储，一种是hashtable、另一种是ziplist（数据量小的时候使用ziplist）。在redis中，哈希表分为三层（源码地址【dict.h】）：

### dictEntry

管理一个key-value，同时保留同一个桶中相邻元素的指针，用来维护哈希桶的内部链：
```c
typedef struct dictEntry {
    void *key;
    union { // 因为value有多种类型，所以value用了union来存储
        void *val;
        uint64_t u64;
        int64_t s64;
        double d;
    } v;
    // 洗一个节点的地址，用来处理hash碰撞
    // 所有分配到同一索引的元素通过next指针链接起来形成链表
    // key和v都可以报错多种类型的数据
    struct dictEntry *next;
} dictEntry;
```

### dictht

实现一个hash表会使用一个buckets存放dictEntry的地址，一般情况下通过`hash(key)%len`得到的值就是buckets的索引，这个值决定了我们要将此dictEntry节点放入buckets的哪个索引里，这个buckets实际上就是我们说的hash表：

```c
typedef struct dictht {
    dictEntry **table; // buckets的地址
    unsigned long size; // buckets的大小，总保持为2^n
    unsigned long sizemask; // 掩码，用来计算hash值对应的buckets索引
    unsigned long used;// 当前dictht有多少个dictEntry节点
} dictht;
```

### dict

dictht实际上就是hash表的核心，但是只有一个dictht还不够，比如rehash、遍历hash等操作，所以redis定义了一个叫dict的结构以支持字典的各种操作，当dictht需要扩容/缩容时，用来管理dictht的迁移：

```c
typedef struct dict {
    dictType *type;// dictType里存放的时一堆工具函数的函数指针
    void *privdata;// 保存type中的某些函数需要作为参数的数据
    dictht ht[2];// 两个dictht，ht[0]平时用，ht[1]rehash时用
    long rehashidx;// 当前rehash到buckets的哪个索引，-1时表示非rehash状态
    int iterators;// 安全迭代器的计数
} dict;
```

比如我们要将一个数据存储到hash表中，那么会先计算key对应的hashcode，然后根据hashcode取模得到bucket的位置，再插入到链表中

# 集合（Set）

集合类型中，每个元素都是不同的，也就是不能有重复数据，同时集合类型中的数据是无序的，集合类型和列表类型最大的区别就是有序性和唯一性

集合类型的常用操作是向集合中加入或删除元素、判断某个元素是否存在。由于集合类型在redis内部是使用的值为空的散列表（hash table），所以这些操作的时间复杂度都是O(1)

## 数据结构

Set在底层数据结构是以intset或者hashtable存储的：
* 当set中只包含整数型的元素时，采用intset来存储
* 其它则用hashtable来存储，但是hashtable的value值为null，通过key来存储元素

# 有序集合（SortedSet/ZSet）

有序集合，顾名思义，和之前的集合多了有序的功能。

在集合的基础上，有序集合为集合中的每个元素都关联了一个分数，这使得我们不仅可以完成插入、删除和判断元素是否操作等集合支持的操作，还能获得分数最高（或最低）的前N个元素、获得指定分数范围内的元素等与分数有关的操作（虽然集合中每个元素都是不同的，但是它们的分数却可以相同）

![ZSet](/images/redis/ZSet结构.png)

## 数据结构
Zset的数据结构比较复杂一点，内部是以ziplist或者skiplist+hashtable来实现的，这里面最核心的一个结构就是skiplist（跳跃表）