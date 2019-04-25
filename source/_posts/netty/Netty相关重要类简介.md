---
title: Netty相关重要类简介
date: 2019-04-25 10:26:17
tags:
- netty
- Netty权威指南
categories: 
- netty
---

摘自《Netty权威指南》

这里简单介绍Netty重要的类，深入了解可以参考《Netty权威指南》

# ByteBuf

当我们进行数据传输时，往往需要使用到缓冲区，常用的是JDK NIO类库提供的 `java.nio.Buffer`，但是它有如下缺点：
1. ByteBuffer长度固定，一旦分配完成，容量不能动态扩展和收缩，当需要编码大对象时，可能会发生索引越界异常
2. ByteBuffer只有一个标识位置的指针position，读写需要手动调用 `flip()` 和 `rewind()`，且必须小心使用，很容易导致程序处理失败
3. ByteBuffer的API功能有限，一些高级特性不支持，需要自己实现

由于以上缺点，Netty提供了自己的 ByteBuffer 实现：ByteBuf

功能介绍：
1. 顺序读操作
2. 顺序写操作
3. readerIndex 和 writerIndex：提供两个指针变量用于支持顺序读写操作
4. Discardable bytes
5. Readable bytes 和 Writable bytes
6. clear操作
7. Mark 和 Rest
8. 查找操作
9. Derived buffers
10. 转换成标准的ByteBuffer
11. 随机读写（set 和 get）

相关辅助类：
* ByteBufHolder：ByteBuf容器，实现该接口定制化需求
* ByteBufAllocator：字节缓冲区分配器
* CompositeByteBuf：允许多个 ByteBuf 的实例组装到一起
* ByteBufUtil：工具类

# Channel和Unsafe

## Channel

`io.netty.channel.Channel` 是Netty网络操作抽象类，包含了：
1. 网络IO操作
2. 客户端发起连接、主动关闭连接、链路关闭
3. 获取通信双方的网络地址
4. 获取该 Channel 的 EventLoop
5. 获取缓冲分配器 ByteBufAllocator 和 pipeline
6. ...

## Unsafe

Unsafe 接口实际上是 Channel 接口的辅助接口，它不应该被用户代码直接调用到，实际的IO操作都是由Unsafe接口完成的

# ChannelPipeline和ChannelHandler

Netty 的 ChannelPipeline 和 ChannelHandler 机制类似于 Servlet 和 Filter 过滤器

Netty 的 Channel 过滤器实现原理与 Servlet Filter 机制一直，它将 Channel 的数据管道抽象成 ChannelPipeline，消息在 ChannelPipeline 中流动和传递， ChannelPipeline 持有IO事件拦截器 ChannelHandler 的链表，由 ChannelHandler 对IO事件进行拦截和处理

# EventLoop 和 EventLoopGroup

见Netty线程模型

# Future 和 Promise

## Future

Future 最早来源于JDK的 `java.util.concurrent.Future`，它用于代表异步操作的结果

由于Netty的Future都是与异步IO操作相关，因此命名为 `ChannelFuture`，代表与Channel操作相关

# Promise

Promise 是可写的 Future，Future 自身并没有写操作相关的接口，Netty通过Promise对Future进行扩展，用于设置IO操作的结果