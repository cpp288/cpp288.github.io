---
title: Java AIO编程
date: 2019-04-19 15:02:34
tags:
- java
- IO
- Netty权威指南
categories: 
- java
---

摘自《Netty权威指南》

JDK7 的 NIO2.0 引入了新的异步通道的概念，并提供了异步文件通道和异步套接字通道的实现。异步通道提供两种方式获取操作结果：
1. 通过 `java.util.concurrent.Future` 类来表示异步操作的结果
2. 在执行异步操作的时候传入一个 `java.nio.channels`

`CompletionHandler` 接口的实现类作为操作完成的回调

NIO2.0的异步套接字通道是真正的异步非阻塞I/O，它对应UNIX网络编程中的事件驱动I/O（AIO），它不需要通过多路复用器对注册的通道进行轮询操作即可实现异步读写，简化了NIO的编程思想

仍旧以事件服务器为例，[源码地址](https://github.com/cpp288/sty/tree/master/base/io/src/main/java/com/cpp/base/io/aio)

服务端：
```java
public class AsyncTimeServer implements Runnable {

    CountDownLatch latch;
    AsynchronousServerSocketChannel asynchronousServerSocketChannel;

    public static void main(String[] args) {
        new Thread(new AsyncTimeServer(8080), "AIO-AsyncTimeServer-001").start();
    }

    public AsyncTimeServer(int port) {
        try {
            // 创建 AsynchronousServerSocketChannel，并绑定端口
            this.asynchronousServerSocketChannel = AsynchronousServerSocketChannel.open();
            this.asynchronousServerSocketChannel.bind(new InetSocketAddress(port));
            System.out.println("The time server is start in port : " + port);
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void run() {
        // 初始化 CountDownLatch 对象，作用是在完成一组正在执行的操作之前，允许当前线程一直阻塞
        this.latch = new CountDownLatch(1);
        doAccept();
        try {
            latch.await();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

    /**
     * 接收客户端的请求
     */
    private void doAccept() {
        // 由于是异步操作，可以通过 CompletionHandler 实例来接收 accept 操作成功的通知消息
        this.asynchronousServerSocketChannel.accept(this, new CompletionHandler<AsynchronousSocketChannel, AsyncTimeServer>() {

            @Override
            public void completed(AsynchronousSocketChannel channel, AsyncTimeServer asyncTimeServer) {
                // 为什么还要再次调用 accept 方法呢？
                // 当我们调用 AsynchronousServerSocketChannel 的 accept 方法后，如果有新的客户端接入，系统将回调我们传入的 CompletionHandler 实例的 completed 方法
                // 表示新的客户端已经接入成功，因为一个 AsynchronousServerSocketChannel 可以接收成千上万个客户端，所以需要继续调用它的 accept 方法，
                // 接收其它客户端连接，最终形成一个循环，每当接收一个客户端连接成功后，再异步接收新的客户端连接
                asyncTimeServer.asynchronousServerSocketChannel.accept(asyncTimeServer, this);
                ByteBuffer buffer = ByteBuffer.allocate(1024);
                // 进行异步读操作，参数详解：
                // ByteBuffer dst：接收缓冲区，用于从异步 Channel 中读取数据包
                // A attachment：异步 Channel 携带的附件，通知回调的时候作为入参使用
                // CompletionHandler<Integer,? super A> handler：接收通知回调的业务handler
                channel.read(buffer, buffer, new ReadCompletionHandler(channel));
            }

            @Override
            public void failed(Throwable exc, AsyncTimeServer attachment) {
                exc.printStackTrace();
                attachment.latch.countDown();
            }
        });
    }

    private class ReadCompletionHandler implements CompletionHandler<Integer, ByteBuffer> {

        private AsynchronousSocketChannel channel;

        public ReadCompletionHandler(AsynchronousSocketChannel channel) {
            this.channel = channel;
        }

        @Override
        public void completed(Integer result, ByteBuffer attachment) {
            attachment.flip();
            byte[] bytes = new byte[attachment.remaining()];
            attachment.get(bytes);

            String req = new String(bytes, StandardCharsets.UTF_8);
            System.out.println("The time server receive order : " + req);
            String currentTime = "QUERY TIME ORDER".equalsIgnoreCase(req)
                    ? new Date(System.currentTimeMillis()).toString() : "BAD ORDER";
            doWrite(currentTime);
        }

        private void doWrite(String response) {
            if (response == null || response.length() <= 0) {
                return;
            }
            byte[] bytes = response.getBytes();
            ByteBuffer writeBuffer = ByteBuffer.allocate(bytes.length);
            writeBuffer.put(bytes);
            writeBuffer.flip();
            this.channel.write(writeBuffer, writeBuffer, new CompletionHandler<Integer, ByteBuffer>() {

                @Override
                public void completed(Integer result, ByteBuffer buffer) {
                    // 如果没有发送完成，继续发送
                    if (buffer.hasRemaining()) {
                        channel.write(buffer, buffer, this);
                    }
                }

                @Override
                public void failed(Throwable exc, ByteBuffer buffer) {
                    try {
                        channel.close();
                    } catch (IOException e) {
                        e.printStackTrace();
                    }
                }
            });
        }

        @Override
        public void failed(Throwable exc, ByteBuffer attachment) {
            try {
                this.channel.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }
}
```

客户端：
```java
public class AsyncTimeClient implements Runnable, CompletionHandler<Void, AsyncTimeClient> {

    private String host;
    private int port;
    private CountDownLatch latch;

    private AsynchronousSocketChannel client;

    public static void main(String[] args) {
        new Thread(new AsyncTimeClient("127.0.0.1", 8080), "AIO-AsyncTimeClient-001").start();
    }

    public AsyncTimeClient(String host, int port) {
        this.host = host == null ? "127.0.0.1" : host;
        this.port = port;

        try {
            this.client = AsynchronousSocketChannel.open();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void run() {
        this.latch = new CountDownLatch(1);
        // 通过 connect 发起异步操作
        // A attachment：AsynchronousSocketChannel 的附件，用户回调通知时作为入参被传递
        // CompletionHandler<Void,? super A> handler：异步操作回调通知接口
        this.client.connect(new InetSocketAddress(host, port), this, this);

        try {
            latch.await();
            this.client.close();
        } catch (InterruptedException | IOException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void completed(Void result, AsyncTimeClient attachment) {
        byte[] req = "QUERY TIME ORDER".getBytes();
        ByteBuffer writeBuffer = ByteBuffer.allocate(req.length);
        writeBuffer.put(req);
        writeBuffer.flip();
        this.client.write(writeBuffer, writeBuffer, new CompletionHandler<Integer, ByteBuffer>() {

            @Override
            public void completed(Integer result, ByteBuffer buffer) {
                // 还有未发送的数据，则继续发送
                if (buffer.hasRemaining()) {
                    client.write(buffer, buffer, this);
                }
                // 发送完成，则异步读取响应数据
                else {
                    ByteBuffer readBuffer = ByteBuffer.allocate(1024);
                    client.read(readBuffer, readBuffer, new CompletionHandler<Integer, ByteBuffer>() {

                        @Override
                        public void completed(Integer result, ByteBuffer buffer) {
                            buffer.flip();
                            byte[] bytes = new byte[buffer.remaining()];
                            buffer.get(bytes);
                            String body = new String(bytes, StandardCharsets.UTF_8);
                            System.out.println("Now is : " + body);
                            latch.countDown();
                        }

                        @Override
                        public void failed(Throwable exc, ByteBuffer attachment) {
                            try {
                                client.close();
                            } catch (IOException e) {
                                e.printStackTrace();
                            } finally {
                                latch.countDown();
                            }
                        }
                    });
                }
            }

            @Override
            public void failed(Throwable exc, ByteBuffer buffer) {
                try {
                    client.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }  finally {
                    latch.countDown();
                }
            }
        });
    }

    @Override
    public void failed(Throwable exc, AsyncTimeClient attachment) {
        try {
            client.close();
        } catch (IOException e) {
            e.printStackTrace();
        }  finally {
            latch.countDown();
        }
    }
}
```

通过线程堆栈可以发现，JDK底层通过线程池来执行回调通知，最终回调 `CompletionHandler` 的 completed 方法，完成回调通知

我们不需要像NIO那样创建一个独立的IO线程来处理读写操作，对于 `AsynchronousServerSocketChannel` 和 `AsynchronousSocketChannel`，它们都有JDK底层的线程池负责回调并驱动读写操作，所以基于NIO2.0新的异步非阻塞 Channel 进行编程比NIO编程更为简单