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
donate: true
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

**dispatch_source**

这是一个功能强大的API，用于处理基于事件的异步任务。它可以处理如定时器、信号处理、文件描述符相关事件（如读取、写入等）等多种类型的事件。`dispatch_source` 能够在事件发生时自动将任务添加到指定的队列中执行，从而实现高效的事件驱动编程。

**使用场景和示例 - 定时器应用**：

- 假设要实现一个简单的定时器，每隔一段时间执行一个任务。
  
  ```objc
  // Objective - C示例
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
  dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
  uint64_t interval = (uint64_t)(1.0 * NSEC_PER_SEC);
  dispatch_source_set_timer(timer, start, interval, 0);
  dispatch_source_set_event_handler(timer, ^{
  // 在这里执行定时任务，比如更新UI上的时间显示
  NSDate *currentDate = [NSDate date];
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setDateFormat:@"HH:mm:ss"];
  NSString *dateString = [formatter stringFromDate:currentDate];
  self.timerLabel.text = dateString;
  });
  dispatch_resume(timer);
  ```
  
  ```swift
  // Swift示例
  let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
  let start = DispatchTime.now() + 1.0
  let interval: DispatchTimeInterval =.seconds(1)
  timer.schedule(deadline: start, repeating: interval)
  timer.setEventHandler {
  // 在这里执行定时任务，比如更新UI上的时间显示
  let currentDate = Date()
  let formatter = DateFormatter()
  formatter.dateFormat = "HH:mm:ss"
  let dateString = formatter.string(from: currentDate)
  self.timerLabel.text = dateString
  }
  timer.resume()
  ```
  
  在Objective - C示例中，首先使用 `dispatch_source_create` 创建一个定时器类型（`DISPATCH_SOURCE_TYPE_TIMER`）的 `dispatch_source` 对象，并将其与主队列（`dispatch_get_main_queue`）关联，这样定时器事件触发后的任务会在主线程执行。接着设置定时器的启动时间（`dispatch_time`）和间隔时间（`interval`），通过 `dispatch_source_set_timer` 来配置定时器。然后使用 `dispatch_source_set_event_handler` 定义定时器事件触发时要执行的任务，这里是更新一个UI标签来显示当前时间。最后通过 `dispatch_resume` 启动定时器。Swift示例的操作过程类似，不过在一些函数和类型的使用上更符合Swift的语法习惯。

- **使用场景和示例 - 文件读取应用**：

- 当读取一个文件时，可以使用 `dispatch_source` 来监控文件读取事件，以便在数据可用时进行处理。
  
  ```objc
  // Objective - C示例
  int fileDescriptor = open("example.txt", O_RDONLY);
  dispatch_source_t readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fileDescriptor, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
  dispatch_source_set_event_handler(readSource, ^{
  char buffer[1024];
  ssize_t bytesRead = read(fileDescriptor, buffer, sizeof(buffer));
  if (bytesRead > 0) {
  // 处理读取到的数据
  NSString *dataString = [[NSString alloc] initWithBytes:buffer length:bytesRead encoding:NSUTF8StringEncoding];
  NSLog(@"读取到的数据: %@", dataString);
  } else if (bytesRead == 0) {
  // 文件读取完毕
  dispatch_source_cancel(readSource);
  close(fileDescriptor);
  }
  });
  dispatch_resume(readSource);
  ```
  
  ```swift
  // Swift示例
  let fileURL = URL(fileURLWithPath: "example.txt")
  let fileDescriptor = open(fileURL.path, O_RDONLY)
  let readSource = DispatchSource.makeReadSource(fileDescriptor: fileDescriptor, queue: DispatchQueue.global())
  readSource.setEventHandler {
  let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: 1024)
  let bytesRead = read(fileDescriptor, buffer, 1024)
  if bytesRead > 0 {
  // 处理读取到的数据
  let dataString = String(cString: buffer, encoding:.utf8)
  print("读取到的数据: \(dataString!)")
  } else if bytesRead == 0 {
  // 文件读取完毕
  readSource.cancel()
  close(fileDescriptor)
  }
  buffer.deallocate()
  }
  readSource.resume()
  ```

**dispatch_apply**

这个函数用于在指定的队列上以并行或串行的方式多次执行一个任务。它类似于一个循环，但可以利用队列的并行性来提高执行效率，特别是对于可以并行处理的任务。

- 假设要对一个数组中的元素进行某种操作，并且这些操作可以并行进行，比如对数组中的每个元素进行平方运算。
  
  ```objc
  // Objective - C示例
  NSArray *numbers = @[@1, @2, @3, @4, @5];
  dispatch_queue_t concurrentQueue = dispatch_queue_create("com.example.concurrentQueue", DISPATCH_QUEUE_CONCURRENT);
  dispatch_apply(numbers.count, concurrentQueue, ^(size_t index) {
  NSNumber *number = numbers[index];
  NSNumber *squaredNumber = @([number integerValue] * [number integerValue]);
  NSLog(@"元素 %@ 的平方是 %@", number, squaredNumber);
  });
  ```
  
  ```swift
  // Swift示例
  let numbers = [1, 2, 3, 4, 5]
  let concurrentQueue = DispatchQueue(label: "com.example.concurrentQueue", attributes:.concurrent)
  dispatch_apply(numbers.count, concurrentQueue) { index in
  let number = numbers[index]
  let squaredNumber = number * number
  print("元素 \(number) 的平方是 \(squaredNumber)")
  }
  ```

**dispatch_set_target_queue**

用于设置一个队列的目标队列。这在管理队列的优先级和继承关系等方面非常有用。例如，可以将一个自定义队列的目标队列设置为全局队列，这样自定义队列中的任务会根据目标队列的优先级和属性来执行。

- 假设有一个自定义的串行队列，希望它继承全局队列的优先级和一些属性，就可以使用这个API。
  
  ```objc
  // Objective - C示例
  dispatch_queue_t customSerialQueue = dispatch_queue_create("com.example.customSerialQueue", DISPATCH_QUEUE_SERIAL);
  dispatch_queue_t targetGlobalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_set_target_queue(customSerialQueue, targetGlobalQueue);
  dispatch_async(customSerialQueue, ^{
  // 执行任务，会根据目标全局队列的优先级等属性来执行
  NSLog(@"任务在自定义串行队列中执行，其目标是全局队列");
  });
  ```
  
  ```swift
  // Swift示例
  let customSerialQueue = DispatchQueue(label: "com.example.customSerialQueue", attributes:.serial)
  let targetGlobalQueue = DispatchQueue.global()
  customSerialQueue.setTarget(queue: targetGlobalQueue)
  customSerialQueue.async {
  // 执行任务，会根据目标全局队列的优先级等属性来执行
  print("任务在自定义串行队列中执行，其目标是全局队列")
  }
  ```

- 在Objective - C示例中，首先创建了一个自定义的串行队列 `customSerialQueue` 和一个目标全局队列 `targetGlobalQueue`，然后使用 `dispatch_set_target_queue` 将自定义队列的目标队列设置为全局队列。之后通过 `dispatch_async` 将任务添加到自定义队列中，这个任务会根据目标全局队列的优先级等属性来执行。Swift示例的操作类似，只是在设置目标队列的语法上略有不同（`setTarget(queue:)`）。

### NSOperation

NSOperation 是一个抽象类。自定义子类继承NSOperation 实现具体的任务细节以及执行、暂停、取消等能力。

NSOperation对象将每一类任务封装成一个对象，使其可以独立执行和管理，同时可以独立的管理执行、暂停、取消事件。

可以看到在GCD中并没有提供这种程度的封装和对于执行过程的控制能力。NSOperation更细粒度的管理任务的执行。

**关键属性和方法**

**main**

通常需要重写main方法定义任务的具体逻辑。Operation被执行时，main方法会在一个合适的线程中运行。

eg. code

```swift
class DataProcessingOperation: NSOperation {
    override func main() {
        guard !self.isCancelled else {
            return
        }
        var sum = 0
        for i in 1...100 {
            sum += i
        }
        print("result of data process: \(sum)")

    }
}
```

**start**

这个方法用于启动一个Operation。 在生产环境中，通常将Operation添加到队列中，将执行操作交给队列进行管理。

**NSOperationQueue 与任务调度**

NSOperationQueue 用于管理NSOperation实例。队列的属性`maxConcurrentOperationCount` 用于设置队列中同时可以执行的操作的数量。设置为1时相当于串行队列，否则并发队列。默认值为-1。

eg. 

```swift
let operation1 = DataProcessingOperation()
let operation2 = FileDownloadOperation()
let operationQueue = NSOperationQueue()
operationQueue.addOperation(operation1)
operationQueue.addOperation(operation2)
```

waitUntilFinished 属性，设置为true，阻塞线程，直到队列内任务执行完毕。

```swift
let operationArray: [NSOperation] = [operation1, operation2]
operationQueue.addOperations(operationArray, waitUntilFinished: false)
```

**Operation之间的依赖和优先级**

**依赖关系**

Operation 通过addDependency 方法为操作增加依赖关系 。 

eg, A 依赖 B， A会在B执行完之后开始执行。

```swift
let downloadOperation = FileDownloadOperation()
let filterOperation = ImageFilterOperation()
filterOperation.addDependency(downloadOperation)
let operationQueue = NSOperationQueue()
operationQueue.addOperation(downloadOperation)
operationQueue.addOperation(filterOperation)
```

**优先级设置**

设置Operation的优先级只能影响Operation的执行顺序，但是还是会收到依赖、系统资源的影响。

```swift
let highPriorityOperation = DataProcessingOperation()
highPriorityOperation.queuePriority =.veryHigh
let normalPriorityOperation = FileDownloadOperation()
let operationQueue = NSOperationQueue()
operationQueue.addOperation(highPriorityOperation)
operationQueue.addOperation(normalPriorityOperation)
```

暂时先写到这里... 复习时可能会补充。
