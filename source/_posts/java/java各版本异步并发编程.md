---
title: java各版本异步并发编程
date: 2019-03-04 09:56:30
tags:
- java
- 并发编程
categories: 
- java
---

所谓异步调用其实就是实现一个可无需等待被调用函数的返回值而让操作继续运行的方法。在 Java 语言中，简单的讲就是另启一个线程来完成调用中的部分计算，使调用继续运行或返回，而不需要等待计算结果

# java5之前

在java5之前，主要通过 `Thread` 或者实现 `Runnable` 来创建线程，可以通过 `Thread` 的一些方法来控制线程

```java
public class ThreadDemo {

    public static void main(String[] args) {
        normalThread();
        completableThread();
    }

    /**
     * 普通线程
     */
    private static void normalThread() {
        Thread thread = new Thread(() -> System.out.printf("[Thread : %s]Hello World...\n", Thread.currentThread().getName()), "Sub");

        thread.start();

        System.out.printf("[Thread : %s]Starting...\n", Thread.currentThread().getName());
    }

    /**
     * 获取线程是否已经完成
     * 在获取 completableRunnable.isCompleted() 值时并不一定是true
     *      我们会想到可见性的问题，所以在 completed 字段加上 volatile 关键字
     *      但是还是会出现上面的问题，这里涉及到线程的执行顺序，当Sub线程还未执行到 completed = true; 时，主线程已经执行完了
     *      要解决这个问题需要使用 thread.join() 方法，主线程等待Sub线程执行完成
     */
    private static void completableThread() {
        CompletableRunnable completableRunnable = new CompletableRunnable();
        Thread thread = new Thread(completableRunnable, "Sub");

        thread.start();

//        try {
//            thread.join();
//        } catch (InterruptedException e) {
//            e.printStackTrace();
//        }

        System.out.printf("[Thread : %s]Starting...\n", Thread.currentThread().getName());

        System.out.printf("runnable is completed : " + completableRunnable.isCompleted());
    }

    /**
     * 可完成的
     */
    private static class CompletableRunnable implements Runnable{

        private boolean completed = false;

        @Override
        public void run() {
            System.out.printf("[Thread : %s]Hello World...\n", Thread.currentThread().getName());
            completed = true;
        }

        public boolean isCompleted() {
            return completed;
        }
    }
}
```

java5之前实现的局限性：
1. 缺少线程管理的原生支持（没有线程池）
2. 缺少"锁"的api（缺少Lock这样的api）
3. 缺少执行完成的原生支持
4. 执行结果获取困难

# java5

## 线程池
java5增加了线程池，由 `Doug Lea` 编写

```java
public class ExecutorDemo {

    public static void main(String[] args) {

        // 执行器服务，线程池 ThreadPoolExecutor 是它的一种实现
        ExecutorService executor = Executors.newFixedThreadPool(1);

        executor.execute(() -> System.out.printf("[Thread : %s]Hello World...\n", Thread.currentThread().getName()));

        // 合理的关闭线程池是非常重要的
        executor.shutdown();
    }
}
```

## Future
增加了 `Future`，提供了可以获取执行结果的方法（Callable是有返回值操作，相对于Runnable）

```java
public class FutureDemo {

    public static void main(String[] args) {
        ExecutorService executorService = Executors.newFixedThreadPool(1);

        Future<String> future = executorService.submit(new Callable<String>() {
            @Override
            public String call() throws Exception {
                return "[Thread : " + Thread.currentThread().getName() + "]Hello World...";
            }
        });

        // 可以知道该线程是否执行完成
//        future.isDone();

        try {
            String v = future.get();
            System.out.println(v);
        } catch (InterruptedException | ExecutionException e) {
            e.printStackTrace();
        }

        executorService.shutdown();
    }
}
```

Future的限制：
1. 无法手动完成
2. 阻塞式结果返回 future.get()
3. 无法链式调用多个Future，从 ExecutorService#invokeAll 方法中只能返回Future的集合
4. 无法合并多个Future的结果，从 ExecutorService#invokeAll 方法中只能返回Future的集合

# java7

## Fork/Join

ForkJoin是Java7提供的原生多线程并行处理框架，其基本思想是将大人物分割成小任务，最后将小任务聚合起来得到结果。

它非常类似于HADOOP提供的MapReduce框架，只是MapReduce的任务可以针对集群内的所有计算节点，可以充分利用集群的能力完成计算任务。ForkJoin更加类似于单机版的MapReduce

Fork/Join使用两个类完成以上两件事情：
 
**ForkJoinTask**：

我们要使用ForkJoin框架，必须首先创建一个ForkJoin任务。它提供在任务中执行fork()和join的操作机制，通常我们不直接继承ForkjoinTask类，只需要直接继承其子类。
1. RecursiveAction，用于没有返回结果的任务
2. RecursiveTask，用于有返回值的任务
 
**ForkJoinPool**：

task要通过ForkJoinPool来执行，分割的子任务也会添加到当前工作线程的双端队列中，进入队列的头部。当一个工作线程中没有任务时，会从其他工作线程的队列尾部获取一个任务。

计算整数之和 DEMO：
```java
public class ForkJoinDemo {

    public static void main(String[] args) {

        ForkJoinPool forkJoinPool = new ForkJoinPool();

        LongAccumulator accumulator = new LongAccumulator(((left, right) -> left + right), 0);

        List<Long> params = new ArrayList<>();
        for (long i = 0; i < 10000000; i++) {
            params.add(i);
        }

        long start = System.currentTimeMillis();
        forkJoinPool.invoke(new LongSumTask(params, accumulator));
        long end = System.currentTimeMillis();

        System.out.println(accumulator.get());
        System.out.printf("消耗时间：%d %s\n", end - start, "ms");

        forkJoinPool.shutdown();
    }

    static class LongSumTask extends RecursiveAction {

        private final List<Long> elements;

        private final LongAccumulator accumulator;

        LongSumTask(List<Long> elements, LongAccumulator accumulator) {
            this.elements = elements;
            this.accumulator = accumulator;
        }

        @Override
        public void compute() {

            int size = elements.size();

            int parts = size / 2;

            // 使用简单的二分法，将计算平分，当元素只有一个的时候使用 LongAccumulator 进行累加计算
            if (size > 1) {

                List<Long> left = elements.subList(0, parts);
                List<Long> right = elements.subList(parts, size);

                new LongSumTask(left, accumulator).fork().join();
                new LongSumTask(right, accumulator).fork().join();

            } else {

                if (elements.isEmpty()) {
                    return;
                }

                Long num = elements.get(0);
                accumulator.accumulate(num);

            }

        }

    }
}
```

# java8
## CompletableFuture

在Java8中，`CompletableFuture` 提供了非常强大的Future的扩展功能，可以帮助我们简化异步编程的复杂性，并且提供了函数式编程的能力，可以通过回调的方式处理计算结果，也提供了转换和组合 `CompletableFuture` 的方法

`CompletableFuture` 实现了 `Future` 和 `CompletionStage`
```java
public class CompletableFuture<T> implements Future<T>, CompletionStage<T> {
    // ...
}
```

相关的操作可以查看官方API或者相关博客

DEMO：
```java
public class CompletableFutureDemo {

    public static void main(String[] args) throws ExecutionException, InterruptedException {

        // 1. 完成操作（可以被其它线程去做）
//        CompletableFuture<String> completableFuture = new CompletableFuture<>();
//        completableFuture.complete("Hello World");
//        String v = completableFuture.get();
//        System.out.println(v);

        // 2. runAsync 异步执行，阻塞操作
//        CompletableFuture asyncCompletableFuture = CompletableFuture.runAsync(() -> {
//            System.out.printf("[Thread : %s]Hello World...\n", Thread.currentThread().getName());
//        });
//
//        // 这里仍然是阻塞的
//        asyncCompletableFuture.get();
//
//        System.out.println("Starting...");

        // 3. supplyAsync 异步执行，阻塞操作
//        CompletableFuture<String> asyncCompletableFuture = CompletableFuture.supplyAsync(() -> {
//            // 获取数据操作，比如来自于数据库
//            return String.format("[Thread : %s]Hello World...\n", Thread.currentThread().getName());
//        });
//
//        String v = asyncCompletableFuture.get();
//        System.out.println(v);
//        System.out.println("Starting...");

        // 4. 合并操作
        CompletableFuture<String> combinedCompletableFuture = CompletableFuture.supplyAsync(() -> {
            // 获取数据操作，比如来自于数据库
            return String.format("[Thread : %s]Hello World...", Thread.currentThread().getName());
        }).thenApply(value -> {
            System.out.printf("current thread : %s\n", Thread.currentThread().getName());
            return value + " - 来自于数据库";
        }).thenApplyAsync(value -> {
            System.out.printf("current thread : %s\n", Thread.currentThread().getName());
            return value + " at " + LocalDate.now();
        }).exceptionally(e -> {
            // 异常处理
            e.printStackTrace();
            return "";
        });

        while (!combinedCompletableFuture.isDone()) {

        }

        String v = combinedCompletableFuture.get();
        System.out.println(v);

        System.out.println("Starting...");

    }
}
```

事实上，如果每个操作都很简单的话，没有必要用这种多线程异步的方式，因为创建线程还需要时间，还不如直接同步执行来得快。

事实证明，只有当每个操作很复杂需要花费相对很长的时间（比如，调用多个其它的系统的接口）的时候用 `CompletableFuture` 才合适，不然区别真的不大，还不如顺序同步执行。