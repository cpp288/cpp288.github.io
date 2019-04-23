---
title: Netty UDP协议开发
date: 2019-04-23 20:10:54
tags:
- netty
- Netty权威指南
categories: 
- netty
---

摘自《Netty权威指南》

# 介绍

UDP是用户数据协议（User Datagram Protocol），作用是将网络数据流量压缩成数据报形式，提供面向事务的简单信息传送服务。与TCP不同，UDP直接利用IP协议进行UDP数据报的传输，它提供面向无连接的、不可靠的数据报投递服务

由于UDP具有资源消耗小、处理速度快的优点，通常视屏、音频等可靠性要求不高的数据传输一般会使用UDP

UDP是无连接的，通信双方不需要建立物理链路连接。在网络中它用于处理数据包，在OSI模型中，处于第四层传输层，位于IP协议上一层。它不对数据报分组、组装、校验和排序

其数据报格式有首部和数据两个部分，首部很简单，为8个字节，包含：
1. 源端口：2个字节，最大值为65535
2. 目的端口：2个字节，最大值为65535
3. 长度：2个字节，UDP用户数据报的总长度
4. 校验和：2个字节，用于校验UDP数据报的数字段和包含UDP数据报首部的"伪首部"（其校验方法类似于IP分组首部中的首部校验和）

UDP协议的特点：
* 传送数据前并不与对方建立连接，在传送数据前，发送方和接收方相互交换信息使双方同步
* 对接收到的数据报不发送确认信号，发送端不知道数据是否正确接收，也不会重复发送
* 比TCP快速，系统开销少

# Netty UDP Demo

[源码地址](https://github.com/cpp288/sty/tree/master/netty/src/main/java/com/cpp/netty/protocol/udp)

服务端：
```java
public class ChineseProverbServer {

    public static void main(String[] args) throws InterruptedException {
        new ChineseProverbServer().run(8080);
    }

    public void run(int port) throws InterruptedException {
        NioEventLoopGroup group = new NioEventLoopGroup();
        try {
            Bootstrap b = new Bootstrap();
            b.group(group)
                    // UDP通信，使用 NioDatagramChannel 来创建
                    .channel(NioDatagramChannel.class)
                    .option(ChannelOption.SO_BROADCAST, true)
                    // UDP不存在客户端和服务端的实际连接，因此不需要为连接（ChannelPipeline）设置 handler
                    .handler(new ChineseProverbServerHandler());

            b.bind(port).sync().channel().closeFuture().await();
        } finally {
            group.shutdownGracefully();
        }
    }

    private static class ChineseProverbServerHandler extends SimpleChannelInboundHandler<DatagramPacket> {

        private static final String[] DICTIONARY = {
                "只要功夫深，铁杵磨成针",
                "旧时王谢堂前燕，飞入寻常百姓家",
                "洛阳亲友如想问，一片冰心在玉壶",
                "一寸光阴一寸金，寸金难买寸光阴"
        };

        private String nextQuote() {
            int index = ThreadLocalRandom.current().nextInt(DICTIONARY.length);
            return DICTIONARY[index];
        }

        @Override
        protected void messageReceived(ChannelHandlerContext ctx, DatagramPacket packet) throws Exception {
            String req = packet.content().toString(CharsetUtil.UTF_8);
            System.out.println(req);

            if ("谚语字典查询?".equals(req)) {
                ctx.writeAndFlush(new DatagramPacket(
                        Unpooled.copiedBuffer("谚语查询结果：" + nextQuote(), CharsetUtil.UTF_8), packet.sender()));
            }
        }

        @Override
        public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
            cause.printStackTrace();
            ctx.close();
        }
    }
}
```

客户端：
```java
public class ChineseProverbClient {

    public static void main(String[] args) throws InterruptedException {
        new ChineseProverbClient().run(8080);
    }

    public void run(int port) throws InterruptedException {
        NioEventLoopGroup group = new NioEventLoopGroup();
        try {
            Bootstrap b = new Bootstrap();
            b.group(group)
                    .channel(NioDatagramChannel.class)
                    .option(ChannelOption.SO_BROADCAST, true)
                    .handler(new ChineseProverbClientHandler());

            Channel ch = b.bind(0).sync().channel();
            // 创建UDP Channel完成之后，客户端就要主动发送广播消息：
            // TCP客户端是在客户端和服务端链路建立成功之后由客户端的业务handler发送消息，这是两者的区别
            ch.writeAndFlush(new DatagramPacket(Unpooled.copiedBuffer("谚语字典查询?", CharsetUtil.UTF_8),
                    new InetSocketAddress("255.255.255.255", port))).sync();
            // 等待15s秒接收服务端的应答消息，然后退出
            if (!ch.closeFuture().await(15000)) {
                System.out.println("查询超时！");
            }
        } finally {
            group.shutdownGracefully();
        }
    }

    private class ChineseProverbClientHandler extends SimpleChannelInboundHandler<DatagramPacket> {

        @Override
        protected void messageReceived(ChannelHandlerContext ctx, DatagramPacket msg) throws Exception {
            String resp = msg.content().toString(CharsetUtil.UTF_8);
            System.out.println(resp);
            ctx.close();
        }

        @Override
        public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
            cause.printStackTrace();
            ctx.close();
        }
    }
}
```