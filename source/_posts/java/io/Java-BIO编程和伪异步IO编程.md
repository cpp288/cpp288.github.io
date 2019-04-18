---
title: Java BIO编程和伪异步I/O编程
date: 2019-04-18 16:37:38
tags:
- java
- IO
- Netty权威指南
categories: 
- java
- 笔记
---

摘自《Netty权威指南》

# BIO

BIO通信模型：

![BIO通信模型](/images/java/io/BIO通信模型.png)

问题显而易见：**每个客户端都需要创建一个线程，并发访问量大时，系统会出现堆栈溢出、创建新线程失败等问题**

## 代码演示

功能：时间服务器

服务端：
```java
public class TimeServer {

    public static void main(String[] args) throws IOException {
        // 监听8080端口
        int port = 8080;
        if (args != null && args.length > 0) {
            port = Integer.valueOf(args[0]);
        }

        ServerSocket server = null;
        try {
            server = new ServerSocket(port);
            System.out.println("The time server is start in port : " + port);
            Socket socket;
            while (true) {
                socket = server.accept();
                // 这里创建一个线程去执行业务
                new Thread(new TimeServerHandler(socket)).start();
            }
        } finally {
            if (server != null) {
                System.out.println("The time server close");
                server.close();
            }
        }
    }
}

/**
 * 具体执行的线程 
 */
public class TimeServerHandler implements Runnable{

    private Socket socket;

    public TimeServerHandler(Socket socket) {
        this.socket = socket;
    }

    @Override
    public void run() {
        BufferedReader in = null;
        PrintWriter out = null;

        try {
            in = new BufferedReader(new InputStreamReader(this.socket.getInputStream()));
            out = new PrintWriter(this.socket.getOutputStream(), true);

            String currentTime;
            String body;

            while (true) {
                body = in.readLine();
                if (body == null) {
                    break;
                }
                System.out.println("The time server receive order : " + body);
                currentTime = "QUERY TIME ORDER".equalsIgnoreCase(body)
                        ? new Date(System.currentTimeMillis()).toString() : "BAD ORDER";
                out.println(currentTime);
            }
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            // 释放相关资源
            if (in != null) {
                try {
                    in.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }

            if (out != null) {
                out.close();
            }

            if (this.socket != null) {
                try {
                    this.socket.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
                this.socket = null;
            }
        }
    }
}
```

客户端：
```java
public class TimeClient {

    public static void main(String[] args) {
        int port = 8080;
        if (args != null && args.length > 0) {
            port = Integer.valueOf(args[0]);
        }

        Socket socket = null;
        BufferedReader in = null;
        PrintWriter out = null;

        try {
            socket = new Socket("127.0.0.1", port);
            in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
            out = new PrintWriter(socket.getOutputStream(), true);

            out.println("QUERY TIME ORDER");
            System.out.println("Send order 2 server succeed.");

            String resp = in.readLine();
            System.out.println("Now is : " + resp);
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            // 释放相关资源
            if (in != null) {
                try {
                    in.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }

            if (out != null) {
                out.close();
            }

            if (socket != null) {
                try {
                    socket.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
    }
}
```

# 伪异步I/O

伪异步I/O模型图：

![伪异步IO模型](/images/java/io/伪异步IO模型.png)

可以看到，伪异步I/O只是加入了一个线程池，避免了每次请求都创建线程的问题（这里就不写demo了）

但是通过对输入和输出流的API文档分析，了解到读和写操作都是同步阻塞的，阻塞的时间取决于对方I/O线程的处理速度和网络I/O的传输速度。我们无法保证生产环境的网络状况和对端的应用程序能足够快，所以它的可靠性就非常差。