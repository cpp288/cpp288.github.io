---
title: Java NIO编程
date: 2019-04-19 09:54:47
tags:
- java
- IO
- Netty权威指南
categories: 
- java
---

摘自《Netty权威指南》

Java NIO是 JDK1.4 引入的，弥补了原来BIO的不足

# 概念

## 缓冲区 Buffer

在 NIO 库中，所有数据都是用缓冲区处理的，任何时候访问 NIO 中的数据，都是通过缓冲区进行操作的。

最常用的缓冲区是 `ByteBuffer`，提供了一组功能用于操作byte数组，还有其它的一些缓冲区，关系图如下：

![NIO缓冲区关系图](/images/java/io/NIO缓冲区关系图.png)

## 通道 Channel

Channel 是一个通道，可以通过它读取和写入数据，**与流的不同之处在于通道是双向的（可以读、写或者同时读写），流只是一个方向上移动（流必须是 `InputStream` 或 `OutputStream` 的子类）**

因为 Channel 是全双工的，可以比流更好地映射操作系统地API，特别是在 UNIX 网络编程模型中，底层操作系统地通道都是全双工的，同时支持读写操作。其继承关系如下：

![NIO通道关系图](/images/java/io/NIO通道关系图.png)

## 多路复用器 Selector

多路复用器提供选择已经就绪的任务的能力，它会不断地轮询注册在其上的 Channel，如果某个 Channel 上面有新的 TCP 连接接入、读和写事件，那么这个 Channel 就处于就绪状态，会被 Selector 轮询出来，然后通过 SelectionKey 可以获取就绪的 Channel 的集合，进行后续的IO操作

一个 Selector 可以同时轮询多个 Channel，由于 JDK 使用了 epoll() 代替了传统的 select 实现，所以没有最大连接句柄限制

# 详解

[源码地址](https://github.com/cpp288/sty/tree/master/base/io/src/main/java/com/cpp/base/io/nio)

## 服务端

NIO服务端序列图：

![NIO服务端序列图](/images/java/io/NIO服务端序列图.png)

将之前的 TimeServer 改造成 NIO 模式：

```java
public class MultiplexerTimeServer implements Runnable {

    private Selector selector;
    private ServerSocketChannel serverSocketChannel;
    private volatile boolean stop;

    public static void main(String[] args) {
        new Thread(new MultiplexerTimeServer(8080), "NIO-MultiplexerTimeServer-001").start();
    }

    /**
     * 初始化多路复用器、绑定监听端口
     *
     * @param port
     */
    public MultiplexerTimeServer(int port) {
        try {
            // 创建多路复用器
            this.selector = Selector.open();
            // 创建通道，并设置成非阻塞模式，绑定监听端口，最后注册到多路复用器（监听 SelectionKey.OP_ACCEPT）
            this.serverSocketChannel = ServerSocketChannel.open();
            this.serverSocketChannel.configureBlocking(false);
            this.serverSocketChannel.socket().bind(new InetSocketAddress(port), 1024);
            this.serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);
            System.out.println("The time server is start in port : " + port);
        } catch (IOException e) {
            e.printStackTrace();
            System.exit(1);
        }
    }

    public void stop() {
        this.stop = true;
    }

    @Override
    public void run() {
        while (!this.stop) {
            try {
                this.selector.select(1000);
                // 当有处于就绪状态的 Channel 时，selector 将返回就绪状态的 Channel 的 SelectionKey 集合
                Set<SelectionKey> selectionKeys = this.selector.selectedKeys();

                Iterator<SelectionKey> it = selectionKeys.iterator();
                SelectionKey key;
                while (it.hasNext()) {
                    key = it.next();
                    it.remove();
                    try {
                        // 进行网络的异步读写操作
                        handleInput(key);
                    } catch (Exception e) {
                        if (key != null) {
                            key.cancel();
                            if (key.channel() != null) {
                                key.channel().close();
                            }
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    /**
     * 处理客户端请求
     *
     * @param key
     * @throws IOException
     */
    private void handleInput(SelectionKey key) throws IOException {
        // 通过 SelectionKey 的操作位进行判断即可获知网络事件的类型
        if (key.isValid()) {
            if (key.isAcceptable()) {
                ServerSocketChannel ssc = (ServerSocketChannel) key.channel();
                // 接受客户端的连接请求并创建 SocketChannel 实例，相当于完成了TCP的三次握手
                SocketChannel sc = ssc.accept();
                // 设置为非阻塞
                sc.configureBlocking(false);
                // 注册到 selector，并设置为读操作
                sc.register(this.selector, SelectionKey.OP_READ);
            }

            if (key.isReadable()) {
                SocketChannel sc = (SocketChannel) key.channel();
                // 创建一个 ByteBuffer，由于无法得知客户端发送的大小，这里开辟一个1K的缓冲区
                ByteBuffer readBuffer = ByteBuffer.allocate(1024);
                // SocketChannel 读取缓冲区数据
                int readBytes = sc.read(readBuffer);
                // 由于 SocketChannel 设置为非阻塞的，因此read操作也是非阻塞的，需要通过返回值判断读到的字节数
                // 大于0：读到了字节；等于0：没有读到字节；小于0：链路已关闭，需要释放相关资源；
                if (readBytes > 0) {
                    // 将缓冲区当前的limit设置为position，position设置为0，用于后续会缓冲区的读取操作
                    readBuffer.flip();
                    byte[] bytes = new byte[readBuffer.remaining()];
                    readBuffer.get(bytes);
                    String body = new String(bytes, StandardCharsets.UTF_8);
                    System.out.println("The time server receive order : " + body);
                    String currentTime = "QUERY TIME ORDER".equalsIgnoreCase(body)
                            ? new Date(System.currentTimeMillis()).toString() : "BAD ORDER";
                    doWrite(sc, currentTime);
                } else if (readBytes < 0) {
                    key.cancel();
                    sc.close();
                }
            }
        }
    }

    /**
     * 应答消息异步发送给客户端
     *
     * @param channel
     * @param response
     * @throws IOException
     */
    private void doWrite(SocketChannel channel, String response) throws IOException {
        if (response == null || response.length() <= 0) {
            return;
        }
        byte[] bytes = response.getBytes();
        ByteBuffer writeBuffer = ByteBuffer.allocate(bytes.length);
        // 将字节数据复制到缓冲区
        writeBuffer.put(bytes);
        writeBuffer.flip();
        // 将缓冲区中的字节数组发送出去
        // 由于 SocketChannel 的write方法是异步非阻塞的，不保证一次能够发送完，会出现"写半包"的问题
        // 需要注册写操作，不断轮询 selector 将没有发送完的 ByteBuffer 发送完毕
        // 可以通过 ByteBuffer 的 hasRemaining 方法判断消息是否发送完成，这里没演示
        channel.write(writeBuffer);
    }
}
```

## 客户端

NIO客户端序列图：

![NIO客户端序列图](/images/java/io/NIO客户端序列图.png)

将之前的 TimeClient 改造成 NIO 模式：

```java
public class MultiplexerTimeClient implements Runnable {

    private String host;
    private int port;
    private Selector selector;
    private SocketChannel socketChannel;
    private volatile boolean stop;

    public static void main(String[] args) {
        new Thread(new MultiplexerTimeClient("127.0.0.1", 8080), "NIO-MultiplexerTimeClient-001").start();
    }

    public MultiplexerTimeClient(String host, int port) {
        this.host = host == null ? "127.0.0.1" : host;
        this.port = port;

        try {
            this.selector = Selector.open();
            this.socketChannel = SocketChannel.open();
            this.socketChannel.configureBlocking(false);
        } catch (IOException e) {
            e.printStackTrace();
            System.exit(1);
        }
    }

    @Override
    public void run() {
        try {
            doConnect();
        } catch (IOException e) {
            e.printStackTrace();
            System.exit(1);
        }

        while (!this.stop) {
            try {
                this.selector.select(1000);
                Set<SelectionKey> selectionKeys = this.selector.selectedKeys();

                Iterator<SelectionKey> it = selectionKeys.iterator();
                SelectionKey key;
                while (it.hasNext()) {
                    key = it.next();
                    it.remove();
                    try {
                        handleInput(key);
                    } catch (Exception e) {
                        if (key != null) {
                            key.cancel();
                            if (key.channel() != null) {
                                key.channel().close();
                            }
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
                System.exit(1);
            }
        }

        if (this.selector != null) {
            try {
                // 释放 selector，由于在其注册的 channel 可能是成千上万的，一一释放显然不合适
                // 因此，JDK底层会自动释放所有跟此 selector 相关联的资源
                this.selector.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    private void handleInput(SelectionKey key) throws IOException {
        if (key.isValid()) {
            SocketChannel sc = (SocketChannel) key.channel();
            // 如果处于连接状态，说明服务端已经返回ACK应答消息
            if (key.isConnectable()) {
                // 说明连接成功，注册成 SelectionKey.OP_READ，通过 doWrite 发送
                if (sc.finishConnect()) {
                    sc.register(this.selector, SelectionKey.OP_READ);
                    doWrite(sc);
                } else {
                    System.exit(1);
                }
            }
            // 判断是否收到了服务端的应答消息，如果是，则 SocketChannel 是可读的
            if (key.isReadable()) {
                ByteBuffer readBuffer = ByteBuffer.allocate(1024);
                int readBytes = sc.read(readBuffer);
                if (readBytes > 0) {
                    readBuffer.flip();
                    byte[] bytes = new byte[readBuffer.remaining()];
                    readBuffer.get(bytes);
                    String body = new String(bytes, StandardCharsets.UTF_8);
                    System.out.println("Now is : " + body);
                    this.stop = true;
                } else if (readBytes < 0) {
                    key.channel();
                    sc.close();
                }
            }
        }
    }

    /**
     * 连接
     *
     * @throws IOException
     */
    private void doConnect() throws IOException {
        // 如果连接成功，将 Channel 注册到 selector 上，进行请求写操作
        if (this.socketChannel.connect(new InetSocketAddress(this.host, this.port))) {
            this.socketChannel.register(this.selector, SelectionKey.OP_READ);
            doWrite(this.socketChannel);
        }
        // 如果没有连接成功，不代表连接失败，注册成 SelectionKey.OP_CONNECT，当服务端返回TCP syn-ack消息后，
        // selector就能轮询到这个 SocketChannel 处于连接就绪状态
        else {
            this.socketChannel.register(selector, SelectionKey.OP_CONNECT);
        }
    }

    /**
     * 发送数据
     *
     * @param channel
     * @throws IOException
     */
    private void doWrite(SocketChannel channel) throws IOException {
        byte[] req = "QUERY TIME ORDER".getBytes();
        ByteBuffer writeBuffer = ByteBuffer.allocate(req.length);
        writeBuffer.put(req);
        writeBuffer.flip();
        channel.write(writeBuffer);
        // 通过 writeBuffer.hasRemaining() 进行判断是否消息全部发送完毕
        if (!writeBuffer.hasRemaining()) {
            System.out.println("Send order 2 server succeed.");
        }
    }
}
```

# 总结

通过上述例子，NIO编程难度要比BIO大很多（这里并没有考虑"半包读"和"半包写"），其优点：
1. 客户端发起的连接操作是异步的，可以通过在 selector 上注册 OP_CONNECT 等待后续结果
2. SocketChannel 的读写操作都是异步的，如果没有可读写的数据它不会同步等待，直接返回，这样IO线程可以处理其它的链路
3. 线程模型优化，JDK的selector在Linux等主流操作系统上通过epoll实现，没有连接句柄的限制，意味着一个selector线程可以同时处理成千上万个客户端连接，而性能不会线性下降，适合做高性能、高负载的网络服务器