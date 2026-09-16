/*
 * WCRSideloadFix — 自签修复（修复自签分享跳转 / 消息详情头像显示）
 *
 * 本文件按 WCRefine.dylib (微信 8.0.78) 的反汇编结果 1:1 重建，
 * 所有函数/常量后面都标注了其在二进制中的真实地址，不再是"我自己的设计"。
 *
 *  ── 证据总览 ────────────────────────────────────────────────────────────
 *  安装入口                     0x8f3508   WCRSideloadFixInstall
 *  swizzle NSFileManager        0x8f3630   （受 bss 0x2526a68 记忆位保护）
 *  swizzle 其余 8 处             0x8f3698
 *  手写 swizzle helper          0x8f393c   (Class, SEL, IMP newIMP, IMP *orig)
 *  被 hook 的 IMP                0x8f3af8   -[NSFileManager containerURLForSecurityApplicationGroupIdentifier:]
 *
 *  进程判定                     0x1482108  IsShareExtensionProcess
 *                               0x148230c  IsNotificationServiceProcess
 *                               0x14820c8  IsGroupRemapExtensionProcess (= 上两者取或)
 *   entitlement 四级回退         0x147d4e8  ReadEffectiveEntitlements
 *  可用应用组                    0x147e154  WCRSideloadShareFixApplicationGroupIDs
 *  marker 读/写                  0x148190c / 0x14815d8 / 0x14810f8
 *  主 App 解析出的组             0x1481ec0  WCRSideloadShareFixResolvedGroupID
 *  ProtobufLite 链接检查          0x14804f8  WCRSideloadShareFixPreferredHostLinked
 *  云控开关                      0x148236c  WCRSideloadShareFixCloudAllowed
 *  总开关 ShouldInstall          0x14823ec
 *
 *  ── 「需注入 ProtobufLite3（没有则 ProtobufLite）」的真实判定 ──────────────
 *  0x14804f8  PreferredHostLinked      memo: bss 0x253a6f0/0x253a6f1
 *  0x148056c  找宿主二进制  <bundle>/{Frameworks,Contents/Frameworks}/
 *                          {ProtobufLite3(@0x205b4b6),ProtobufLite(@0x205b4c4)}.framework
 *                          可执行文件取 Info.plist["CFBundleExecutable"]
 *  0x147f6a4  fopen(path,"rb") 解析 Mach-O，只看
 *             LC_LOAD_DYLIB(0x0c) / LC_LOAD_WEAK_DYLIB(0x80000018) /
 *             LC_REEXPORT_DYLIB(0x8000001f) / LC_LOAD_UPWARD_DYLIB(0x80000023)
 *             的 dylib 名字，strnstr(name, "WCRefine")  ← 标记串 @0x202a8b8
 *  0x147ccf4  fat 中定位 arm64 slice（CPU_TYPE_ARM64），thin 返回 0，失败 -1
 *  0x147cff4  BOOL ReadAt(FILE *, uint64_t off, void *buf, size_t len)
 *  0x147d0b4  be32（fat_header/fat_arch 全是大端）
 *
 *  结论：判的不是"ProtobufLite 被没被加载"，而是
 *        **磁盘上那份 ProtobufLite 二进制有没有被 Icsign 注入 WCRefine**
 *        （注入后 Mach-O 会多一条指向 WCRefine.dylib 的 LC_LOAD_DYLIB）。
 *  实测微信 8.0.78 的 Frameworks/ 只有 ProtobufLite.framework（无 ProtobufLite3），
 *  且其依赖表里没有 WCRefine → 原始包下返回 NO，故未注入时功能不挂载。
 *
 *  ── 纯本地运行形态 ───────────────────────────────────────────────────────
 *  · 无云控（0x148236c 已删除）；无本地开关；无设置页 UI。
 *  · 功能默认生效：主 App 进程在 ShouldInstall 通过后自动选第一个可用应用组并写 marker，
 *    扩展进程（NSE / 分享）靠 marker 反查主 App 选定组，三类功能（通知详情/头像/分享跳转）即生效。
 *
 *  ── 私有函数（本文件按原样重建）─────────────────────────────────────────
 *  0x8f5490  WCRCurrentGroupID        扩展:0x8f3f40(nil)  主App:0x1481ec0
 *  0x8f4b9c  WCRFixActive             扩展:当前组非空    主App:默认 YES（纯本地，无开关）
 *  0x8f4cd0  WCRShouldRemapGroup      空→NO；在可用组里→YES；hasPrefix "group.com.tencent."→YES
 *  0x8f4e50  WCRRemappedContainerURL  LSBundleProxy.groupContainerURLs[gid] → 回退原 IMP
 *  0x8f3f40  WCRRemapGroupID          扩展进程：扫所有容器找 marker，得到主 App 选定的组
 *  0x8f54e4  WCRCachedAvailableGroups
 *  0x8f6af4  WCREnsureDirectory
 *  0x8f53b8  WCRProbe                 （WCR 内已被裁成空实现，本文件同样保留为 no-op）
 *
 *  ── 关键结论 ────────────────────────────────────────────────────────────
 *  WCR 真正拿到容器的首选路径是私有 API：
 *      Class  LSBundleProxy                      (@"LSBundleProxy"             @0x20447ac)
 *      +[LSBundleProxy bundleProxyForCurrentProcess]  (@"bundleProxyForCurrentProcess" @0x20447ba)
 *      -[LSBundleProxy groupContainerURLs]        (@"groupContainerURLs"       @0x20447d7)
 *      NSDictionary *urls;  urls[resolvedGroupID]  → NSURL
 *  它**绕过 com.apple.security.application-groups entitlement 校验**，
 *  这正是自签包（无 entitlement）也能拿到正确容器 URL 的原因。
 *  只有在 LSBundleProxy 不可用时才回退到原始 IMP。
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <stdio.h>
#import <string.h>
#import <stdlib.h>

/* 手动声明 WCPluginsMgr 接口（DD收款助手同款插件管理器；用户确认在 8.0.78 真实存在，
 * 故不再走 objc_getClass 运行期取类，改为编译期静态调用）。 */
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title
                            version:(NSString *)version
                         controller:(NSString *)controller;
@end

#pragma mark - 常量（全部来自 __cstring / __cfstring）

/* @0x204476c —— marker 文件名：主 App 把"选定的应用组"写进所有可用容器的
 *   <container>/Library/Preferences/ 下；扩展进程反过来扫这些文件找回组 id。 */
static NSString * const kWCRMarkerFileName = @"com.qimiao.WCRefine.sideload-share-fix-group";
/* @0x205b1b9 —— 探针日志（WCR 内 0 调用，保留） */
static NSString * const kWCRProbeLogName   = @"com.qimiao.WCRefine.sideload-share-fix.log";

static NSString * const kWCREntitlementAppGroups = @"com.apple.security.application-groups"; // @0x22bf480
static NSString * const kWCRExtShareService       = @"com.apple.share-services";              // @0x1482130
static NSString * const kWCRExtNotificationService= @"com.apple.usernotifications.service";   // @0x1482334

/* 0x8f45bc / 0x8f5f2c / 0x8f4df0 */
static NSString * const kWCRPrefsSubPath   = @"Library/Preferences";   // @0x2290280
static NSString * const kWCRGroupPrefix    = @"group";                 // @0x226f000
static NSString * const kWCRTencentPrefix  = @"group.com.tencent.";    // @0x22902c0

/* 0x8f4f50 起的动态私有调用 */
static NSString * const kWCRLSBundleProxyClass = @"LSBundleProxy";                    // @0x20447ac
static NSString * const kWCRLSBundleProxySel   = @"bundleProxyForCurrentProcess";     // @0x20447ba
static NSString * const kWCRGroupContainerURLs = @"groupContainerURLs";               // @0x20447d7

/* 0x8f3698 中被 swizzle 的类 / 方法名（全部用字符串，避免链接期依赖） */
static NSString * const kWCRCKEntitlementsClass   = @"CKEntitlements";                 // @0x20447ea
static NSString * const kWCRCKEntitlementsInit    = @"initWithEntitlementsDict:";      // @0x20447f9
static NSString * const kWCRCKContainerClass      = @"CKContainer";                    // @0x2044813
static NSString * const kWCRCKInitWithID          = @"_initWithContainerIdentifier:";  // @0x204481f
static NSString * const kWCRCKSetupWithID         = @"_setupWithContainerID:options:"; // @0x204483d
static NSString * const kWCRUserDefaultsSuiteInit = @"_initWithSuiteName:container:";  // @0x204485c
static NSString * const kWCRAppExtDataUtilClass   = @"WCAppExtensionDataUtil";         // @0x204487a
static NSString * const kWCRExtDataUtilClass      = @"WCExtDataUtil";                  // @0x204489c
static NSString * const kWCRAppGroupIDSel         = @"appGroupID";                     // @0x2044891
static NSString * const kWCRShareMainVCClass      = @"MSEShareMainViewController";     // @0x20448aa
static NSString * const kWCRDoAuthenticateCheck   = @"doAuthenticateCheck";            // @0x20448c5
static NSString * const kWCRAuthDidFinish         = @"onCheckAuthenticateDidFinish:";  // @0x20448d9

static NSString * const kWCRProtobufLite3 = @"ProtobufLite3";  // @0x205b4b6
static NSString * const kWCRProtobufLite  = @"ProtobufLite";   // @0x205b4c4
/* 0x147f6a4 在宿主 Mach-O 的 LC_LOAD_DYLIB* 名字里搜的标记 */
static NSString * const kWCRInjectToken   = @"WCRefine";       // @0x202a8b8
/* 0x14806a8 / 0x14806b4：宿主 framework 的候选目录（后者为 macOS 布局兼容） */
static NSString * const kWCRFrameworksDir        = @"Frameworks";           // @0x22b3620
static NSString * const kWCRContentsFrameworksDir= @"Contents/Frameworks";  // @0x22bf840
static NSString * const kWCRFrameworkExt         = @"framework";            // @0x22bf860
static NSString * const kWCRInfoPlistName        = @"Info.plist";           // @0x22b3740
static NSString * const kWCRBundleExecutableKey  = @"CFBundleExecutable";   // @0x22bf7a0

/* 配置键（WCRefineConfig，classref @0x238f810） */
static NSString * const kWCRCfgGroupID  = @"sideloadShareFixAppGroupId";

#pragma mark - 前向声明

static NSString *WCRPreferredHostBinaryPath(void);
static NSArray<NSString *> *WCRApplicationGroupIDs(void);
static NSString *WCRMarkerGroupID(void);
static BOOL WCRWriteGroupMarker(NSString *groupID);
static NSString *WCRResolvedGroupID(void);
static NSString *WCRCurrentGroupID(void);
static BOOL WCRFixActive(void);
static BOOL WCRShouldRemapGroup(NSString *groupID);
static NSURL *WCRRemappedContainerURL(void);
static NSString *WCRRemapGroupID(NSString *groupID);
static NSArray<NSString *> *WCRCachedAvailableGroups(void);
static void WCREnsureDirectory(NSString *path);
static BOOL WCRPreferredHostLinked(void);
static BOOL WCRShouldInstall(void);
static void WCRSelectGroup(NSString *groupID);          /* 设置页选组：写 picked + marker + 清缓存 */

#pragma mark - 运行时状态（一一对应 WCR 的 __DATA,__bss 槽位）

static BOOL  gSwizzledFileManager = NO;   /* bss 0x2526a68 —— 0x8f3630 的记忆位 */
static NSURL *(*gOrigContainerURL)(id, SEL, NSString *) = NULL; /* bss 0x2526a70 */
/* WCR 的替换 IMP 自己就用 gOrigContainerURL 递归调用原始实现，所以必须在
 * 任何 swizzle 发生之前由 WCRSwizzle 写入 —— 这正是 WCR 在 0x8f367c 传
 * x3 = &0x2526a70 的原因。 */

static id   (*gOrigCKEntitlementsInit)(id, SEL, NSDictionary *)          = NULL; /* 0x2526a78 */
static id   (*gOrigCKInitWithID)(id, SEL, NSString *)                    = NULL; /* 0x2526a80 */
static id   (*gOrigCKSetupWithID)(id, SEL, NSString *, id)               = NULL; /* 0x2526a88 */
static id   (*gOrigUserDefaultsSuiteInit)(id, SEL, NSString *, id)       = NULL; /* 0x2526a90 */
static id   (*gOrigAppExtDataUtilGroupID)(id, SEL)                       = NULL; /* 0x2526a98 */
static id   (*gOrigExtDataUtilGroupID)(id, SEL)                          = NULL; /* 0x2526aa0 */
static id   (*gOrigDoAuthenticateCheck)(id, SEL)                         = NULL; /* 0x2526aa8 */
static void (*gOrigAuthDidFinish)(id, SEL, id)                           = NULL; /* 0x2526ab0 */

static NSString *gCachedRemappedGroup  = nil; /* bss 0x2526a58 —— 0x8f3f40 的结果缓存 */
static NSArray  *gCachedAvailableGroups= nil; /* bss 0x2526a60 —— 0x8f54e4 的结果缓存 */
static NSURL    *gCachedContainerURL   = nil; /* bss 0x2526a48 */
static NSString *gCachedContainerGroup = nil; /* bss 0x2526a50 */

#pragma mark - 手写 swizzle helper（1:1 对应 0x8f393c）

/*
 * BOOL WCRSwizzle(Class cls, SEL sel, IMP newIMP, IMP *origIMP)
 *
 * 0x8f3948~0x8f3988 : cls / sel / newIMP / origIMP 任一为 NULL 直接返回 NO
 * 0x8f39a8          : class_copyMethodList(cls, &count)
 * 0x8f39dc          : 逐个 method_getName(list[i]) == sel ?
 *     命中 → 0x8f3a3c method_setImplementation(found, newIMP)，把旧 IMP 存进 *origIMP
 *     未命中 → 0x8f3a64 class_getInstanceMethod(cls, sel)
 *              为 NULL 返回 NO
 *              否则 *origIMP = method_getImplementation(m)（继承来的实现）
 *              0x8f3ad4 class_addMethod(cls, sel, newIMP, method_getTypeEncoding(m))
 */
static BOOL WCRSwizzle(Class cls, SEL sel, IMP newIMP, IMP *origIMP) {
    if (!cls || !sel || !newIMP || !origIMP) return NO;

    unsigned int count = 0;
    Method *list = class_copyMethodList(cls, &count);
    Method found = NULL;
    for (unsigned int i = 0; i < count; i++) {
        if (method_getName(list[i]) == sel) { found = list[i]; break; }
    }
    if (list) free(list);

    if (found) {
        IMP old = method_setImplementation(found, newIMP);
        *origIMP = old;
        return YES;
    }

    Method m = class_getInstanceMethod(cls, sel);   // 可能是父类实现
    if (!m) return NO;

    *origIMP = method_getImplementation(m);
    return class_addMethod(cls, sel, newIMP, method_getTypeEncoding(m));
}

#pragma mark - 进程判定（0x1482108 / 0x148230c / 0x14820c8）

static NSString *WCRExtensionPointIdentifier(void) {
    NSDictionary *ext = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSExtension"];
    id v = ext[@"NSExtensionPointIdentifier"];
    return [v isKindOfClass:[NSString class]] ? (NSString *)v : nil;
}

static BOOL WCRIsShareExtensionProcess(void) {            /* 0x1482108 */
    return [WCRExtensionPointIdentifier() isEqualToString:kWCRExtShareService];
}

static BOOL WCRIsNotificationServiceProcess(void) {       /* 0x148230c */
    return [WCRExtensionPointIdentifier() isEqualToString:kWCRExtNotificationService];
}

/* 0x14820c8 = IsShareExtensionProcess() || IsNotificationServiceProcess()
 * 注意：Notification Service Extension 正是"消息详情头像显示"那条线 ——
 * 头像由 NSExtension 生成 UNNotificationAttachment，图片源在 App Group 容器里，
 * 容器拿不到 → 没头像。修复容器 → 头像回来。 */
static BOOL WCRIsGroupRemapExtensionProcess(void) {       /* 0x14820c8 */
    return WCRIsShareExtensionProcess() || WCRIsNotificationServiceProcess();
}

#pragma mark - entitlement 读取（0x147d4e8 四级回退）

static NSArray<NSString *> *WCRGroupsFromEntitlements(NSDictionary *ent) {
    if (![ent isKindOfClass:[NSDictionary class]]) return nil;
    id v = ent[kWCREntitlementAppGroups];
    if (![v isKindOfClass:[NSArray class]]) return nil;
    NSMutableArray *out = [NSMutableArray array];
    for (id g in (NSArray *)v) {
        if ([g isKindOfClass:[NSString class]] && [(NSString *)g length] > 0) [out addObject:g];
    }
    return out.count ? out : nil;
}

/* SecTask 系列在 iOS SDK 的公开头文件里没有声明，但 Security.framework 里确实有符号。
 * 这里用 dlsym 在运行期解析，符号不存在就跳过该级回退 —— 既不依赖私有头，也不会链接失败。 */
typedef struct __WCRSecTask *WCRSecTaskRef;
typedef WCRSecTaskRef (*WCRSecTaskCreateFromSelfFunc)(CFAllocatorRef);
typedef CFTypeRef     (*WCRSecTaskCopyValueFunc)(WCRSecTaskRef, CFStringRef, CFErrorRef *);

static CFTypeRef WCRCopyEntitlementViaSecTask(NSString *key) {
    static void *sSecTaskCreate = NULL, *sSecTaskCopy = NULL;
    static BOOL sResolved = NO;
    if (!sResolved) {
        sResolved = YES;
        sSecTaskCreate = dlsym(RTLD_DEFAULT, "SecTaskCreateFromSelf");
        sSecTaskCopy   = dlsym(RTLD_DEFAULT, "SecTaskCopyValueForEntitlement");
    }
    if (!sSecTaskCreate || !sSecTaskCopy) return NULL;

    WCRSecTaskRef task = ((WCRSecTaskCreateFromSelfFunc)sSecTaskCreate)(NULL);
    if (!task) return NULL;
    CFErrorRef err = NULL;
    CFTypeRef v = ((WCRSecTaskCopyValueFunc)sSecTaskCopy)(
                      task, (__bridge CFStringRef)key, &err);
    CFRelease(task);
    if (err) CFRelease(err);
    return v;
}

/* 1) 0x147d944 内部缓存  2) 0x147bd34+0x147c2d0 embedded.mobileprovision
 *    3) 0x147c448 可执行文件  4) 0x147d254 CodeSignature
 * 每一级都用 @selector(count) 判空后再 objectForKeyedSubscript:。
 * iOS SDK 不导出 SecStaticCode / kSecCSDefaultFlags，级别 3/4 改用
 * 直接读 Mach-O __TEXT,__entitlements 段的方式兜底。 */
static NSArray<NSString *> *WCRDeclaredAppGroupIDs(void) {
    /* 级别 1：SecTaskCopyValueForEntitlement（进程真实生效的 entitlement） */
    CFTypeRef ent = WCRCopyEntitlementViaSecTask(kWCREntitlementAppGroups);
    if (ent) {
        NSArray *a = CFBridgingRelease(ent);
        NSArray *g = WCRGroupsFromEntitlements(@{ kWCREntitlementAppGroups : (a ?: @[]) });
        if (g.count) return g;
    }

    /* 级别 2：embedded.mobileprovision（自签场景真正的来源） */
    NSURL *profileURL = [[NSBundle mainBundle] URLForResource:@"embedded"
                                                withExtension:@"mobileprovision"];
    if (!profileURL) {
        NSString *p = [[NSBundle mainBundle] pathForResource:@"embedded"
                                                      ofType:@"mobileprovision"];
        if (p) profileURL = [NSURL fileURLWithPath:p];
    }
    if (profileURL) {
        NSData *data = [NSData dataWithContentsOfURL:profileURL];
        if (data.length) {
            NSRange s = [data rangeOfData:[NSData dataWithBytes:"<?xml" length:5]
                                  options:0 range:NSMakeRange(0, data.length)];
            NSRange e = [data rangeOfData:[NSData dataWithBytes:"</plist>" length:8]
                                  options:0 range:NSMakeRange(0, data.length)];
            if (s.location != NSNotFound && e.location != NSNotFound &&
                e.location > s.location) {
                NSRange r = NSMakeRange(s.location,
                                        NSMaxRange(e) - s.location);
                NSData *xml = [data subdataWithRange:r];
                NSDictionary *plist =
                    [NSPropertyListSerialization propertyListWithData:xml
                                                              options:0
                                                               format:NULL
                                                                error:NULL];
                NSArray *a = WCRGroupsFromEntitlements(
                    ((NSDictionary *)plist)[@"Entitlements"]);
                if (a.count) return a;
            }
        }
    }

    /* 级别 3/4：可执行文件自身的 entitlement。
     * 现代签名把 entitlements 放在 __TEXT,__entitlements（<plist>...</plist>），
     * 老签名放在 __TEXT,__info_plist / CodeResources，这里只扫 __TEXT,__entitlements。 */
    NSURL *exeURL = [[NSBundle mainBundle] executableURL];
    if (exeURL) {
        NSData *bin = [NSData dataWithContentsOfURL:exeURL];
        if (bin.length) {
            NSData *head = [NSData dataWithBytes:"<?xml" length:5];
            NSData *tail = [NSData dataWithBytes:"</plist>" length:8];
            NSRange s = [bin rangeOfData:head options:0 range:NSMakeRange(0, bin.length)];
            if (s.location != NSNotFound) {
                NSRange search = NSMakeRange(NSMaxRange(s), bin.length - NSMaxRange(s));
                NSRange e = [bin rangeOfData:tail options:0 range:search];
                if (e.location != NSNotFound) {
                    NSData *xml = [bin subdataWithRange:
                                   NSMakeRange(s.location, NSMaxRange(e) - s.location)];
                    NSDictionary *plist =
                        [NSPropertyListSerialization propertyListWithData:xml
                                                                  options:0
                                                                   format:NULL
                                                                    error:NULL];
                    NSArray *a = WCRGroupsFromEntitlements(plist);
                    if (a.count) return a;
                }
            }
        }
    }
    return @[];
}

/* 0x147e154 */
static NSArray<NSString *> *WCRApplicationGroupIDs(void) {
    return WCRDeclaredAppGroupIDs() ?: @[];
}

#pragma mark - marker 读写（0x148190c / 0x14815d8 / 0x14810f8）

static NSArray<NSURL *> *WCRMarkerFileURLs(void) {
    NSMutableArray *urls = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *gid in WCRApplicationGroupIDs()) {
        NSURL *u = nil;
        if (gOrigContainerURL) {
            u = gOrigContainerURL(fm,
                    @selector(containerURLForSecurityApplicationGroupIdentifier:), gid);
        } else {
            u = [fm containerURLForSecurityApplicationGroupIdentifier:gid];
        }
        if (![u isKindOfClass:[NSURL class]]) continue;
        NSURL *dir = [u URLByAppendingPathComponent:kWCRPrefsSubPath isDirectory:YES];
        [urls addObject:[dir URLByAppendingPathComponent:kWCRMarkerFileName]];
    }
    return urls;
}

static NSArray<NSString *> *WCRMarkerGroupIDsInternal(void) {
    NSMutableArray *out = [NSMutableArray array];
    NSArray<NSString *> *available = WCRApplicationGroupIDs();
    for (NSURL *mu in WCRMarkerFileURLs()) {
        NSString *content = [NSString stringWithContentsOfURL:mu
                                                     encoding:NSUTF8StringEncoding
                                                        error:NULL];
        NSString *gid = [content stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (gid.length == 0) continue;
        if (![available containsObject:gid]) continue;
        if (![out containsObject:gid]) [out addObject:gid];
    }
    return out;
}

/* 0x148190c */
static NSString *WCRMarkerGroupID(void) {
    return WCRMarkerGroupIDsInternal().firstObject;
}

/* 0x14815d8 —— 主 App 把选定组写进**所有**可用容器（多开防串号：不同实例选不同组） */
static BOOL WCRWriteGroupMarker(NSString *groupID) {
    if (groupID.length == 0) return NO;
    BOOL ok = NO;
    for (NSURL *mu in WCRMarkerFileURLs()) {
        WCREnsureDirectory([mu URLByDeletingLastPathComponent].path);
        if ([groupID writeToURL:mu atomically:YES
                       encoding:NSUTF8StringEncoding error:NULL]) ok = YES;
    }
    return ok;
}

#pragma mark - 配置

static Class WCRConfigClass(void) {
    Class c = NSClassFromString(@"WCRefineConfig");
    return c;
}

static id WCRConfig(void) {
    Class c = WCRConfigClass();
    if (!c) return nil;
    if (![c respondsToSelector:@selector(shared)]) return nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [c performSelector:@selector(shared)];
#pragma clang diagnostic pop
}

/* 纯本地版：功能默认生效，无开关、无设置界面。
 * WCR 原版此处读 WCRefineConfig.sideloadShareFixEnabled（@0x8f4c30），
 * 独立插件版去掉该开关，主 App 分支统一走 WCRShouldInstall 的宿主检查后默认放行。 */
static NSString *WCRPickedGroupID(void) {
    id cfg = WCRConfig();
    id v = [cfg respondsToSelector:NSSelectorFromString(kWCRCfgGroupID)]
         ? [cfg valueForKey:kWCRCfgGroupID] : nil;
    if ([v isKindOfClass:[NSString class]]) return (NSString *)v;
    return [[NSUserDefaults standardUserDefaults] stringForKey:kWCRCfgGroupID];
}

static void WCRSetPickedGroupID(NSString *gid) {
    id cfg = WCRConfig();
    if ([cfg respondsToSelector:NSSelectorFromString(@"setSideloadShareFixAppGroupId:")]) {
        [cfg setValue:(gid ?: @"") forKey:kWCRCfgGroupID];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:(gid ?: @"")
                                                  forKey:kWCRCfgGroupID];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

#pragma mark - ProtobufLite 链接检查（0x14804f8 / 0x148056c / 0x147f6a4 / 0x147ccf4 / 0x147cff4）

/*
 * 「需注入 ProtobufLite3（没有则 ProtobufLite）」这句 UI 文案的真正含义，
 * 由下面四个函数闭环给出，全部来自反汇编，不是推测：
 *
 *   0x148056c  在 <bundlePath>/{Frameworks,Contents/Frameworks}/ 下依次找
 *              ProtobufLite3.framework (@0x205b4b6) → ProtobufLite.framework (@0x205b4c4)
 *              读其 Info.plist 的 CFBundleExecutable 得到可执行文件名，
 *              拼出 <fw>/<exe> 并 isReadableFileAtPath:
 *   0x147f6a4  fopen(path,"rb") → 解析 Mach-O → 遍历 load commands，
 *              只认 LC_LOAD_DYLIB(0x0c) / LC_LOAD_WEAK_DYLIB(0x80000018) /
 *              LC_REEXPORT_DYLIB(0x8000001f) / LC_LOAD_UPWARD_DYLIB(0x80000023)
 *              取其中的 dylib 名字，strnstr(name, "WCRefine")  ← @0x202a8b8
 *   0x147ccf4  定位 fat 里的 arm64 slice（CPU_TYPE_ARM64），thin 直接返回 0
 *   0x147cff4  BOOL ReadAt(FILE *, uint64_t off, void *buf, size_t len)
 *
 * 换句话说：这不是"检查 ProtobufLite 有没有被加载"，而是
 * **检查磁盘上那份 ProtobufLite 二进制有没有被 Icsign 注入 WCRefine**
 * （注入后其 Mach-O 会多出一条指向 WCRefine.dylib 的 LC_LOAD_DYLIB）。
 *
 * 实测微信 8.0.78（Frameworks.zip）：只有 ProtobufLite.framework，没有
 * ProtobufLite3.framework；ProtobufLite 的 LC_LOAD_DYLIB 列表里没有 WCRefine，
 * 所以原始包下本函数返回 NO —— 正是设置页提示"需注入"的原因。
 */

/* 0x147d0b4 —— 大端读 32 位 */
static uint32_t WCRBigEndian32(const void *p) {
    const uint8_t *b = (const uint8_t *)p;
    return ((uint32_t)b[0] << 24) | ((uint32_t)b[1] << 16) |
           ((uint32_t)b[2] << 8)  |  (uint32_t)b[3];
}

/* 0x147cff4 */
static BOOL WCRReadAt(FILE *f, uint64_t off, void *buf, size_t len) {
    if (!f || !buf) return NO;
    if (len == 0) return YES;
    if (fseeko(f, (off_t)off, SEEK_SET) != 0) return NO;
    return fread(buf, 1, len, f) == len;
}

/* WCR 用的是 strnstr（桩 0x1f15a44）；这里自带一份，避免 SDK 声明差异 */
static char *WCRStrNStr(const char *haystack, const char *needle, size_t len) {
    if (!haystack || !needle) return NULL;
    size_t n = strlen(needle);
    if (n == 0) return (char *)haystack;
    if (n > len) return NULL;
    for (size_t i = 0; i + n <= len; i++) {
        if (haystack[i] == needle[0] && strncmp(haystack + i, needle, n) == 0) {
            return (char *)(haystack + i);
        }
    }
    return NULL;
}

/* 0x147ccf4 —— 返回 arm64 slice 的文件偏移；thin 返回 0；失败返回 -1 */
static int64_t WCRFindARM64Slice(FILE *f, uint32_t *magicOut) {
    uint8_t head[8];
    if (!WCRReadAt(f, 0, head, 8)) return -1;                  /* 0x147cd28 */
    uint32_t m = 0;
    memcpy(&m, head, 4);
    if (m == 0xfeedfacf /* MH_MAGIC_64 */) {                    /* 0x147cd58 */
        if (magicOut) *magicOut = m;                            /* 0x147cd78 */
        return 0;                                               /* 0x147cd80 */
    }

    uint32_t nfat = WCRBigEndian32(head + 4);                   /* 0x147cdd8 */
    if (nfat == 0 || nfat > 0x10) return -1;                    /* 0x147cde4 / 0x147cdf0 */
    BOOL isFat64 = (m == 0xcafebabf);                           /* 0x147ce14 */
    size_t archSize = isFat64 ? 0x20 : 0x14;                    /* 0x147ce24~0x147ce38 */
    uint64_t off = 8;                                           /* 0x147ce40 */

    for (uint32_t i = 0; i < nfat; i++) {                       /* 0x147ce4c */
        if (archSize > 0x20) return -1;                         /* 0x147ce64 */
        uint8_t arch[0x20];
        if (!WCRReadAt(f, off, arch, archSize)) return -1;       /* 0x147ce80 */

        uint32_t cputype = WCRBigEndian32(arch);                /* 0x147ce9c */
        uint64_t sliceOff;
        if (isFat64) {                                          /* 0x147cea4 */
            uint64_t lo = WCRBigEndian32(arch + 0x8);
            uint64_t hi = WCRBigEndian32(arch + 0xc);
            sliceOff = (hi << 32) | lo;                         /* 0x147cedc */
        } else {                                                /* 0x147ceec */
            sliceOff = WCRBigEndian32(arch + 0x8);
        }

        if ((cputype & 0x01000000) != 0 &&                      /* CPU_ARCH_ABI64  0x147cf0c */
            (cputype & 0xfeffffff) == 0xc) {                    /* CPU_TYPE_ARM64  0x147cf1c */
            uint32_t sliceMagic = 0;
            if (!WCRReadAt(f, sliceOff, &sliceMagic, 4)) return -1;   /* 0x147cf3c */
            if (sliceMagic == 0xfeedfacf) {                     /* 0x147cf54 */
                if (magicOut) *magicOut = sliceMagic;           /* 0x147cf74 */
                return (int64_t)sliceOff;                       /* 0x147cf7c */
            }
        }
        off += archSize;                                        /* 0x147cf8c~0x147cf98 */
    }
    return -1;                                                  /* 0x147cfb0 */
}

/* 0x147f6a4 —— 该二进制的 dylib 依赖里是否含 "WCRefine"（@0x202a8b8） */
static BOOL WCRMachOLinksWCRefine(NSString *path) {
    if (![path isKindOfClass:[NSString class]]) return NO;
    if (path.length == 0) return NO;                            /* 0x147f6ec */
    FILE *f = fopen(path.fileSystemRepresentation, "rb");       /* 0x147f724 / 0x147f73c */
    if (!f) return NO;                                          /* 0x147f748 */

    BOOL found = NO;
    uint32_t magic = 0;
    int64_t base = WCRFindARM64Slice(f, &magic);                /* 0x147f778 */
    if (base == -1) { fclose(f); return NO; }                   /* 0x147f784 */
    if (magic != 0xfeedfacf) { fclose(f); return NO; }          /* 0x147f79c */

    uint8_t hdr[0x20];
    if (!WCRReadAt(f, (uint64_t)base, hdr, 0x20)) { fclose(f); return NO; }  /* 0x147f7dc */

    uint32_t ncmds = 0, sizeofcmds = 0;
    memcpy(&ncmds,      hdr + 0x10, 4);                         /* sp+0x60 */
    memcpy(&sizeofcmds, hdr + 0x14, 4);                         /* sp+0x64 */
    if (ncmds == 0 || ncmds > 0x200) { fclose(f); return NO; }              /* 0x147f81c */
    if (sizeofcmds == 0 || sizeofcmds > 0x1000000) { fclose(f); return NO; } /* 0x147f838 */

    uint64_t off = (uint64_t)base + 0x20;                       /* 0x147f868~0x147f86c */
    for (uint32_t i = 0; i < ncmds && !found; i++) {            /* 0x147f880 */
        uint32_t pair[2] = {0, 0};
        if (!WCRReadAt(f, off, pair, 8)) break;                 /* 0x147f8cc */
        uint32_t cmd = pair[0], cmdsize = pair[1];
        if (cmdsize < 8 || cmdsize > sizeofcmds) break;         /* 0x147f8f4 / 0x147f904 */

        if (cmd == 0x0c        ||    /* LC_LOAD_DYLIB         0x147f918 */
            cmd == 0x80000018  ||    /* LC_LOAD_WEAK_DYLIB    0x147f92c */
            cmd == 0x8000001f  ||    /* LC_REEXPORT_DYLIB     0x147f944 */
            cmd == 0x80000023) {     /* LC_LOAD_UPWARD_DYLIB  0x147f95c */
            uint32_t nameoff = 0;
            if (cmdsize >= 0xc &&                               /* 0x147f970 */
                WCRReadAt(f, off + 8, &nameoff, 4) &&           /* 0x147f990 */
                nameoff >= 8 && nameoff < cmdsize) {            /* 0x147f9a0 / 0x147f9b4 */
                size_t len = cmdsize - nameoff;                 /* 0x147f9c8 */
                if (len > 0x200) len = 0x200;                   /* 0x147f9d4 */
                char name[0x201];
                memset(name, 0, sizeof(name));                  /* 0x147f9f8 (bzero) */
                if (WCRReadAt(f, off + nameoff, name, len) &&   /* 0x147fa14 */
                    WCRStrNStr(name, kWCRInjectToken.UTF8String, len)) {  /* 0x147fa30 */
                    found = YES;                                /* 0x147fa40 */
                }
            }
        }
        off += cmdsize;                                         /* 0x147fa54~0x147fa64 */
    }
    fclose(f);                                                  /* 0x147fa80 */
    return found;
}

/* 0x148056c —— 找"首选宿主"二进制：
 *   名字 ProtobufLite3 → ProtobufLite，目录 Frameworks → Contents/Frameworks，
 *   可执行名取 Info.plist["CFBundleExecutable"]，取不到就用 name 本身。 */
static NSString *WCRPreferredHostBinaryPath(void) {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];   /* 0x1480598 / 0x14805b8 */
    if (bundlePath.length == 0) return nil;                     /* 0x1480600 */
    NSFileManager *fm = [NSFileManager defaultManager];          /* 0x1480624 */

    NSString *fallback = nil;                                    /* sp+0x220 */
    NSArray *names = @[ kWCRProtobufLite3, kWCRProtobufLite ];   /* 0x1480648 / 0x1480654 */
    NSArray *dirs  = @[ kWCRFrameworksDir, kWCRContentsFrameworksDir ]; /* 0x14806a8 / 0x14806b4 */

    for (NSString *name in names) {
        for (NSString *dir in dirs) {
            NSString *fw =
                [[bundlePath stringByAppendingPathComponent:dir] /* 0x1480868 */
                    stringByAppendingPathComponent:
                        [name stringByAppendingPathExtension:kWCRFrameworkExt]]; /* 0x148088c */

            NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
                [fw stringByAppendingPathComponent:kWCRInfoPlistName]];     /* 0x1480924 / 0x1480944 */
            NSString *exe = nil;
            if ([info isKindOfClass:[NSDictionary class]]) {                 /* 0x14809e0 */
                id v = info[kWCRBundleExecutableKey];                        /* 0x1480a00 */
                if ([v isKindOfClass:[NSString class]] &&                    /* 0x1480a60 */
                    [(NSString *)v length] > 0) {                            /* 0x1480abc */
                    exe = (NSString *)v;
                }
            }

            NSString *bin = [fw stringByAppendingPathComponent:(exe ?: name)]; /* 0x1480ba4 */
            if ([fm isReadableFileAtPath:bin]) {                             /* 0x1480bcc */
                if (WCRMachOLinksWCRefine(bin)) return bin;                  /* 0x1480be8 */
                if (!fallback) fallback = bin;                               /* 0x1480c28 */
            }

            /* 变体二：<bundlePath>/<dir>/<name>（不带 .framework） */
            NSString *bin2 = [[bundlePath stringByAppendingPathComponent:dir] /* 0x1480c4c */
                                stringByAppendingPathComponent:name];        /* 0x1480c70 */
            if ([fm isReadableFileAtPath:bin2]) {                            /* 0x1480cac */
                if (WCRMachOLinksWCRefine(bin2)) return bin2;
                if (!fallback) fallback = bin2;
            }
        }
    }
    return fallback;
}

/* 0x14804f8 —— memo：bss 0x253a6f0（已算过） / 0x253a6f1（结果） */
static BOOL WCRPreferredHostLinked(void) {
    static BOOL sComputed = NO;                                  /* bss 0x253a6f0 */
    static BOOL sLinked   = NO;                                  /* bss 0x253a6f1 */
    if (!sComputed) {                                            /* 0x148050c */
        sComputed = YES;                                         /* 0x148051c */
        NSString *p = WCRPreferredHostBinaryPath();              /* 0x1480520 */
        BOOL r = WCRMachOLinksWCRefine(p);                       /* 0x1480530 */
        sLinked = r;                                             /* 0x1480540 */
    }
    return sLinked & 1;                                          /* 0x1480558~0x148055c */
}

#pragma mark - 组解析

/* 0x1481ec0 —— 只在**主 App** 进程里被调用 */
static NSString *WCRResolvedGroupID(void) {
    if (WCRIsGroupRemapExtensionProcess()) return WCRMarkerGroupID();

    NSArray<NSString *> *available = WCRApplicationGroupIDs();
    if (available.count == 0) return nil;

    NSString *picked = WCRPickedGroupID();
    if (picked.length && [available containsObject:picked]) return picked;

    NSString *marker = WCRMarkerGroupID();
    if (marker.length && [available containsObject:marker]) return marker;

    return nil;
}

/* 0x8f5490 —— 主 App 与扩展的统一入口 */
static NSString *WCRCurrentGroupID(void) {
    if (WCRIsGroupRemapExtensionProcess()) {
        return WCRRemapGroupID(nil);      /* 0x8f54a8: mov x0,#0 ; bl 0x8f3f40 */
    }
    return WCRResolvedGroupID();          /* 0x8f54c0: bl 0x1481ec0 */
}

/* 0x8f4b9c —— 所有 hook 的统一开关 */
static BOOL WCRFixActive(void) {
    if (WCRIsGroupRemapExtensionProcess()) {
        return WCRCurrentGroupID().length > 0;   /* 扩展：有解析出组就生效 */
    }
    return YES;                                  /* 主 App：无开关，默认生效 */
}

/* 0x8f54e4 —— 带缓存的可用组列表 */
static NSArray<NSString *> *WCRCachedAvailableGroups(void) {
    if (!gCachedAvailableGroups) {
        gCachedAvailableGroups = [WCRApplicationGroupIDs() copy];
    }
    return gCachedAvailableGroups ?: @[];
}

/* 0x8f4cd0 —— 这个 groupID 该不该被重映射 */
static BOOL WCRShouldRemapGroup(NSString *groupID) {
    if (![groupID isKindOfClass:[NSString class]]) return NO;
    if (groupID.length == 0) return NO;                                  /* 0x8f4d18 */
    if ([WCRCachedAvailableGroups() containsObject:groupID]) return YES;  /* 0x8f4d9c */
    return [groupID hasPrefix:kWCRTencentPrefix];                        /* 0x8f4dd8 */
}

#pragma mark - 目录保障（0x8f6af4）

static void WCREnsureDirectory(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) return;
    [fm createDirectoryAtPath:path
        withIntermediateDirectories:YES
                         attributes:nil
                              error:NULL];
}

#pragma mark - 核心：容器 URL 重映射（0x8f4e50）

/* 首选 LSBundleProxy.groupContainerURLs[gid] —— 绕过 entitlement 校验 */
static NSURL *WCRContainerURLViaLSBundleProxy(NSString *gid) {
    Class proxyClass = NSClassFromString(kWCRLSBundleProxyClass);   /* 0x1f156fc */
    if (!proxyClass) return nil;
    SEL selProxy = NSSelectorFromString(kWCRLSBundleProxySel);      /* 0x1f159a8 */
    if (![proxyClass respondsToSelector:selProxy]) return nil;

    id proxy = ((id (*)(id, SEL))objc_msgSend)((id)proxyClass, selProxy);
    if (!proxy) return nil;

    SEL selURLs = NSSelectorFromString(kWCRGroupContainerURLs);
    if (![proxy respondsToSelector:selURLs]) return nil;

    id urls = ((id (*)(id, SEL))objc_msgSend)(proxy, selURLs);
    if (![urls isKindOfClass:[NSDictionary class]]) return nil;     /* 0x238f828 = NSDictionary */

    id u = [urls objectForKeyedSubscript:gid];
    return [u isKindOfClass:[NSURL class]] ? (NSURL *)u : nil;
}

static NSURL *WCRUnmappedContainerURL(NSString *gid) {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (gOrigContainerURL) {
        NSURL *u = gOrigContainerURL(fm,
            @selector(containerURLForSecurityApplicationGroupIdentifier:), gid);
        return [u isKindOfClass:[NSURL class]] ? u : nil;
    }
    NSURL *u = [fm containerURLForSecurityApplicationGroupIdentifier:gid];
    return [u isKindOfClass:[NSURL class]] ? u : nil;
}

/* 0x8f4e50 —— 带 memo（bss 0x2526a48 / 0x2526a50） */
static NSURL *WCRRemappedContainerURL(void) {
    NSString *gid = WCRCurrentGroupID();
    if (gid.length == 0) {                       /* 0x8f4e9c */
        gCachedContainerURL = nil;
        gCachedContainerGroup = nil;
        return nil;
    }
    if (gCachedContainerURL &&
        [gCachedContainerGroup isEqualToString:gid]) {   /* 0x8f4ef0 */
        return gCachedContainerURL;
    }

    NSURL *url = WCRContainerURLViaLSBundleProxy(gid);
    if (![url isKindOfClass:[NSURL class]]) {            /* 0x8f51ac */
        if (gOrigContainerURL) {                         /* 0x8f51b8 */
            url = WCRUnmappedContainerURL(gid);
        }
    }
    if (![url isKindOfClass:[NSURL class]]) {            /* 0x8f52d0 */
        return nil;
    }

    gCachedContainerGroup = [gid copy];                  /* 0x8f530c */
    gCachedContainerURL = url;                           /* 0x8f5328 */
    return url;
}

#pragma mark - 核心：扩展进程反查主 App 选定的组（0x8f3f40）

/*
 * 0x8f3f40 的完整逻辑：
 *   1. 非 group-remap 扩展进程              → nil
 *   2. bss 0x2526a58 缓存非空              → 直接返回
 *   3. MarkerGroupID() 非空                 → copy 进缓存后返回
 *   4. 原 IMP 为空                          → nil
 *   5. 组装候选：先放传入的 groupID，再追加所有可用组（去重、非空）
 *   6. 逐个候选：原 IMP 取容器 → <container>/Library/Preferences/<marker>
 *        → fileExistsAtPath → stringWithContentsOfURL(NSUTF8)
 *        → 去空白 → 必须在候选列表里 → 命中即 copy 进缓存并返回
 */
static NSString *WCRRemapGroupID(NSString *groupID) {
    if (!WCRIsGroupRemapExtensionProcess()) return nil;           /* 0x8f3f80 */
    if (gCachedRemappedGroup.length > 0) return gCachedRemappedGroup; /* 0x8f3fd0 */

    NSString *marker = WCRMarkerGroupID();                         /* 0x8f4008 */
    if (marker.length > 0) {                                       /* 0x8f404c */
        gCachedRemappedGroup = [marker copy];                      /* 0x8f4080 */
        return gCachedRemappedGroup;
    }
    if (!gOrigContainerURL) return nil;                            /* 0x8f40d0 */

    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    if (groupID.length > 0) [candidates addObject:groupID];        /* 0x8f4154 */
    for (NSString *g in WCRApplicationGroupIDs()) {                /* 0x8f4188 */
        if (g.length > 0 && ![candidates containsObject:g]) {
            [candidates addObject:g];                              /* 0x8f42cc */
        }
    }

    NSFileManager *fm = [NSFileManager defaultManager];            /* 0x8f4394 */
    for (NSString *g in candidates) {
        NSURL *u = gOrigContainerURL(fm,
            @selector(containerURLForSecurityApplicationGroupIdentifier:), g);
        if (![u isKindOfClass:[NSURL class]]) continue;            /* 0x8f4520 */

        NSURL *dir = [u URLByAppendingPathComponent:kWCRPrefsSubPath isDirectory:YES];
        NSURL *mu = [dir URLByAppendingPathComponent:kWCRMarkerFileName];
        NSString *mp = mu.path;
        if (mp.length == 0) continue;                              /* 0x8f4654 */
        if (![fm fileExistsAtPath:mp]) continue;                   /* 0x8f4714 */

        NSString *content = [NSString stringWithContentsOfURL:mu
                                                     encoding:NSUTF8StringEncoding
                                                        error:NULL];
        NSString *trimmed = [content stringByTrimmingCharactersInSet:
                                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) continue;                          /* 0x8f48b0 */
        if (![candidates containsObject:trimmed]) continue;         /* 0x8f48e0 */

        gCachedRemappedGroup = [trimmed copy];                      /* 0x8f4910 */
        return gCachedRemappedGroup;
    }
    return nil;                                                     /* 0x8f4a70 */
}

#pragma mark - 探针日志（0x8f53b8，WCR 内已裁成空实现）

static void WCRProbe(NSString *tag, id a, id b, id c) {
    /* WCR 里这里原来会往 com.qimiao.WCRefine.sideload-share-fix.log 追加，
     * 发布版本被 #if 0 掉了，只剩 retain/release。保持对齐：no-op。 */
    (void)tag; (void)a; (void)b; (void)c; (void)kWCRProbeLogName;
}

#pragma mark - 被注入的 IMP（一一对应 WCR 的替换函数）

/* ── 0x8f3af8 : -[NSFileManager containerURLForSecurityApplicationGroupIdentifier:] ── */
static NSURL *WCRHook_ContainerURL(id self, SEL _cmd, NSString *groupIdentifier) {
    /* 分支 A（0x8f3b40）：扩展进程 + 组是 NSString
     * WCR 在这里调用 0x8f3f40 只为**预热 bss 0x2526a58 缓存**，
     * 返回值被 retain 后丢弃（0x8f3bcc → 0x8f3bd0 未写回返回槽），
     * 随后同样落到下面的公共路径。这里按原样保留该副作用。 */
    if (WCRIsGroupRemapExtensionProcess() &&
        [groupIdentifier isKindOfClass:[NSString class]]) {
        (void)WCRRemapGroupID(groupIdentifier);
    }

    if (!WCRFixActive()) {                                        /* 0x8f3be4 */
        return WCRUnmappedContainerURL(groupIdentifier);
    }
    if (![groupIdentifier isKindOfClass:[NSString class]]) {      /* 0x8f3c88 */
        return WCRUnmappedContainerURL(groupIdentifier);
    }
    if (groupIdentifier.length == 0) {                            /* 0x8f3cb4 */
        return WCRUnmappedContainerURL(groupIdentifier);
    }
    if (!WCRShouldRemapGroup(groupIdentifier)) {                  /* 0x8f3d10 */
        return WCRUnmappedContainerURL(groupIdentifier);
    }

    NSURL *u = WCRRemappedContainerURL();                         /* 0x8f3d54 */
    if (!u) {                                                     /* 0x8f3d74 */
        return WCRUnmappedContainerURL(groupIdentifier);          /* 0x8f3e8c */
    }

    WCRProbe(@"container", groupIdentifier, WCRCurrentGroupID(), u.path); /* 0x8f3de4 */
    return u;                                                     /* 0x8f3e24 */
}

/* ── 0x8f55cc : -[CKEntitlements initWithEntitlementsDict:] ── */
static id WCRHook_CKEntitlementsInit(id self, SEL _cmd, NSDictionary *dict) {
    /* 注意：这里原来写成 goto passthrough;，ARC 下 goto 不能跨过 __strong 变量的
     * 初始化（clang: "jump bypasses initialization of __strong variable"），
     * 全部改成早返回语义，二进制里的控制流完全等价。 */
    NSDictionary *patched = dict;
    if (WCRFixActive() &&                                         /* 0x8f5610 */
        [dict isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *m = [dict mutableCopy];              /* 0x8f56d8 */
        /* 自签包没有这些 iCloud entitlement，留着会让 CloudKit 走错误分支 */
        [m removeObjectForKey:@"com.apple.developer.icloud-container-environment"]; /* 0x8f5710 */
        [m removeObjectForKey:@"com.apple.developer.icloud-services"];              /* 0x8f5734 */
        patched = [m copy];                                       /* 0x8f5748 */
    }
    if (gOrigCKEntitlementsInit) return gOrigCKEntitlementsInit(self, _cmd, patched);
    return nil;
}

/* ── 0x8f5834 : -[CKContainer _initWithContainerIdentifier:] ── */
static id WCRHook_CKInitWithID(id self, SEL _cmd, NSString *containerID) {
    if (WCRFixActive() &&                                         /* 0x8f5878 */
        [containerID isKindOfClass:[NSString class]]) {
        /* WCR 走 0x8f6760：把 CloudKit 容器目录也挂到重映射后的 App Group 容器下 */
        NSURL *u = WCRRemappedContainerURL();
        if (u) {
            NSString *dir = [u URLByAppendingPathComponent:containerID].path;
            WCREnsureDirectory(dir);
        }
    }
    if (gOrigCKInitWithID) return gOrigCKInitWithID(self, _cmd, containerID);
    return nil;
}

/* ── 0x8f5af8 : -[CKContainer _setupWithContainerID:options:] ── */
static id WCRHook_CKSetupWithID(id self, SEL _cmd, NSString *containerID, id options) {
    if (WCRFixActive() &&                                         /* 0x8f5b48 */
        [containerID isKindOfClass:[NSString class]]) {
        NSURL *u = WCRRemappedContainerURL();
        if (u) {
            NSString *dir = [u URLByAppendingPathComponent:containerID].path;
            WCREnsureDirectory(dir);
        }
    }
    if (gOrigCKSetupWithID) return gOrigCKSetupWithID(self, _cmd, containerID, options);
    return nil;
}

/* ── 0x8f5df4 : -[NSUserDefaults _initWithSuiteName:container:] ── */
static id WCRHook_UserDefaultsSuiteInit(id self, SEL _cmd, NSString *suiteName, id container) {
    BOOL remap = WCRFixActive() &&                                            /* 0x8f5e50 */
                 [suiteName isKindOfClass:[NSString class]] &&                 /* 0x8f5f08 */
                 [suiteName hasPrefix:kWCRGroupPrefix] &&                      /* 0x8f5f3c */
                 WCRShouldRemapGroup(suiteName);                               /* 0x8f5f98 */
    if (remap) {
        NSURL *u = WCRRemappedContainerURL();                                  /* 0x8f5fe4 */
        NSString *gid = u ? WCRCurrentGroupID() : nil;                          /* 0x8f60d0 */
        if (u && gid.length > 0) {                                              /* 0x8f6004 */
            NSURL *suiteURL = [u URLByAppendingPathComponent:gid];              /* 0x8f618c */
            WCREnsureDirectory(suiteURL.path);                                  /* 0x8f61f0 (0x8f6af4) */
            WCRProbe(@"suite", suiteName, gid, suiteURL.path);                  /* 0x8f625c */
            if (gOrigUserDefaultsSuiteInit) {
                return gOrigUserDefaultsSuiteInit(self, _cmd, gid, suiteURL);   /* 0x8f6280 */
            }
        }
    }
    if (gOrigUserDefaultsSuiteInit) {
        return gOrigUserDefaultsSuiteInit(self, _cmd, suiteName, container);
    }
    return nil;
}

/* ── 0x8f6cf4 : +[WCAppExtensionDataUtil appGroupID] / +[WCExtDataUtil appGroupID] 的公共体 ── */
static id WCRHook_AppGroupID(IMP orig, id self, SEL _cmd) {
    if (!WCRFixActive()) {                                    /* 0x8f6d20 */
        if (orig) {
            id r = ((id (*)(id, SEL))orig)(self, _cmd);        /* 0x8f6d60 */
            return r;
        }
        return nil;                                            /* 0x8f6d98 */
    }
    NSString *gid = WCRCurrentGroupID();                       /* 0x8f6dfc */
    return gid.length ? gid : (orig ? ((id (*)(id, SEL))orig)(self, _cmd) : nil);
}

static id WCRHook_AppExtDataUtilGroupID(id self, SEL _cmd) {
    return WCRHook_AppGroupID((IMP)gOrigAppExtDataUtilGroupID, self, _cmd);   /* 0x8f63b0 */
}

static id WCRHook_ExtDataUtilGroupID(id self, SEL _cmd) {
    return WCRHook_AppGroupID((IMP)gOrigExtDataUtilGroupID, self, _cmd);      /* 0x8f644c */
}

/* ── 0x8f64e8 : -[MSEShareMainViewController doAuthenticateCheck] ── */
static id WCRHook_DoAuthenticateCheck(id self, SEL _cmd) {
    if (gOrigDoAuthenticateCheck) return gOrigDoAuthenticateCheck(self, _cmd);
    return nil;
}

/* ── 0x8f6608 : -[MSEShareMainViewController onCheckAuthenticateDidFinish:] ── */
static void WCRHook_AuthDidFinish(id self, SEL _cmd, id arg) {
    if (gOrigAuthDidFinish) gOrigAuthDidFinish(self, _cmd, arg);
}

#pragma mark - 安装（0x8f3630 / 0x8f3698 / 0x8f3508）

/* 0x8f3630 */
static void WCRInstallFileManagerHook(void) {
    if (gSwizzledFileManager) return;                       /* 0x8f363c */
    Class cls = [NSFileManager class];                      /* classref 0x238f8f0 */
    SEL sel = @selector(containerURLForSecurityApplicationGroupIdentifier:);
    gSwizzledFileManager = WCRSwizzle(cls, sel,
                                      (IMP)WCRHook_ContainerURL,
                                      (IMP *)&gOrigContainerURL);   /* 0x8f3680 */
}

/* 0x8f3698 */
static void WCRInstallOtherHooks(void) {
    Class ckEnt = NSClassFromString(kWCRCKEntitlementsClass);
    if (ckEnt) {                                                       /* 0x8f36b8 */
        WCRSwizzle(ckEnt, NSSelectorFromString(kWCRCKEntitlementsInit),
                   (IMP)WCRHook_CKEntitlementsInit, (IMP *)&gOrigCKEntitlementsInit);
    }

    Class ck = NSClassFromString(kWCRCKContainerClass);
    if (ck) {                                                          /* 0x8f3708 */
        WCRSwizzle(ck, NSSelectorFromString(kWCRCKInitWithID),
                   (IMP)WCRHook_CKInitWithID, (IMP *)&gOrigCKInitWithID);
        WCRSwizzle(ck, NSSelectorFromString(kWCRCKSetupWithID),
                   (IMP)WCRHook_CKSetupWithID, (IMP *)&gOrigCKSetupWithID);
    }

    WCRInstallFileManagerHook();                                        /* 0x8f3774 */

    Class ud = [NSUserDefaults class];                                  /* classref 0x238f8c8 */
    WCRSwizzle(ud, NSSelectorFromString(kWCRUserDefaultsSuiteInit),
               (IMP)WCRHook_UserDefaultsSuiteInit,
               (IMP *)&gOrigUserDefaultsSuiteInit);                     /* 0x8f37bc */

    Class m1 = NSClassFromString(kWCRAppExtDataUtilClass);              /* 0x8f37d0 */
    if (m1) {
        Class meta = objc_getMetaClass(kWCRAppExtDataUtilClass.UTF8String); /* 0x1f15840 */
        WCRSwizzle(meta, NSSelectorFromString(kWCRAppGroupIDSel),
                   (IMP)WCRHook_AppExtDataUtilGroupID,
                   (IMP *)&gOrigAppExtDataUtilGroupID);                 /* 0x8f380c */
    }

    Class m2 = NSClassFromString(kWCRExtDataUtilClass);                 /* 0x8f3828 */
    if (m2) {
        Class meta = objc_getMetaClass(kWCRExtDataUtilClass.UTF8String);
        WCRSwizzle(meta, NSSelectorFromString(kWCRAppGroupIDSel),
                   (IMP)WCRHook_ExtDataUtilGroupID,
                   (IMP *)&gOrigExtDataUtilGroupID);                    /* 0x8f3860 */
    }

    Class shareVC = NSClassFromString(kWCRShareMainVCClass);            /* 0x8f387c */
    if (shareVC) {
        WCRSwizzle(shareVC, NSSelectorFromString(kWCRDoAuthenticateCheck),
                   (IMP)WCRHook_DoAuthenticateCheck,
                   (IMP *)&gOrigDoAuthenticateCheck);                   /* 0x8f38b0 */
        Method m = class_getInstanceMethod(shareVC,
                       NSSelectorFromString(kWCRAuthDidFinish));        /* 0x1f15228 */
        if (m && method_getNumberOfArguments(m) == 3) {                  /* 0x8f38e8 */
            WCRSwizzle(shareVC, NSSelectorFromString(kWCRAuthDidFinish),
                       (IMP)WCRHook_AuthDidFinish,
                       (IMP *)&gOrigAuthDidFinish);                     /* 0x8f3924 */
        }
    }
}

/* 0x14823ec —— 总开关 */
static BOOL WCRShouldInstall(void) {
    if (WCRIsShareExtensionProcess()) return YES;             /* 0x1482108 分支 */
    if (WCRIsNotificationServiceProcess()) return YES;        /* 0x148230c 分支 */
    if (!WCRPreferredHostLinked()) return NO;                 /* 0x14804f8 */
    return YES;   /* 纯本地运行：无开关，默认生效（原函数 0x148236c 云控点已删除） */
}

/* 设置页「选择分组」：把用户选定的应用组固化下来并立刻生效（对应 WCR 原版
 * 0x1482888 WCRSideloadFixApplySelectedGroupID 的写入部分）。扩展进程（NSE /
 * 分享扩展）下次启动扫 marker 时才切换到新组，故选完需杀对应进程后重开微信。 */
static void WCRSelectGroup(NSString *groupID) {
    if (![groupID isKindOfClass:[NSString class]] || groupID.length == 0) return;
    if (![WCRApplicationGroupIDs() containsObject:groupID]) return;   /* 只接受当前包声明过的组 */

    WCRSetPickedGroupID(groupID);          /* 写 sideloadShareFixAppGroupId（NSUserDefaults / WCRefineConfig） */
    WCRWriteGroupMarker(groupID);          /* 写进所有可用容器，供扩展进程反向查组 */

    /* 清缓存，让下一次容器访问按新组重新解析（0x8f3f40 / 0x8f4e50 的 memo） */
    gCachedRemappedGroup  = nil;
    gCachedAvailableGroups = nil;
    gCachedContainerURL   = nil;
    gCachedContainerGroup = nil;
}

#pragma mark - 安装流程

/* 0x8f3508 —— 完整安装流程 */
static void WCRSideloadFixInstall(void) {
    BOOL isNotif = WCRIsNotificationServiceProcess();          /* 0x8f3520 */
    BOOL should  = WCRShouldInstall();                         /* 0x8f3528 */

    if (isNotif) WCRInstallFileManagerHook();                  /* 0x8f353c */

    if (!should) {                                             /* 0x8f3548 */
        if (isNotif) WCRInstallOtherHooks();                   /* 0x8f355c */
        return;
    }

    if (WCRIsGroupRemapExtensionProcess()) {                   /* 0x8f3568 */
        WCRInstallOtherHooks();                                /* 0x8f3614 */
        return;
    }

    /* 主 App：把当前选定的应用组写进所有可用容器的 marker 文件。
     * 纯本地版默认生效，未选组时自动选第一个可用组；
     * 可在微信「插件」页的「自签修复」设置界面手动切换分组（多开防串号）。 */
    NSString *gid = WCRResolvedGroupID();                      /* 0x8f3574 */
    if (gid.length == 0) {
        NSArray<NSString *> *ids = WCRApplicationGroupIDs();   /* 自动选第一个 */
        if (ids.count) {
            WCRSetPickedGroupID(ids.firstObject);
            gid = ids.firstObject;
        }
    }
    if (gid.length > 0) WCRWriteGroupMarker(gid);              /* 0x8f35b8 */

    WCRInstallOtherHooks();                                    /* 0x8f3614 */
}

#pragma mark - 设置界面（参考 DD收款助手：父 cell 展开 + 子 cell 选择）

/* 单 section、单父 cell「证书分组（应用组）」，点按展开成应用组列表，
 * 点子 cell 即选定该组。沿用 DD 收款助手的交互模式，但底层用原生 UITableView
 * —— 8.0.78 的 WCTableViewManager initWithFrame:style: 第二参是 CGSize（DD 那版
 * 微信 76 是 NSInteger/UITableViewStyle），照搬会 ABI 错位崩溃，故不依赖微信内部表格类。 */
@interface WCRSideloadFixSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic) BOOL expanded;
@end

@implementation WCRSideloadFixSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"自签修复";

    /* 与 DD 收款助手一致的导航栏外观：去底部分割线 */
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithDefaultBackground];
        appearance.shadowColor = nil;
        self.navigationItem.standardAppearance   = appearance;
        self.navigationItem.scrollEdgeAppearance = appearance;
        self.navigationItem.compactAppearance    = appearance;
    }

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate   = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.tableView];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.expanded ? (1 + [WCRApplicationGroupIDs() count]) : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"即签名证书中的 application-groups。多开请选不同应用组，防止串号。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WCRCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:@"WCRCell"];
    }
    NSArray<NSString *> *groups = WCRApplicationGroupIDs();
    NSString *picked = WCRPickedGroupID();

    if (indexPath.row == 0) {
        cell.textLabel.text = @"证书分组（应用组）";
        cell.detailTextLabel.text = picked.length ? picked : @"未选择";
        cell.accessoryType = self.expanded ? UITableViewCellAccessoryNone
                                           : UITableViewCellAccessoryDisclosureIndicator;
    } else {
        NSString *gid = groups[indexPath.row - 1];
        cell.textLabel.text = gid;
        cell.detailTextLabel.text = nil;
        cell.accessoryType = [gid isEqualToString:picked]
                             ? UITableViewCellAccessoryCheckmark
                             : UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.row == 0) {
        self.expanded = !self.expanded;
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                 withRowAnimation:UITableViewRowAnimationAutomatic];
        return;
    }

    NSString *gid = [WCRApplicationGroupIDs() objectAtIndex:indexPath.row - 1];
    WCRSelectGroup(gid);                  /* 写 picked + marker + 清缓存，立刻生效 */
    self.expanded = NO;
    [tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
             withRowAnimation:UITableViewRowAnimationAutomatic];
}

@end

#pragma mark - 构造

%ctor {
    @autoreleasepool {
        /* WCR 在 0x8f3508 里同样是"先判定进程/开关，再装 hook"，
         * 所有 hook 在主 App 与扩展进程里都会装（由 WCRFixActive 运行期决定生效）。
         * 纯本地版默认生效，这里只按 WCR 顺序执行安装。 */
        WCRSideloadFixInstall();

        /* 插件入口：照搬 DD收款助手 的 WCPluginsMgr 注册方式。
         * WCPluginsMgr 已在文件顶部手动声明（用户确认存在于 8.0.78），
         * 直接编译期调用 [WCPluginsMgr sharedInstance]，不再走 objc_getClass。
         * 用户在微信「插件」页点「自签修复」即进入上面的设置界面。 */
        WCPluginsMgr *mgr = [WCPluginsMgr sharedInstance];
        if (mgr && [mgr respondsToSelector:@selector(registerControllerWithTitle:version:controller:)]) {
            [mgr registerControllerWithTitle:@"自签修复"
                                     version:@"1.0.0"
                                  controller:@"WCRSideloadFixSettingsViewController"];
        }
    }
}
