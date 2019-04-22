---
title: Java 序列化的缺点
date: 2019-04-22 16:17:40
tags:
- java
- IO
- Netty权威指南
categories: 
- java
---

摘自《Netty权威指南》

JDK1.1版本提供了Java序列化，只需要实现 `java.io.Serializable` 接口并生成序列ID即可，但是在远程服务调用（RPC）时，很少使用Java序列化进行消息的编解码和传输

[源码地址](https://github.com/cpp288/sty/tree/master/netty/src/main/java/com/cpp/netty/serialize/jdk)

# 无法跨语言

由于Java序列化是Java语言内部的私有协议，其它语言并不支持，对于用户来说完全是黑盒，其序列化后的字节数组，别的语言无法进行反序列化

目前几乎所有流行的Java RPC通信框架，都没有使用Java序列化，原因就是它无法跨语言，而一般情况下，RPC框架都需要支持跨语言应用

# 序列化后的码流太大

通过下面的例子看下Java序列化后的字节数组大小：

```java
@Getter
@Setter
public class UserInfo implements Serializable {

    private static final long serialVersionUID = 1L;

    private String userName;
    private int userId;

    public UserInfo buildUserName(String userName) {
        this.userName = userName;
        return this;
    }

    public UserInfo buildUserId(int userId) {
        this.userId = userId;
        return this;
    }

    public byte[] codeC() {
        ByteBuffer buffer = ByteBuffer.allocate(1024);
        byte[] value = this.userName.getBytes();
        buffer.putInt(value.length);
        buffer.put(value);
        buffer.putInt(this.userId);

        buffer.flip();
        value = null;
        byte[] result = new byte[buffer.remaining()];
        buffer.get(result);
        return result;
    }
    
    public static void main(String[] args) throws IOException {
        UserInfo userInfo = new UserInfo();
        userInfo.buildUserId(100).buildUserName("hello");

        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        ObjectOutputStream os = new ObjectOutputStream(bos);
        os.writeObject(userInfo);
        os.flush();
        os.close();
        byte[] b = bos.toByteArray();

        System.out.println("The jdk serializable length is : " + b.length);
        bos.close();

        System.out.println("----------------------------------------------");

        System.out.println("The byte array serializable length is : " + userInfo.codeC().length);
    }
}
```

执行后的结果：
```
The jdk serializable length is : 106
----------------------------------------------
The byte array serializable length is : 13
```

可以发现，使用Java序列化后的字节数组很大，这样就导致占用空间大、网络传输更占带宽，导致系统的吞吐量降低

# 序列化性能太低

将上面的例子改造成性能测试版本

```java
public class JavaSerializePerformTest {

    public static void main(String[] args) throws IOException {
        UserInfo userInfo = new UserInfo();
        userInfo.buildUserId(100).buildUserName("hello");

        int loop = 1000000;
        ByteArrayOutputStream bos;
        ObjectOutputStream os;

        long startTime = System.currentTimeMillis();
        for (int i = 0; i < loop; i++) {
            bos = new ByteArrayOutputStream();
            os = new ObjectOutputStream(bos);
            os.writeObject(userInfo);
            os.flush();
            os.close();
            byte[] b = bos.toByteArray();
            bos.close();
        }
        long endTime = System.currentTimeMillis();
        System.out.println("The jdk serializable cost time is : " + (endTime - startTime) + " ms");

        System.out.println("----------------------------------------------");

        startTime = System.currentTimeMillis();
        for (int i = 0; i < loop; i++) {
            userInfo.codeC();
        }
        endTime = System.currentTimeMillis();
        System.out.println("The byte array serializable cost time is : " + (endTime - startTime) + " ms");
    }
}
```

执行结果：
```
The jdk serializable cost time is : 2667 ms
----------------------------------------------
The byte array serializable cost time is : 160 ms
```

简单的例子可以看出，Java序列化的性能很低