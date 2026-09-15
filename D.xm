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
 *  ── 私有函数（本文件按原样重建）─────────────────────────────────────────
 *  0x8f5490  WCRCurrentGroupID        扩展:0x8f3f40(nil)  主App:0x1481ec0
 *  0x8f4b9c  WCRFixActive             扩展:当前组非空    主App:config.sideloadShareFixEnabled
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

#pragma mark - 常量（全部来自 __cstring / __cfstring）

/* @0x204476c —— marker 文件名：主 App 把"选定的应用组"写进所有可用容器的
 *   <container>/Library/Preferences/ 下；扩展进程反过来扫这些文件找回组 id。 */
static NSString * const kWCRMarkerFileName = @"com.qimiao.WCRefine.sideload-share-fix-group";
/* @0x205b1b9 —— 探针日志（WCR 内 0 调用，保留） */
static NSString * const kWCRProbeLogName   = @"com.qimiao.WCRefine.sideload-share-fix.log";
/* @0x205b3cd —— 云控 feature id */
static NSString * const kWCRCloudFeatureID = @"sideload_share_fix";

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

/* 配置键（WCRefineConfig，classref @0x238f810） */
static NSString * const kWCRCfgEnabled  = @"sideloadShareFixEnabled";
static NSString * const kWCRCfgGroupID  = @"sideloadShareFixAppGroupId";

#pragma mark - 前向声明

static NSArray<NSString *> *WCRApplicationGroupIDs(void);
static NSString *WCRMarkerGroupID(void);
static BOOL WCRWriteGroupMarker(NSString *groupID);
static void WCRClearGroupMarker(void);
static NSString *WCRResolvedGroupID(void);
static NSString *WCRCurrentGroupID(void);
static BOOL WCRFixActive(void);
static BOOL WCRShouldRemapGroup(NSString *groupID);
static NSURL *WCRRemappedContainerURL(void);
static NSString *WCRRemapGroupID(NSString *groupID);
static NSArray<NSString *> *WCRCachedAvailableGroups(void);
static void WCREnsureDirectory(NSString *path);
static BOOL WCRPreferredHostLinked(void);
static BOOL WCRCloudAllowed(void);
static BOOL WCRShouldInstall(void);
static NSString *WCRStatusText(void);
static void WCRApplySelectedGroupID(NSString *groupID);
static void WCRPresentGroupPickerOn(UIViewController *presenter);

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

/* 1) 0x147d944 内部缓存  2) 0x147bd34+0x147c2d0 embedded.mobileprovision
 * 3) 0x147c448 可执行文件  4) 0x147d254 CodeSignature
 * 每一级都用 @selector(count) 判空后再 objectForKeyedSubscript: */
static NSArray<NSString *> *WCRDeclaredAppGroupIDs(void) {
    /* 级别 1：SecTaskCopyValueForEntitlement（进程真实生效的 entitlement） */
    SecTaskRef task = SecTaskCreateFromSelf(NULL);
    if (task) {
        CFErrorRef err = NULL;
        CFTypeRef v = SecTaskCopyValueForEntitlement(task,
                        (__bridge CFStringRef)kWCREntitlementAppGroups, &err);
        NSArray *a = CFBridgingRelease(v);
        CFRelease(task);
        if (err) { CFRelease(err); }
        if (a.count) return a;
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

    /* 级别 3/4：可执行文件的 code signature（这里用 SecStaticCode 兜底） */
    NSURL *exeURL = [[NSBundle mainBundle] executableURL];
    if (exeURL) {
        SecStaticCodeRef code = NULL;
        if (SecStaticCodeCreateWithPath((__bridge CFURLRef)exeURL,
                                        kSecCSDefaultFlags, &code) == errSecSuccess) {
            CFDictionaryRef info = NULL;
            if (SecCodeCopySigningInformation(code, kSecCSDefaultFlags, &info)
                == errSecSuccess) {
                NSDictionary *d = CFBridgingRelease(info);
                NSArray *a = WCRGroupsFromEntitlements(d[@"entitlements"]);
                if (a.count) { CFRelease(code); return a; }
            }
            CFRelease(code);
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

/* 0x14810f8 */
static void WCRClearGroupMarker(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSURL *mu in WCRMarkerFileURLs()) {
        [fm removeItemAtURL:mu error:NULL];
    }
    gCachedRemappedGroup = nil;
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

static BOOL WCRFixEnabledFromConfig(void) {
    id cfg = WCRConfig();
    if (!cfg) return NO;
    if (![cfg respondsToSelector:NSSelectorFromString(kWCRCfgEnabled)]) return NO;
    return [[cfg valueForKey:kWCRCfgEnabled] boolValue];
}

static void WCRSetFixEnabledInConfig(BOOL on) {
    id cfg = WCRConfig();
    if (!cfg) return;
    if ([cfg respondsToSelector:NSSelectorFromString(@"setSideloadShareFixEnabled:")]) {
        [cfg setValue:@(on) forKey:kWCRCfgEnabled];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:on forKey:kWCRCfgEnabled];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

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

#pragma mark - ProtobufLite 链接检查（0x14804f8）

/* 「需注入 ProtobufLite3（没有则 ProtobufLite）」 */
static BOOL WCRObjectIsImageLinked(NSString *imageName) {
    if (imageName.length == 0) return NO;
    const char *name = imageName.UTF8String;
    BOOL found = (dlsym(RTLD_DEFAULT, name) != NULL);
    if (found) return YES;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *p = _dyld_get_image_name(i);
        if (!p) continue;
        NSString *path = @(p);
        if ([path.lastPathComponent hasPrefix:imageName] ||
            [path rangeOfString:[NSString stringWithFormat:@"/%@.", imageName]].location != NSNotFound ||
            [path rangeOfString:[NSString stringWithFormat:@"/%@/", imageName]].location != NSNotFound) {
            return YES;
        }
    }
    /* 兜底：拿该类/函数符号探测 */
    void *h = dlopen(NULL, RTLD_NOLOAD);
    if (h) {
        NSString *sym = [@"OBJC_CLASS_$_" stringByAppendingString:imageName];
        if (dlsym(h, sym.UTF8String)) return YES;
    }
    return NO;
}

static BOOL WCRPreferredHostLinked(void) {              /* 0x14804f8 */
    if (WCRObjectIsImageLinked(kWCRProtobufLite3)) return YES;
    return WCRObjectIsImageLinked(kWCRProtobufLite);
}

#pragma mark - 云控（0x148236c）

static BOOL WCRCloudAllowed(void) {                      /* 0x148236c */
    /* WCR 内部走自己的云控；独立插件版本默认放行，
     * 如需接自己的开关，在这里按 feature id `sideload_share_fix` 判定即可。 */
    (void)kWCRCloudFeatureID;
    return YES;
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
    return WCRFixEnabledFromConfig();            /* 主 App：跟随开关 */
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
    if (!WCRFixActive()) goto passthrough;                        /* 0x8f5610 */
    if (![dict isKindOfClass:[NSDictionary class]]) goto passthrough;

    NSMutableDictionary *m = [dict mutableCopy];                  /* 0x8f56d8 */
    /* 自签包没有这些 iCloud entitlement，留着会让 CloudKit 走错误分支 */
    [m removeObjectForKey:@"com.apple.developer.icloud-container-environment"]; /* 0x8f5710 */
    [m removeObjectForKey:@"com.apple.developer.icloud-services"];              /* 0x8f5734 */
    dict = [m copy];                                              /* 0x8f5748 */

passthrough:
    if (gOrigCKEntitlementsInit) return gOrigCKEntitlementsInit(self, _cmd, dict);
    return nil;
}

/* ── 0x8f5834 : -[CKContainer _initWithContainerIdentifier:] ── */
static id WCRHook_CKInitWithID(id self, SEL _cmd, NSString *containerID) {
    if (!WCRFixActive()) goto passthrough;                        /* 0x8f5878 */
    if (![containerID isKindOfClass:[NSString class]]) goto passthrough;
    /* WCR 走 0x8f6760：把 CloudKit 容器目录也挂到重映射后的 App Group 容器下 */
    {
        NSURL *u = WCRRemappedContainerURL();
        if (u) {
            NSString *dir = [u URLByAppendingPathComponent:containerID].path;
            WCREnsureDirectory(dir);
        }
    }
passthrough:
    if (gOrigCKInitWithID) return gOrigCKInitWithID(self, _cmd, containerID);
    return nil;
}

/* ── 0x8f5af8 : -[CKContainer _setupWithContainerID:options:] ── */
static id WCRHook_CKSetupWithID(id self, SEL _cmd, NSString *containerID, id options) {
    if (!WCRFixActive()) goto passthrough;                        /* 0x8f5b… */
    if (![containerID isKindOfClass:[NSString class]]) goto passthrough;
    {
        NSURL *u = WCRRemappedContainerURL();
        if (u) {
            NSString *dir = [u URLByAppendingPathComponent:containerID].path;
            WCREnsureDirectory(dir);
        }
    }
passthrough:
    if (gOrigCKSetupWithID) return gOrigCKSetupWithID(self, _cmd, containerID, options);
    return nil;
}

/* ── 0x8f5df4 : -[NSUserDefaults _initWithSuiteName:container:] ── */
static id WCRHook_UserDefaultsSuiteInit(id self, SEL _cmd, NSString *suiteName, id container) {
    if (!WCRFixActive()) goto passthrough;                                   /* 0x8f5e50 */
    if (![suiteName isKindOfClass:[NSString class]]) goto passthrough;        /* 0x8f5f08 */
    if (![suiteName hasPrefix:kWCRGroupPrefix]) goto passthrough;             /* 0x8f5f3c */
    if (!WCRShouldRemapGroup(suiteName)) goto passthrough;                    /* 0x8f5f98 */
    {
        NSURL *u = WCRRemappedContainerURL();                                 /* 0x8f5fe4 */
        if (!u) goto passthrough;                                              /* 0x8f6004 */

        NSString *gid = WCRCurrentGroupID();                                   /* 0x8f60d0 */
        if (gid.length == 0) goto passthrough;

        NSURL *suiteURL = [u URLByAppendingPathComponent:gid];                 /* 0x8f618c */
        WCREnsureDirectory(suiteURL.path);                                     /* 0x8f61f0 (0x8f6af4) */
        WCRProbe(@"suite", suiteName, gid, suiteURL.path);                     /* 0x8f625c */
        if (gOrigUserDefaultsSuiteInit) {
            return gOrigUserDefaultsSuiteInit(self, _cmd, gid, suiteURL);      /* 0x8f6280 */
        }
    }
passthrough:
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
    if (!WCRFixEnabledFromConfig()) return NO;
    if (!WCRPreferredHostLinked()) return NO;                 /* 0x14804f8 */
    return WCRCloudAllowed();                                 /* 0x148236c */
}

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

    /* 主 App：把当前选定的应用组写进所有可用容器的 marker 文件 */
    NSString *gid = WCRResolvedGroupID();                      /* 0x8f3574 */
    if (gid.length > 0) WCRWriteGroupMarker(gid);              /* 0x8f35b8 */

    WCRInstallOtherHooks();                                    /* 0x8f3614 */
}

#pragma mark - 应用组选择（对应 0x1482b10 PresentGroupPicker / 0x1482888 ApplySelectedGroupID）

static void WCRApplySelectedGroupID(NSString *gid) {            /* 0x1482888 */
    WCRSetPickedGroupID(gid);
    gCachedRemappedGroup = nil;
    gCachedAvailableGroups = nil;
    gCachedContainerURL = nil;
    gCachedContainerGroup = nil;
    if (gid.length) WCRWriteGroupMarker(gid);
}

static NSString *WCRStatusText(void) {
    NSArray *ids = WCRApplicationGroupIDs();
    if (ids.count == 0) {
        return @"当前包没有应用组权限。请确认描述文件或签名含 application-groups。";
    }
    NSMutableArray *parts = [NSMutableArray array];
    [parts addObject:[NSString stringWithFormat:@"应用组权限：%lu 个",
                      (unsigned long)ids.count]];
    NSString *cur = WCRResolvedGroupID();
    [parts addObject:[NSString stringWithFormat:@"当前应用组：%@",
                      cur.length ? cur : @"无应用组"]];
    if (!WCRPreferredHostLinked()) {
        [parts addObject:@"未检测到 ProtobufLite3 / ProtobufLite，请注入后再试。"];
    }
    [parts addObject:@"多开请选不同应用组，防止串号。"];
    return [parts componentsJoinedByString:@"\n"];
}

static void WCRPresentGroupPickerOn(UIViewController *presenter) {
    NSArray<NSString *> *ids = WCRApplicationGroupIDs();
    UIAlertController *ac =
        [UIAlertController alertControllerWithTitle:@"选择你的应用组"
                                            message:WCRStatusText()
                                     preferredStyle:UIAlertControllerStyleActionSheet];
    if (ids.count == 0) {
        [ac addAction:[UIAlertAction actionWithTitle:@"无应用组"
                                               style:UIAlertActionStyleDefault
                                             handler:nil]];
    }
    for (NSString *gid in ids) {
        NSString *title = [gid isEqualToString:WCRPickedGroupID()]
                        ? [NSString stringWithFormat:@"✓ %@", gid] : gid;
        [ac addAction:[UIAlertAction actionWithTitle:title
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction * _Nonnull a) {
            WCRApplySelectedGroupID(gid);
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消"
                                           style:UIAlertActionStyleCancel
                                         handler:nil]];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UIPopoverPresentationController *pop = ac.popoverPresentationController;
        pop.sourceView = presenter.view;
        pop.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                    CGRectGetMidY(presenter.view.bounds), 0, 0);
    }
    [presenter presentViewController:ac animated:YES completion:nil];
}

#pragma mark - 主 App 设置页入口

%group WCRMainAppGroup

%hook NewSettingViewController

- (void)reloadTableData {
    %orig;
    if (![(id)self isKindOfClass:[UIViewController class]]) return;
    if (![self respondsToSelector:@selector(navigationItem)]) return;

    UIViewController *vc = (UIViewController *)self;
    if (objc_getAssociatedObject(vc, @selector(reloadTableData))) return;
    objc_setAssociatedObject(vc, @selector(reloadTableData), @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    vc.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"自签修复"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(wcr_openSideloadFix)];
}

%new
- (void)wcr_openSideloadFix {
    UIViewController *vc = (UIViewController *)self;
    __weak typeof(vc) weakVC = vc;

    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:@"自签修复"
                         message:WCRStatusText()
                  preferredStyle:UIAlertControllerStyleActionSheet];

    [ac addAction:[UIAlertAction
        actionWithTitle:(WCRFixEnabledFromConfig() ? @"关闭修复" : @"开启修复")
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction * _Nonnull action) {
        BOOL next = !WCRFixEnabledFromConfig();
        WCRSetFixEnabledInConfig(next);
        if (!next) { WCRClearGroupMarker(); return; }

        NSArray *ids = WCRApplicationGroupIDs();
        if (ids.count == 0) { WCRPresentGroupPickerOn(weakVC); return; }
        if (WCRPickedGroupID().length == 0) WCRApplySelectedGroupID(ids.firstObject);

        UIAlertController *tip = [UIAlertController
            alertControllerWithTitle:@"已更新修复自签分享"
                             message:@"需杀进程后重开微信"
                      preferredStyle:UIAlertControllerStyleAlert];
        [tip addAction:[UIAlertAction actionWithTitle:@"好"
                                               style:UIAlertActionStyleDefault
                                             handler:nil]];
        [weakVC presentViewController:tip animated:YES completion:nil];
    }]];

    [ac addAction:[UIAlertAction actionWithTitle:@"选择应用组"
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction * _Nonnull action) {
        WCRPresentGroupPickerOn(weakVC);
    }]];

    [ac addAction:[UIAlertAction actionWithTitle:@"取消"
                                           style:UIAlertActionStyleCancel
                                         handler:nil]];

    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UIPopoverPresentationController *pop = ac.popoverPresentationController;
        pop.sourceView = vc.view;
        pop.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds),
                                    CGRectGetMidY(vc.view.bounds), 0, 0);
    }
    [vc presentViewController:ac animated:YES completion:nil];
}

%end

%end // WCRMainAppGroup

#pragma mark - 构造

%ctor {
    @autoreleasepool {
        /* WCR 在 0x8f3508 里同样是"先判定进程/开关，再装 hook"，
         * 且所有 hook 都在**主 App 与扩展进程**里都装（由 WCRFixActive 运行期决定生效）。
         * 因此这里不做进程分流的 %init，只按 WCR 的顺序执行安装。 */
        WCRSideloadFixInstall();

        if (!WCRIsGroupRemapExtensionProcess()) {
            %init(WCRMainAppGroup);
        }
    }
}
