---
title: iOS中常用的锁
abstract: 介绍在iOS中常用的一些锁的核心原理以及使用方式。
date: 2025-02-24 11:04:26
tags: 
 - iOS
 - 多线程
categories:
 - 锁
 - 多线程
---

# @synchronized

## 核心原理

### 底层实现

synchronized 在编译过程中会被转换成 `objc_sync_enter(obj)` 和`objc_sync_exit(obj)` 

### 锁对象

`obj `作为锁的标识（互斥量）， 对于使用一个`obj`的`synchronized `使用相同的锁。

如果使用不同的obj，多个`synchronized`不会互斥。

### 递归锁

`synchronized` 是可重入锁、递归锁，允许同一个线程多次获取同一个锁，避免死锁。也就是锁，同一个线程中嵌套使用`synchronized `不会阻塞。

### 锁的存储

在Runtime中会维护一个全局的Hash表，将对象obj映射到对应的锁（SyncData 结构体）。

obj释放时，锁自动销毁。

### 注意点

1. 锁对象根据上下文判断，如果保护实例变量，推荐使用self 或者 实例属性；

2. 如果保护类变量，使用类对象或者静态变量。

3. 避免使用临时变量导致不同的锁没办法互斥；

4. 注意生命周期的比较，避免锁提前释放导致出现问题。

5. synchronized 锁性能低于NSLock 和 dispatch_semaphore, 但是低竞争场景下差异可以忽略。

6. 高并发场景可以考虑使用更轻量级锁，比如 os_unfair_lock
   
   | 特性    | @synchronized | NSLock               | dispatch_semaphore |
   | ----- | ------------- | -------------------- | ------------------ |
   | 递归支持  | ✅             | ❌（需 NSRecursiveLock） | ❌                  |
   | 语法简洁性 | ✅             | ❌                    | ✅                  |
   | 性能    | 较低            | 较高                   | 最高                 |
   | 自动释放锁 | ✅（异常安全）       | ❌                    | ❌                  |

# NSLock

## 核心原理

基于 `pthread_mutex`的普通互斥锁。NSLock直接封装pthread_mutex , 直接调用pthread_mutex_lock 和 pthread_mutex_unlock 进行加锁和解锁。

## 特性

1. 非递归锁，同一个线程重复加锁会死锁。

2. 轻量级，性能比synchronized更优，比os_unfair_lock更差

3. 手动管理，需要单独lock和unlock.

| 特性    | `NSLock`    | `@synchronized` |
| ----- | ----------- | --------------- |
| 递归支持  | ❌           | ✅               |
| 异常安全性 | ❌（需 `@try`） | ✅（自动释放）         |
| 性能    | 较高          | 较低              |
| 代码简洁性 | ❌           | ✅               |

# NSRecursiveLock

## 核心原理

基于 `pthread_mutex`的递归锁。NSLock直接封装pthread_mutex , 直接调用pthread_mutex_lock 和 pthread_mutex_unlock 进行加锁和解锁。

NSRecursiveLock 通过设置 pthread_mutexattr_settye 设置递归属性。

## 特性

1. 递归锁，允许同一个线程多次加锁。

| 特性    | `NSRecursiveLock` | `@synchronized` |
| ----- | ----------------- | --------------- |
| 异常安全性 | ❌                 | ✅               |
| 性能    | 较高                | 较低              |
| 使用复杂度 | 较高（需手动）           | 低（语法糖）          |

# dispatch_semaphore

## 核心原理

基于GCD实现，本质就是一个原子的计数器，初始值由 dispatch_semaphore_create(N)指定。

- `dispatch_semaphore_wait` 执行 `P` 操作（计数器减 1），若计数器为负，线程进入等待队列。
- `dispatch_semaphore_signal` 执行 `V` 操作（计数器加 1），唤醒等待队列中的线程。
- 无竞争时完全在用户态运行，竞争时可能陷入内核态。

## 特性

1. 非递归锁，基于GCD信号量实现，性能极高。

2. 通过PV 操作控制并发。

| 特性    | `dispatch_semaphore` | `@synchronized` |
| ----- | -------------------- | --------------- |
| 递归支持  | ❌                    | ✅               |
| 性能    | 最高                   | 较低              |
| 超时控制  | ✅（可设置超时时间）           | ❌               |
| 代码简洁性 | ❌                    | ✅               |

```objc
dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
// 临界区代码
dispatch_semaphore_signal(semaphore);
```

# os_unfair_lock

# 底层原理

- 底层是 `os_unfair_lock` 结构体，内部封装了 `uint32_t` 的状态标志。
- **自旋+等待队列**：
  - 无竞争时通过原子操作（`os_unfair_lock_lock`）快速获取锁。
  - 竞争时，线程进入等待队列，由内核调度（类似 `pthread_mutex`，但更轻量）。
- **优先级继承**：
  - 内核会临时提升等待线程的优先级，避免优先级反转。

## 特性

1. 非递归锁： 在iOS 10 + 之后使用，替代了OSSpinLock, 主要解决优先级反转问题。

2. 性能解决直接调用原子操作。

```objc
#import <os/lock.h>

os_unfair_lock unfairLock = OS_UNFAIR_LOCK_INIT;
os_unfair_lock_lock(&unfairLock);
// 临界区代码
os_unfair_lock_unlock(&unfairLock);
```

# pthread_mutex

### 底层原理

- **POSIX 标准互斥锁**：
  - 通过 `pthread_mutex_init` 初始化，可配置为普通锁、递归锁或错误检查锁。
  - 底层可能是用户态自旋锁或内核态互斥锁，具体依赖系统实现。
- **内核支持**：
  - 竞争时，线程通过 Mach 内核的 `mach_msg_trap` 进入阻塞状态，由内核唤醒。

## 特性

1. 可配置递归性

2. 灵活性强，支持条件变量  pthread_cond_t

| 特性    | `pthread_mutex` | `@synchronized` |
| ----- | --------------- | --------------- |
| 递归支持  | ✅（需配置）          | ✅               |
| 性能    | 高               | 较低              |
| 跨平台   | ✅（POSIX 标准）     | ❌（仅 Apple 平台）   |
| 使用复杂度 | 高               | 低               |

```objc
pthread_mutex_t mutex;
pthread_mutex_init(&mutex, NULL); // 可配置为递归锁
pthread_mutex_lock(&mutex);
// 临界区代码
pthread_mutex_unlock(&mutex);
```

# NSCondition 与 NSConditionLock

### 底层原理

- **组合锁**：
  - `NSCondition` = `pthread_mutex` + `pthread_cond_t`（条件变量）。
  - `NSConditionLock` 在 `NSCondition` 基础上封装了条件值（`integer`）。
- **条件变量逻辑**：
  - `wait`：释放锁并阻塞线程，等待其他线程的 `signal` 或 `broadcast`。
  - `signal`：唤醒一个等待线程。
  - `broadcast`：唤醒所有等待线程。

#### **关键点**：

- 适合生产者-消费者模型，避免忙等待（busy-waiting）。
- 性能中等，因为涉及内核态线程调度。

## 特性

1. 条件锁，允许线程等待特定条件成立，比如资源就绪。
   
   ```objc
   NSCondition *condition = [[NSCondition alloc] init];
   [condition lock];
   while (!resourceReady) {
       [condition wait]; // 等待信号
   }
   // 使用资源
   [condition unlock];
   ```

# 思考

## synchronized 什么情况需要嵌套使用这个锁，解决什么问题？

在 Objective-C 中，`@synchronized` 的嵌套使用主要解决 **同一线程多次访问共享资源时可能导致的死锁问题**，其核心场景和解决方案如下：

---

### 何时需要嵌套使用 `@synchronized`？

#### 1. 递归方法调用（最常见场景）

当一个方法内部递归调用自身，且该方法需要保护共享资源时，必须使用嵌套锁。

**示例**：

```objectivec
- (void)recursiveMethod:(NSInteger)count {
    @synchronized (self) {
        if (count > 0) {
            [self.sharedArray addObject:@(count)]; // 操作共享资源
            [self recursiveMethod:count - 1];      // 递归调用
        }
    }
}
```

- **问题**：如果 `@synchronized` 不是递归锁，第二次进入 `@synchronized(self)` 时会导致死锁。
- **解决**：`@synchronized` 的递归特性允许同一线程多次获取同一把锁。

---

#### 2. 方法链调用

当多个方法（如 `A → B → C`）都需要操作同一共享资源，且这些方法被设计为独立线程安全时，需要嵌套锁。

**示例**：

```objectivec
// 方法A
- (void)methodA {
    @synchronized (self) {
        [self methodB]; // 调用方法B
    }
}

// 方法B
- (void)methodB {
    @synchronized (self) {
        [self methodC]; // 调用方法C
    }
}

// 方法C
- (void)methodC {
    @synchronized (self) {
        [self.sharedData update]; // 最终操作共享资源
    }
}
```

- **问题**：如果 `@synchronized` 不支持嵌套，`methodA → methodB → methodC` 的调用链会导致死锁。
- **解决**：递归锁允许同一线程在调用链中重复获取锁。

---

#### 3. 复杂对象关系

当多个对象的方法需要协作操作同一共享资源，且这些方法可能被嵌套调用时。

**示例**：

```objectivec
// 对象A的方法
- (void)updateData {
    @synchronized (self.lock) {
        [objectB validate]; // 调用对象B的方法
        [self.data commit];
    }
}

// 对象B的方法
- (void)validate {
    @synchronized (objectA.lock) { // 使用与对象A相同的锁
        if (self.isValid) {
            [objectA.data markValid];
        }
    }
}
```

- **问题**：若 `objectA` 和 `objectB` 使用同一把锁，嵌套调用可能导致递归锁需求。
- **解决**：通过递归锁避免同一线程在跨对象调用时死锁。

---

### 嵌套锁的核心作用

1. **避免同一线程的死锁**  
   
   - 递归锁允许同一线程多次获取同一把锁，确保嵌套调用不会阻塞自身。

2. **简化代码设计**  
   
   - 允许方法独立保证线程安全，无需关心是否会被嵌套调用。

3. **保护共享资源的完整性**  
   
   - 确保嵌套操作共享资源时，临界区的原子性不被破坏。

---

### 注意事项

1. **锁对象必须一致**  
   
   - 嵌套的 `@synchronized(obj)` 必须使用同一个 `obj`，否则无法触发递归特性，可能导致死锁。
   
   ```objectivec
   // 错误示例：嵌套使用不同锁对象
   - (void)methodA {
       @synchronized (self.lock1) {
           [self methodB]; // 死锁风险！
       }
   }
   
   - (void)methodB {
       @synchronized (self.lock2) { // 锁对象不一致
           // ...
       }
   }
   ```

2. **控制嵌套深度**  
   
   - 过度嵌套会增加锁的持有时间，降低性能。尽量缩小临界区范围。

3. **避免跨线程嵌套**  
   
   - 递归锁仅对同一线程有效，跨线程嵌套仍会导致竞争。

---

### 与其他锁的对比

| 场景       | `@synchronized`（递归锁） | `NSLock`（非递归锁） |
| -------- | -------------------- | -------------- |
| 同一线程嵌套调用 | ✅ 安全                 | ❌ 死锁           |
| 跨线程竞争    | ✅ 安全                 | ✅ 安全           |
| 性能       | 较低                   | 较高             |

---

### 总结

- **必须嵌套**：当方法递归调用或调用链中需要重复获取同一把锁时。
- **避免嵌套**：若共享资源操作可以拆分为非嵌套的独立临界区，优先减少锁的粒度。
- **递归锁是唯一选择**：在需要线程安全且可能递归/嵌套调用的场景下，`@synchronized` 是最简解决方案。

## 什么是优先级反转（Priority Inversion）？

优先级反转是多线程编程中一种资源竞争导致的现象，**高优先级线程**因等待**低优先级线程**持有的资源而被阻塞，而**中优先级线程**可能抢占资源持有者（低优先级线程），进一步延长高优先级线程的等待时间。这种场景会导致系统实时性严重下降，甚至引发死锁。

#### **为什么 `OSSpinLock` 会加剧优先级反转？**

- **自旋锁的特性**：
  - `OSSpinLock` 是**忙等待锁**（Busy-Wait Lock），线程在等待锁时会持续占用 CPU 循环检查锁状态。
  - 在锁持有时间短时，自旋锁性能优异（避免线程切换开销）。
- **问题根源**：
  - 若低优先级线程持有锁，高优先级线程自旋等待时，**中优先级线程可能抢占 CPU**，导致低优先级线程无法及时释放锁。
  - 高优先级线程因自旋占用 CPU，系统误认为其处于活跃状态，不会触发优先级调整，最终形成**死等**。

### **如何解决优先级反转？**

#### **1. 优先级继承（Priority Inheritance）**

- **核心思想**：
  - 当高优先级线程（A）等待低优先级线程（C）持有的锁时，**临时提升线程 C 的优先级**至与 A 相同。
  - 确保线程 C 尽快执行并释放锁，避免被中优先级线程（B）抢占。
- **实现方式**：
  - 锁的实现需与系统调度器深度集成，动态调整线程优先级。
  - 锁释放后，线程 C 的优先级恢复原状。

#### **2. `os_unfair_lock` 的解决方案**

- **替代 `OSSpinLock`**：
  - iOS 10+ 引入 `os_unfair_lock`，明确设计为**非自旋锁**，解决优先级反转问题。
- **底层机制**：
  1. **等待队列**：
     - 竞争锁时，线程不再自旋，而是进入等待队列休眠，释放 CPU。
  2. **优先级继承**：
     - 系统自动将锁持有者（低优先级线程）的优先级提升至等待线程（高优先级）的优先级。
  3. **内核调度优化**：
     - 依赖 Mach 内核的线程调度，确保高优先级需求被快速响应。

---

### **对比 `OSSpinLock` 与 `os_unfair_lock`**

| 特性         | `OSSpinLock` (已废弃) | `os_unfair_lock` (推荐) |
| ---------- | ------------------ | --------------------- |
| **锁类型**    | 自旋锁（忙等待）           | 非自旋锁（休眠等待）            |
| **优先级反转**  | 高风险（无优先级继承）        | 低风险（支持优先级继承）          |
| **CPU 占用** | 高（持续占用 CPU 自旋）     | 低（线程休眠，不占用 CPU）       |
| **适用场景**   | 极短临界区（纳秒级）         | 短临界区（微秒级）             |
| **线程调度**   | 用户态自旋              | 内核态调度                 |
