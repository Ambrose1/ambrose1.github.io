---
title: iOS多线程操作总结
abstract: 总结iOS设备中多线程的使用方式和应用场景
date: 2024-12-25 16:57:27
tags:
 - 多线程操作
 - Objective-C
 - swift
categories: 
- iOS
---

# 序

在iOS设备上，一般一个进程对应一个程序实例，是资源分配的基本单位。每一个程序包含多个线程模型。

在iOS应用程序启动后，应用会主动创建一个主线程。主线程主要负责处理UI相关事件，包括UI渲染、触摸事件。

> UIKit 不是线程安全的，所以所有操作UI的事件必须在主线程执行，否则会崩溃。

# 一. 疑问

## 1.1 为什么要用多线程？

1. 提高性能，2件事两个人做比一个人做效率高。

2. 防止卡顿，耗时任务在主线程执行会导致用户交互卡顿，影响体验。

## 1.2 多线程的典型应用场景有哪些？

1. 网络请求

2. 读写文件

3. 复杂计算

# 二. 使用方式

## 2.1 使用思路

跳出技术本身，从抽象的层次思考，我们怎么使用多线程：以网络请求为例，

1. 首先，需要实现网络请求任务的逻辑代码，作为一个任务。

2. 然后，创建一个线程，并将上面创建的任务传给线程。

3. 唤醒新线程，执行任务。

4. 等待线程结束（等待期间其他线程正常工作）。

5. 将网络请求结果抛给需求方（可能是主线程进行UI刷新）。

6. 释放线程资源。

## 2.2 C 的实现

```c
#include <stdio.h>
#include <pthread.h>


void *thread_function(void *arg) {
    // 这里是子线程要执行的任务
    printf("子线程开始执行任务\n");
    // 可以进行各种计算、I/O操作等
    // 假设这里进行一个简单的循环
    for (int i = 0; i < 5; i++) {
        printf("子线程执行中: %d\n", i);
    }
    printf("子线程任务完成\n");
    // 线程函数必须返回一个void*类型的值，通常可以返回 NULL
    return NULL;
}


int parameter = 10;
//int pthread_create(pthread_t *thread, const pthread_attr_t *attr, void *(*start_routine)(void *), void *arg);
pthread_t thread_id;
int result = pthread_create(&thread_id, NULL, thread_function, &parameter);
if (result!= 0) {
    // 如果线程创建失败，打印错误信息
    perror("线程创建失败");
    return 1;
}
int pthread_join(pthread_t thread, void **retval);

void *thread_result;
int join_result = pthread_join(thread_id, &thread_result);
if (join_result!= 0) {
    // 如果等待线程结束失败，打印错误信息
    perror("等待线程结束失败");
    return 1;
}

pthread_attr_t thread_attr;
// 假设已经设置了线程属性
pthread_attr_destroy(&thread_attr);
```

## 2.3 生产环境中的多线程

在生产环境中，创建一个新的线程通常会分配给它多个任务，通常使用队列管理这些任务。在iOS中，可以使用GCD和 NSOperation 进行多线程操作。

### GCD

GCD 是一种基于队列的多线程技术，开发者只要将任务添加到队列中，然后根据系统资源和队列优先级自动分配线程来执行队列中的任务。

GCD是一套基于C语言的封装，对外暴露了简单的API，开发者只需要关注任务本身和任务所属的队列类型。

**GCD的队列**

串行队列，Serial Dispatch Queue: 顺序执行，先进先出。

并行队列， Concurrent Dispatch Queue: 并发执行任务。

在GCD中有两种特殊的队列：

1. 主队列，Main Dispatch Queue
   
   主队列的所有任务都会在主线程执行。
   
   主队列是一种串行队列。
   
   ```swift
   import UIKit
   
   class ViewController: UIViewController {
       override func viewDidLoad(){
           super.viewDidLoad()
           DispatchQueue.global().async {
               // 耗时操作
               let result = self.doSomeComplexCalculation()
               DispatchQueue.main.async {
                   // 更新ui
                   self.updateUI(result)
               }
           }
       }
   }
   ```

2. 全局队列 Global Dispatch Queue
   
   全局队列是一种并行队列，适合执行耗时任务。
   
   全局队列有4个优先级： 高> 默认 > 低 > 后台
   
   ```swift
   import UIKit
   
   class ViewController: UIViewController {
       override func viewDidLoad(){
           super.viewDidLoad()
           let highPriQue = DispatchQueue.global(qos:.userInitiated)
           highPriQue.async {
               self.doTask1()
           }
           highPriQue.async {
               self.doTask2()
           }
   
       }
   }
   
   ```

**OC 版本**

```objc
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 创建一个高优先级的全局队列
    dispatch_queue_t highPriorityQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    // 模拟同时执行三个任务
    dispatch_async(highPriorityQueue, ^{
        [self doTask1];
    });
    
    dispatch_async(highPriorityQueue, ^{
        [self doTask2];
    });
    
    dispatch_async(highPriorityQueue, ^{
        [self doTask3];
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // 模拟在后台线程完成一个任务后更新UI
    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(globalQueue, ^{
        // 这里是在后台线程执行的任务，比如进行一个复杂的计算或者网络请求
        NSInteger result = [self doComplexCalculation];
        // 使用主队列来更新UI，确保UI更新操作在主线程进行
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateUI:result];
        });
    });
}
```

**GCD的其他API**

**dispatch_once**

> 保证在整个应用程序的生命周期只执行一次，通常用于单例模式。

```objc
+ (instancetype)sharedInstance {
    static ClassName *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}
```

**dispatch_group**

将多个任务组合在一起，方便等待一组任务都完成后再执行其他操作。

```objc
dispatch_group_t group = dispatch_group_create();
dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0);
dispatch_group_async(grroup, queue, ^{
    [self task1];
});

dispatch_group_async(grroup, queue, ^{
    [self task2];
});


dispatch_group_notify(group, dispatch_get_main_queue(), ^{
    [self mainTask];
});
```

```swift
// Swift示例
let group = DispatchGroup()
let queue = DispatchQueue.global()
group.enter()
queue.async {
    // 从接口1获取数据
    let data1 = self.getDataFromAPI1()
    // 处理data1...
    group.leave()
}
group.enter()
queue.async {
    // 从接口2获取数据
    let data2 = self.getDataFromAPI2()
    // 处理data2...
    group.leave()
}
group.notify(queue: DispatchQueue.main) {
    // 所有任务完成后，在主线程合并和展示数据
    self.combineAndShowData()
}
```

**dispatch_barrier**

在并发队列中创建一个同步点，当一个任务被标记为`dispatch_barrier`时，在它执行期间，并发队列会暂停其他任务执行，直到这个屏障任务完成。

用于对共享资源的写操作时保证数据的一致性。

```objc
// 更新缓存时设置barrier
dispatch_queue_t concurrentQue = dispatch_queue_create("com.example.concurrentQueue", DISPATCH_QUEUE_CONCURRENT);
dispatch_async(concurrentQue, ^{
    [self readCache];
});

dispatch_async(concurrentQue, ^{
    [self readCache];
});

dispatch_barrier_async(concurrentQue, ^{
    [self updateCache];
});


```

```swift
// Swift示例
let concurrentQueue = DispatchQueue(label: "com.example.concurrentQueue", attributes:.concurrent)
// 多个线程可以并发读取缓存
concurrentQueue.async {
    // 读取缓存操作
    let cachedData = self.readFromCache()
}
concurrentQueue.async {
    // 读取缓存操作
    let cachedData = self.readFromCache()
}
// 当需要更新缓存时，使用屏障任务
concurrentQueue.async(flags:.barrier) {
    // 更新缓存操作
    self.updateCache()
}
```

**dispatch_sampore**

信号量是一种用于控制并发访问资源的机制。`dispatch_semaphore` 可以用于实现线程间的同步和互斥。它维护一个计数，当计数大于 0 时，允许线程访问资源，当计数为 0 时，线程会被阻塞，直到计数大于 0。

```objc
// Objective - C示例
dispatch_semaphore_t semaphore = dispatch_semaphore_create(3);
dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
for (int i = 0; i < 10; i++) {
    dispatch_async(queue, ^{
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        // 获取数据库连接并使用
        DatabaseConnection *connection = [self getDatabaseConnection];
        [self useDatabaseConnection:connection];
        // 释放数据库连接
        [self releaseDatabaseConnection:connection];
        dispatch_semaphore_signal(semaphore);
    });
}
```

```swift
// Swift示例
let semaphore = DispatchSemaphore(value: 3)
let queue = DispatchQueue.global()
for _ in 0..<10 {
    queue.async {
        semaphore.wait()
        // 获取数据库连接并使用
        let connection = self.getDatabaseConnection()
        self.useDatabaseConnection(connection)
        // 释放数据库连接
        self.releaseDatabaseConnection(connection)
        semaphore.signal()
    }
}
```

在 Objective - C 示例中，首先使用 `dispatch_semaphore_create` 创建一个信号量，初始值为 3，表示最多允许 3 个线程同时访问资源。然后在一个循环中，通过 `dispatch_async` 将任务添加到全局队列中异步执行。每个任务在访问数据库连接前，使用 `dispatch_semaphore_wait` 等待信号量计数大于 0，获取到信号量后（计数减 1），就可以获取和使用数据库连接。使用完后，通过 `dispatch_semaphore_signal` 释放信号量（计数加 1），以便其他线程可以获取。Swift 示例的原理和操作方式类似。



**`dispatch_source`**

**`dispatch_apply`**

**`dispatch_set_target_queue`**

未完待续...
