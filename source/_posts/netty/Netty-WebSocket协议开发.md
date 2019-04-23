---
title: Netty WebSocket协议开发
date: 2019-04-23 13:41:43
tags:
- netty
- Netty权威指南
categories: 
- netty
---

摘自《Netty权威指南》

# HTTP协议弊端

* HTTP协议为半双工协议，数据可以在客户端和服务端两个方向上传输，但是不能同时传输
* HTTP消息冗长而繁琐，它包含消息头、消息体、换行符等，通常采用文本方式传输，相比于其它的二进制通信协议，冗长而繁琐
* 针对服务器推送的黑客攻击

# WebSocket

## 介绍

WebSocket 基于 TCP 的双向全双工进行消息传输，相比于HTTP的半双工，性能得到很大提升，其特点：
* 单一的TCP连接，采用全双工模式通信
* 对代理、防火墙和路由器透明
* 无头部信息、Cookie和身份验证
* 无安全开销
* 通过"ping/pong"帧保持链路激活
* 服务器可以主动传递消息给客户端，不再需要客户端轮询

## WebSocket生命周期

浏览器通过 JavaScript 向服务器发出建立 WebSocket 连接的请求，客户端和服务器可以通过TCP连接直接交换数据。因为 WebSocket 连接本质上就是一个TCP连接，所以在数据传输的稳定性和传输量大小方面，比轮询以及 Comet 技术有很大的性能优势

为了建立一个 WebSocket 连接，浏览器首先要向服务器发起一个HTTP请求，包含了一些附加头信息，其中附加头信息 `Upgrade:WebSocket` 表明这是一个申请协议升级的HTTP请求

服务端返回给客户端的应答消息：

![](/images/netty/WebSocket服务端应答.png)

握手成功以后，可以通过"messages"的方式进行通信了，一个消息由一个或者多个帧组成，WebSocket 的消息并不一定对应一个特定网络层的帧，可以被分隔或者被合并

帧都有属于自己的类型，属于同一个消息的多个帧具有相同类型的数据，可以是文本数据、二进制数据和控制帧（协议级信令，如信号）

![](/images/netty/WebSocket生命周期.png)

### 连接关闭

为关闭 WebSocket 连接，客户端和服务器需要通过一个安全的方法关闭底层TCP连接以及TLS会话，如果合适，丢弃任何可能已经接收的字节；必要时（受到攻击），可以通过任何可用的手段关闭连接

底层的TCP连接，在正常情况下，应该首先由服务器关闭。在异常情况下（例如在一个合理的时间周期后没有接收到服务器的TCP Close），客户端可以发起TCP Close。因此，当服务器被指示关闭 WebSocket 连接时，它应该立即发起一个TCP Close操作，客户端应该等待服务器的TCP Close

WebSocket 的握手关闭消息带有一个状态码和一个可选的关闭原因，它必须按照协议要求发送一个Close控制帧，当对端接收到关闭控制帧指令时，需要主动关闭 WebSocket 连接

# Netty WebSocket Demo

[源码地址](https://github.com/cpp288/sty/tree/master/netty/src/main/java/com/cpp/netty/protocol/websocket)

目前主流的浏览器都已经支持 WebSocket

功能如下：浏览器通过 WebSocket 协议发送请求消息到服务器，服务器对请求进行判断，如果是合法的 WebSocket 请求，则获取请求消息（文本），并在后面追加字符串返回

服务端：
```java
public class WebSocketServer {

    public static void main(String[] args) throws InterruptedException {
        new WebSocketServer().run(8080);
    }

    public void run(int port) throws InterruptedException {
        NioEventLoopGroup bossGroup = new NioEventLoopGroup();
        NioEventLoopGroup workGroup = new NioEventLoopGroup();

        try {
            ServerBootstrap b = new ServerBootstrap();
            b.group(bossGroup, workGroup)
                    .channel(NioServerSocketChannel.class)
                    .childHandler(new ChannelInitializer<SocketChannel>() {

                        @Override
                        protected void initChannel(SocketChannel socketChannel) throws Exception {
                            socketChannel.pipeline()
                                    // 将请求和应答消息编码或者解码为HTTP消息
                                    .addLast("http-codec", new HttpServerCodec())
                                    // 将HTTP消息的多个部分组合成一个完整的HTTP消息
                                    .addLast("aggregator", new HttpObjectAggregator(65535))
                                    // 向客户端发送HTML5文件，主要用于支持浏览器和服务端进行WebSocket通信
                                    .addLast("http-chunked", new ChunkedWriteHandler())
                                    // 增加服务端handler
                                    .addLast("handler", new WebSocketServerHandler());
                        }
                    });

            Channel channel = b.bind(port).sync().channel();
            System.out.println(String.format("Web socket server started at port : %d", port));
            System.out.println(String.format("Open your browser and navigate to http://localhost:%d/", port));
            channel.closeFuture().sync();
        } finally {
            bossGroup.shutdownGracefully();
            workGroup.shutdownGracefully();
        }
    }

    private class WebSocketServerHandler extends SimpleChannelInboundHandler<Object> {

        private WebSocketServerHandshaker handshaker;

        @Override
        protected void messageReceived(ChannelHandlerContext ctx, Object msg) throws Exception {
            // 普通HTTP接入，第一次接入是通过HTTP
            if (msg instanceof FullHttpRequest) {
                handleHttpRequest(ctx, (FullHttpRequest) msg);
            }
            // WebSocket接入
            else if (msg instanceof WebSocketFrame) {
                handleWebSocketFrame(ctx, (WebSocketFrame) msg);
            }
        }

        @Override
        public void channelReadComplete(ChannelHandlerContext ctx) throws Exception {
            ctx.flush();
        }

        @Override
        public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
            cause.printStackTrace();
            ctx.close();
        }

        private void handleHttpRequest(ChannelHandlerContext ctx, FullHttpRequest req) {
            // 判断是否header里是否有Upgrade为websocket
            if (!req.decoderResult().isSuccess()
                    || (!"websocket".contentEquals(req.headers().get("Upgrade")))) {
                sendHttpResponse(ctx, req, new DefaultFullHttpResponse(HttpVersion.HTTP_1_1, HttpResponseStatus.BAD_REQUEST));
                return;
            }

            // 建立websocket连接
            WebSocketServerHandshakerFactory wsFactory =
                    new WebSocketServerHandshakerFactory("ws://localhost:8080/websocket", null, false);
            handshaker = wsFactory.newHandshaker(req);
            if (handshaker == null) {
                WebSocketServerHandshakerFactory.sendUnsupportedVersionResponse(ctx.channel());
            } else {
                handshaker.handshake(ctx.channel(), req);
            }
        }

        private void sendHttpResponse(ChannelHandlerContext ctx, FullHttpRequest req, FullHttpResponse resp) {
            // 返回客户端应答
            if (resp.status().code() != 200) {
                ByteBuf buf = Unpooled.copiedBuffer(resp.status().toString(), CharsetUtil.UTF_8);
                resp.content().writeBytes(buf);
                buf.release();
                HttpHeaderUtil.setContentLength(resp, resp.content().readableBytes());
            }

            ChannelFuture f = ctx.channel().writeAndFlush(resp);
            if (!HttpHeaderUtil.isKeepAlive(req) || resp.status().code() != 200) {
                f.addListener(ChannelFutureListener.CLOSE);
            }
        }

        private void handleWebSocketFrame(ChannelHandlerContext ctx, WebSocketFrame frame) {
            // 是否是关闭链路的命令
            if (frame instanceof CloseWebSocketFrame) {
                handshaker.close(ctx.channel(), ((CloseWebSocketFrame) frame).retain());
                return;
            }
            // 是否是Ping消息
            if (frame instanceof PingWebSocketFrame) {
                ctx.channel().write(new PongWebSocketFrame(frame.content().retain()));
                return;
            }
            // 本demo仅支持文本消息，不支持二进制消息
            if (!(frame instanceof TextWebSocketFrame)) {
                throw new UnsupportedOperationException(
                        String.format("%s frame types not supported", frame.getClass().getName()));
            }

            // 返回应答消息
            String request = ((TextWebSocketFrame) frame).text();
            System.out.println(String.format("%s received %s", ctx.channel(), request));

            ctx.channel().write(new TextWebSocketFrame(
                    String.format("%s , 欢迎使用Netty WebSocket服务，现在时刻：%s", request, new Date().toString())));
        }
    }
}
```

浏览器HTML：
```xml
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Netty WebSocket 时间服务器</title>
</head>
<body>

</body>
<script type="text/javascript">
    var socket;
    if (!window.WebSocket) {
        window.WebSocket = window.MozWebSocket;
    }
    if (window.WebSocket) {
        socket = new WebSocket("ws://localhost:8080/websocket");
        socket.onmessage = function (ev) {
            var ta = document.getElementById("responseText");
            ta.value = "";
            ta.value = ev.data;
        };

        socket.onopen = function (ev) {
            var ta = document.getElementById("responseText");
            ta.value = "打开 WebSocket 服务正常，浏览器支持 WebSocket！";
        };

        socket.onclose = function (ev) {
            var ta = document.getElementById("responseText");
            ta.value = "";
            ta.value = "WebSocket 关闭！";
        }
    } else {
        alert("抱歉，您的浏览器不支持 WebSocket 协议");
    }

    function send(message) {
        if (!window.WebSocket) {
            return;
        }
        if (socket.readyState === WebSocket.OPEN) {
            socket.send(message);
        } else {
            alert("WebSocket 连接没有建立成功！");
        }
    }
</script>
<form onsubmit="return false;">
    <input type="text" name="message" value="Netty WebSocket"/>
    <br/>
    <input type="button" value="发送 WebSocket 请求消息" onclick="send(this.form.message.value)"/>
    <hr color="blur"/>
    <h3>服务端返回的消息</h3>
    <textarea id="responseText" style="width: 500px;height: 300px"></textarea>
</form>
</html>
```