#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>

// ============================================================
//  DD小丑资料助手  (WeChat Jailbreak Tweak, Theos/Logos 单文件)
//  在微信内自定义「自己的微信号」与「单聊联系人头像」
//
//  功能一 · 自定义微信号（只处理自己的账号）
//    设置页填入目标微信号并打开开关。显示侧 hook 两个数据出口：
//      CSetting.m_nsAliasName        —— 自己的账号资料模型（CSetting.h:58/301）
//      CBaseContact.m_nsAliasName    —— 联系人基类，仅 isSelf 时替换（CBaseContact.h:12/177）
//    只改内存里的显示值，不写数据库、不发网络请求；关闭开关即恢复真实微信号。
//
//  功能二 · 单聊联系人头像替换
//    总开关：设置页「自定义用户头像」→「备注用户头像」。
//    入口：单聊「聊天信息」页(AddContactToChatRoomViewController)第一个分组首行插入「自定义头像」开关，
//      打开即调起系统相册选图并裁剪，关闭则删除本地图片。
//      该 VC 的表格是 MMTableViewInfo，它继承 WCTableViewManager(MMTableViewInfo.h:1)，
//      所以直接复用 WCTableViewSectionManager / WCTableViewCellManager 建行。
//      开关是自建 UISwitch + addTarget 绑定 action：微信的 switchCellForSel:target:title:on:
//      在本版本不回调传入的 sel（日志实证），故不能用它承载点击。
//    存储：Documents/DDAvatar/<userName>.png，按用户名一一对应，不额外维护映射表。
//    显示：hook MMHeadImageView 的全部写图入口，命中本地图就替换
//      会话列表/聊天页走这三个：
//        updateHeadImage:            (MMHeadImageView.h:66)
//        updateUsrName:withHeadImgUrl: (MMHeadImageView.h:54)
//        ImageDidLoad:Url:           (MMHeadImageView.h:68，异步下载完成后会覆盖，必须拦)
//      联系人资料页(CBaseContactInfoAssist.h:16 m_headView，同一个 MMHeadImageView 类)
//      不走上面三个，补了这批入口：
//        initWithUsrName:headImgUrl:bAutoUpdate:bRoundCorner: (h:45)
//        setHeadImageByName:         (h:50，按用户名取图，资料页最可能走它)
//        doUpdateHeadImg:            (h:52)
//        onHeadImageChange:          (h:57)
//        onModifyContact:            (h:71)
//      另加 didMoveToWindow 兜底(UIView 通用)，覆盖所有未列出入口与「图先设好不再刷新」的情况。
//      各入口用「头像入口·xxx」计入次、「头像替换·xxx」计替换次，导出日志可看出资料页走的是哪个。
//    限制：不支持群聊，命中 [CBaseContact isChatroom] 直接跳过注入(CBaseContact.h:129)。
//
//  诊断日志（DDLOG / DDJokerHit / 设置页「导出日志」）默认关闭：
//    仅在设置页打开「记录运行日志」后，才在插件加载处与各功能 hook 命中处记录，
//    并进入命中统计与导出文件；其余时候各模块静默运行，不写日志。
//    开关由 viewWillAppear 入口创建（日志实证该 VC 不走 reloadTableData），入口名写进日志；
//    导出文件为 Documents/DDProfileDiag.log。
// ============================================================


#pragma mark - 微信类声明
// 本插件 hook 的微信原生类与方法签名，均锚定微信 .h 头文件 dump。


@interface WeToast : NSObject
+ (id)toast;
- (void)showDoneToastWithText:(id)a0;
- (void)showErrorToastWithText:(id)a0;
@end

// 统一 toast 出口：设置页 VC 的 dd_showDoneToast: / dd_showErrorToast: 走这两个函数，
// hook 内部（不在设置页 VC 里）直接调用，保证提示风格与主插件一致。
static void DDShowDoneToast(NSString *text) {
    if (!text.length) return;
    WeToast *toast = [%c(WeToast) toast];
    if (toast) [toast showDoneToastWithText:text];
}

static void DDShowErrorToast(NSString *text) {
    if (!text.length) return;
    WeToast *toast = [%c(WeToast) toast];
    if (toast) [toast showErrorToastWithText:text];
}

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// 只声明本插件实际用到的两个构造器：设置页开关用 switchCellForSel，
// 其余行（清理按钮、导出日志、头像开关）统一走 normalCellForSel 的 rightView 版本。
@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightView:(id)rightView;
@property (nonatomic, retain) id userInfo;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(NSString *)header;
@property (nonatomic, copy) NSString *footerTitle;
- (void)addCell:(id)arg1;
- (void)insertCell:(id)a0 At:(unsigned int)a1;
- (id)getAllCells;
@end

// 与主插件声明保持一致（style 用 NSInteger、tableView 只读），另保留注入所需的分组访问方法。
@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(NSInteger)style;
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, weak) id delegate;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (id)cellInfoAtIndexPath:(NSIndexPath *)indexPath;
- (unsigned long long)getSectionCount;
- (id)getSectionAt:(unsigned long long)a0;
- (void)reloadTableView;
@end

// 联系人数据模型。CContact 继承 CBaseContact(CContact.h:3)，字段都在基类。
@interface CBaseContact : NSObject
@property (retain, nonatomic) NSString *m_nsUsrName;
@property (retain, nonatomic) NSString *m_nsAliasName;
- (BOOL)isChatroom;
- (BOOL)isSelf;
@end

@interface CContact : CBaseContact
@end

// 自己的账号资料模型，微信号字段 m_nsAliasName(CSetting.h:58)，getter 见 CSetting.h:301。
@interface CSetting : NSObject
- (id)m_nsAliasName;
@end

// 微信头像视图：nsUsrName 可直接判断当前渲染的是谁(MMHeadImageView.h:23)。
// 资料页顶部头像也是它(CBaseContactInfoAssist.h:16 m_headView)，但走的写图入口与会话列表不同，
// 故下面把头文件里所有可能的写图入口都列上(行号见 MMHeadImageView.h)。
@interface MMHeadImageView : UIView
@property (readonly, nonatomic) NSString *nsUsrName;
- (id)initWithUsrName:(id)usrName headImgUrl:(id)headImgUrl bAutoUpdate:(BOOL)bAutoUpdate bRoundCorner:(BOOL)bRoundCorner; // h:45
- (void)setHeadImageByName:(id)usrName;        // h:50
- (void)doUpdateHeadImg:(BOOL)force;           // h:52
- (void)updateUsrName:(id)usrName withHeadImgUrl:(id)headImgUrl; // h:54
- (void)onHeadImageChange:(id)arg1;            // h:57
- (void)updateHeadImage:(id)image;             // h:66
- (void)updateHeadImageUrl:(id)headImgUrl;     // h:67
- (void)ImageDidLoad:(id)image Url:(id)url;    // h:68
- (void)onModifyContact:(id)arg1;              // h:71
- (void)didMoveToWindow;                       // UIView 通用兜底
@end

// 单聊「聊天信息」页。m_contact 是当前联系人(AddContactToChatRoomViewController.h:24)。
// 下面 %new 方法先声明以便 hook 内互相调用。
@interface AddContactToChatRoomViewController : UIViewController
@property (retain, nonatomic) CContact *m_contact;
- (void)reloadTableData;
- (void)dd_injectAvatarCellFrom:(NSString *)entry;
- (void)ddAvatarSwitchChanged:(UISwitch *)sender;
@end


#pragma mark - 配置


static NSString *const kDDWxidEnabledKey  = @"DDProfileWxidEnabled";
static NSString *const kDDWxidValueKey    = @"DDProfileWxidValue";
static NSString *const kDDAvatarEnabledKey = @"DDProfileAvatarEnabled";
static NSString *const kDDDiagEnabledKey   = @"DDProfileDiagEnabled";

@interface DDProfileConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL wxidEnabled;
@property (nonatomic, copy) NSString *wxidValue;
@property (nonatomic) BOOL avatarEnabled;
@property (nonatomic) BOOL diagEnabled;
@end


#pragma mark - 诊断日志 · 采集
// DDLOG 写内存缓冲（导出用）；DDJokerHit 做 hook 命中计数与节流。
// 默认关闭：只有设置页打开「记录运行日志」后才记录，各功能模块静默运行。

// DDAvatarDir 定义在下面的「头像文件管理」段，这里先声明，导出日志时用它盘点已替换头像。
static NSString *DDAvatarDir(void);


static NSDateFormatter *DDLogTimeFormatter(void) {
    static NSDateFormatter *fmt = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        fmt.dateFormat = @"HH:mm:ss.SSS";
    });
    return fmt;
}

static NSMutableString *DDLogBuffer(void) {
    static NSMutableString *buf = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ buf = [NSMutableString string]; });
    return buf;
}

static NSMutableDictionary *DDLogHits(void) {
    static NSMutableDictionary *hits = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ hits = [NSMutableDictionary dictionary]; });
    return hits;
}

static void DDProfileLog(NSString *fmt, ...) {
    if (![DDProfileConfig shared].diagEnabled) return;
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *line = [NSString stringWithFormat:@"%@  %@",
                      [DDLogTimeFormatter() stringFromDate:[NSDate date]], msg];
    NSLog(@"[DD小丑资料] %@", line);
    NSMutableString *buf = DDLogBuffer();
    @synchronized (buf) {
        [buf appendFormat:@"%@\n", line];
        if (buf.length > 300000) {
            [buf deleteCharactersInRange:NSMakeRange(0, buf.length - 200000)];
        }
    }
}

#define DDLOG(...) DDProfileLog(__VA_ARGS__)

// hook 命中计数，节流输出（前 3 次 + 每 50 次），避免刷屏。
static void DDJokerHit(NSString *tag) {
    NSMutableDictionary *hits = DDLogHits();
    NSInteger n = 0;
    @synchronized (hits) {
        n = [hits[tag] integerValue] + 1;
        hits[tag] = @(n);
    }
    if (n <= 3 || n % 50 == 0) DDLOG(@"HIT %@ 第 %ld 次", tag, (long)n);
}

static void DDProfileClearDiagLog(void) {
    NSMutableString *buf = DDLogBuffer();
    @synchronized (buf) { [buf setString:@""]; }
    NSMutableDictionary *hits = DDLogHits();
    @synchronized (hits) { [hits removeAllObjects]; }
}

static NSString *DDProfileDescribeHitStats(void) {
    NSMutableDictionary *hits = DDLogHits();
    if (!hits.count) return @"  (还没有任何 hook 被触发)\n";
    NSMutableString *s = [NSMutableString string];
    for (NSString *tag in [hits keysSortedByValueUsingComparator:^NSComparisonResult(id a, id b) {
        return [b compare:a];
    }]) {
        [s appendFormat:@"  %-28@ %@ 次\n", tag, hits[tag]];
    }
    return s;
}

static NSString *DDProfileExportDiagLog(void) {
    NSMutableString *out = [NSMutableString string];
    [out appendString:@"===== DD小丑资料 诊断日志 =====\n"];

    DDProfileConfig *c = [DDProfileConfig shared];
    [out appendFormat:@"开关状态 : 微信号=%d 头像=%d 诊断=%d\n",
     c.wxidEnabled, c.avatarEnabled, c.diagEnabled];
    [out appendFormat:@"微信号值 : %@\n", c.wxidValue.length ? c.wxidValue : @"(空)"];
    [out appendString:@"复现步骤 : 清空日志 → 复现问题 → 回本页导出，把日志发出去即可定位\n"];

    // 已替换头像盘点：Documents/DDAvatar/ 下的 png。
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:DDAvatarDir() error:nil];
    NSMutableArray *avatars = [NSMutableArray array];
    for (NSString *f in files) {
        if ([f.pathExtension isEqualToString:@"png"]) [avatars addObject:f];
    }
    [out appendFormat:@"已替换头像 : %lu 个%@\n", (unsigned long)avatars.count,
     avatars.count ? [NSString stringWithFormat:@"（%@）", [avatars componentsJoinedByString:@", "]] : @""];

    [out appendString:@"\n----- hook 命中统计 -----\n"];
    [out appendString:DDProfileDescribeHitStats()];

    [out appendString:@"\n----- 日志正文 -----\n"];
    NSMutableString *buf = DDLogBuffer();
    NSString *body = nil;
    @synchronized (buf) { body = [buf copy]; }
    [out appendString:body.length ? body : @"(空：诊断开关没开，或还没触发过相关 hook)\n"];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *file = [paths.firstObject stringByAppendingPathComponent:@"DDProfileDiag.log"];
    NSError *err = nil;
    [out writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:&err];
    if (err) { NSLog(@"[DD小丑资料] 写诊断日志失败: %@", err); return nil; }
    return file;
}


#pragma mark - 头像文件管理
// 按用户名直接落盘，文件名即 userName（去掉非字母数字字符），存在就有、不存在就没有。


static NSString *DDAvatarDir(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *doc = paths.firstObject;
    if (doc.length == 0) doc = @"/var/mobile/Documents";
    NSString *dir = [doc stringByAppendingPathComponent:@"DDAvatar"];
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:nil];
    }
    return dir;
}

static NSString *DDAvatarPathForUser(NSString *usrName) {
    if (usrName.length == 0) return nil;
    NSCharacterSet *keep = [NSCharacterSet alphanumericCharacterSet];
    NSMutableString *safe = [NSMutableString string];
    for (NSUInteger i = 0; i < usrName.length; i++) {
        unichar c = [usrName characterAtIndex:i];
        if ([keep characterIsMember:c]) {
            [safe appendFormat:@"%C", c];
        } else {
            [safe appendString:@"_"];
        }
    }
    return [DDAvatarDir() stringByAppendingPathComponent:[safe stringByAppendingPathExtension:@"png"]];
}

// 头像解码结果缓存：资料页等入口会高频查询(尤其 didMoveToWindow 兜底)，
// 每次 imageWithContentsOfFile 都走磁盘会拖慢渲染，故按用户名缓存，增删时失效。
static NSCache *DDAvatarCache(void) {
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 64;
    });
    return cache;
}

static void DDAvatarCacheInvalidate(NSString *usrName) {
    if (usrName.length) [DDAvatarCache() removeObjectForKey:usrName];
    else [DDAvatarCache() removeAllObjects];
}

static UIImage *DDAvatarImageForUser(NSString *usrName) {
    if (![DDProfileConfig shared].avatarEnabled) return nil;
    if (usrName.length == 0) return nil;
    NSCache *cache = DDAvatarCache();
    id cached = [cache objectForKey:usrName];
    if (cached) return (cached == [NSNull null]) ? nil : (UIImage *)cached;

    UIImage *img = [UIImage imageWithContentsOfFile:DDAvatarPathForUser(usrName)];
    if (!(img && img.size.width > 0 && img.size.height > 0)) img = nil;
    [cache setObject:(img ?: (UIImage *)[NSNull null]) forKey:usrName];
    return img;
}

// 等比缩到最大边 maxSide，避免原图过大拖慢列表渲染。
static UIImage *DDScaledImage(UIImage *image, CGFloat maxSide) {
    if (!image || maxSide <= 0) return image;
    CGSize size = image.size;
    CGFloat longest = MAX(size.width, size.height);
    if (longest <= maxSide) return image;
    CGFloat ratio = maxSide / longest;
    CGSize target = CGSizeMake(round(size.width * ratio), round(size.height * ratio));
    UIGraphicsBeginImageContextWithOptions(target, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, target.width, target.height)];
    UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaled ?: image;
}

static BOOL DDAvatarSaveImage(UIImage *image, NSString *usrName) {
    NSString *path = DDAvatarPathForUser(usrName);
    if (!image || !path) return NO;
    NSData *data = UIImagePNGRepresentation(DDScaledImage(image, 400.0));
    if (data.length == 0) return NO;
    BOOL ok = [data writeToFile:path atomically:YES];
    if (ok) DDAvatarCacheInvalidate(usrName);
    return ok;
}

static BOOL DDAvatarRemoveForUser(NSString *usrName) {
    NSString *path = DDAvatarPathForUser(usrName);
    if (!path) return NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return NO;
    BOOL ok = [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    DDAvatarCacheInvalidate(usrName);
    return ok;
}

static NSInteger DDAvatarRemoveAll(void) {
    NSString *dir = DDAvatarDir();
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    NSInteger n = 0;
    for (NSString *f in files) {
        if (![f.pathExtension isEqualToString:@"png"]) continue;
        if ([[NSFileManager defaultManager] removeItemAtPath:[dir stringByAppendingPathComponent:f] error:nil]) n++;
    }
    if (n > 0) DDAvatarCacheInvalidate(nil);
    return n;
}


#pragma mark - 选图（系统 UIImagePickerController）
// 与主插件同款：独立 delegate 类 + 系统相册，不往 AddContactToChatRoomViewController 上加同名
// %new 方法（该 VC 自己已有 imagePickerController:didFinishPickingMediaWithInfo:，见头文件 h:76）。
// delegate 用关联对象挂在 picker 上持有，而不是全局静态变量，picker 释放时自动释放。
// 与主插件的差异：头像需要方形，故开启 allowsEditing 并优先取 EditedImage。


typedef void (^DDAvatarPickCompletion)(UIImage *image);

@interface DDAvatarPicker : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) DDAvatarPickCompletion completion;
+ (void)presentFromViewController:(UIViewController *)vc completion:(DDAvatarPickCompletion)completion;
@end

@implementation DDAvatarPicker

static char kDDAvatarPickerDelegateKey;

// 找最上层可 present 的 VC：当前 VC 若已在呈现别的控制器，就从被呈现的那个继续往下找。
// 直接在已被遮挡的 VC 上 present，系统会静默丢弃并打 "already presenting" 警告。
static UIViewController *DDTopPresentedViewController(UIViewController *vc) {
    UIViewController *top = vc;
    NSInteger guard = 0;
    while (top.presentedViewController && !top.presentedViewController.isBeingDismissed && guard++ < 8) {
        top = top.presentedViewController;
    }
    return top;
}

+ (void)presentFromViewController:(UIViewController *)vc completion:(DDAvatarPickCompletion)completion {
    if (!vc) {
        DDLOG(@"[头像·相册] 失败：源 VC 为空");
        if (completion) completion(nil);
        return;
    }
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        DDLOG(@"[头像·相册] 失败：相册源不可用");
        if (completion) completion(nil);
        return;
    }

    UIViewController *presenter = DDTopPresentedViewController(vc);
    DDLOG(@"[头像·相册] 准备弹出 presenter=%@  window=%d  presented=%@",
          NSStringFromClass([presenter class]),
          presenter.view.window ? 1 : 0,
          presenter.presentedViewController ? NSStringFromClass([presenter.presentedViewController class]) : @"(无)");

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = YES;
    picker.title = @"头像修改";

    DDAvatarPicker *proxy = [[DDAvatarPicker alloc] init];
    proxy.completion = completion;
    picker.delegate = proxy;
    objc_setAssociatedObject(picker, &kDDAvatarPickerDelegateKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 延到下一个主循环再弹：开关的 ValueChanged 回调里立刻 present，偶尔会跟 UISwitch 自身的
    // 动画 / 表格刷新撞在同一帧被系统忽略，延迟一帧更稳。
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!presenter.view.window || presenter.isBeingDismissed || presenter.presentedViewController) {
            DDLOG(@"[头像·相册] 放弃弹出：presenter 状态异常 window=%d beingDismissed=%d presented=%@",
                  presenter.view.window ? 1 : 0, presenter.isBeingDismissed,
                  presenter.presentedViewController ? NSStringFromClass([presenter.presentedViewController class]) : @"(无)");
            if (completion) completion(nil);
            return;
        }
        [presenter presentViewController:picker animated:YES completion:^{
            DDLOG(@"[头像·相册] 已弹出");
        }];
    });
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    DDAvatarPickCompletion cb = self.completion;
    [picker dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(image);
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    DDAvatarPickCompletion cb = self.completion;
    [picker dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(nil);
    }];
}

@end


#pragma mark - 自定义微信号（只改自己）


// 开关未开或没填值就返回 nil，各 hook 点原样走 %orig。
static NSString *DDCustomWxid(void) {
    DDProfileConfig *cfg = [DDProfileConfig shared];
    if (!cfg.wxidEnabled) return nil;
    NSString *value = cfg.wxidValue;
    if (value.length == 0) return nil;
    return value;
}

%hook CSetting

- (id)m_nsAliasName {
    NSString *custom = DDCustomWxid();
    if (custom) {
        DDJokerHit(@"微信号替换·CSetting");
        return custom;
    }
    return %orig;
}

%end

%hook CBaseContact

- (id)m_nsAliasName {
    NSString *custom = DDCustomWxid();
    if (custom && [self isSelf]) {
        DDJokerHit(@"微信号替换·CBaseContact");
        return custom;
    }
    return %orig;
}

%end


#pragma mark - 头像替换（显示侧）


// 用户名采样：只诊断用。开日志时把每个头像视图实际渲染的 nsUsrName 记一次，
// 用于核对「存的图片文件名」与「资料页视图要的名字」是不是同一个 key。
static void DDSampleAvatarName(NSString *name) {
    if (![DDProfileConfig shared].diagEnabled || name.length == 0) return;
    static NSMutableSet *seen = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ seen = [NSMutableSet set]; });
    @synchronized (seen) {
        if ([seen containsObject:name]) return;
        [seen addObject:name];
    }
    DDLOG(@"[头像·采样] nsUsrName=%@", name);
}

// 统一替换出口：命中本地图就写回，返回是否替换。命中才记日志，未命中静默。
// 参数 usrName 为空时回落到视图自己的 nsUsrName。
static BOOL DDTryApplyCustomAvatar(MMHeadImageView *view, NSString *usrName, NSString *tag) {
    NSString *name = usrName.length ? usrName : view.nsUsrName;
    UIImage *custom = DDAvatarImageForUser(name);
    if (!custom) return NO;
    DDJokerHit(tag);
    [view updateHeadImage:custom];
    return YES;
}

%hook MMHeadImageView

// 同步写图入口：命中本地图就直接换成本地图，不再显示网络头像。
// 这三个入口刷新非常频繁，只在真正命中替换时记命中数（节流输出），不逐次写日志。
- (void)updateHeadImage:(id)image {
    UIImage *custom = DDAvatarImageForUser([self nsUsrName]);
    if (custom) DDJokerHit(@"头像替换·updateHeadImage");
    %orig(custom ?: image);
}

// 设置用户名 + 头像地址时补一次，避免首屏没走到 updateHeadImage:。
- (void)updateUsrName:(id)usrName withHeadImgUrl:(id)headImgUrl {
    %orig(usrName, headImgUrl);
    UIImage *custom = DDAvatarImageForUser(usrName ?: [self nsUsrName]);
    if (custom) {
        DDJokerHit(@"头像替换·updateUsrName");
        [self updateHeadImage:custom];
    }
}

// 网络头像异步下载完成会走这里，不拦的话本地图会被真头像盖掉。
- (void)ImageDidLoad:(id)image Url:(id)url {
    %orig(image, url);
    UIImage *custom = DDAvatarImageForUser([self nsUsrName]);
    if (custom) {
        DDJokerHit(@"头像替换·ImageDidLoad");
        [self updateHeadImage:custom];
    }
}

// ——— 下面这批是联系人资料页(CBaseContactInfoAssist.m_headView)走的入口 ———
// 资料页不调 updateUsrName:withHeadImgUrl:，而是按用户名直接取图，
// 所以原来三个入口拦不到它。逐个补上，命中的那个会在日志里显形。

- (id)initWithUsrName:(id)usrName headImgUrl:(id)headImgUrl bAutoUpdate:(BOOL)bAuto bRoundCorner:(BOOL)bRound {
    id ret = %orig(usrName, headImgUrl, bAuto, bRound);
    DDJokerHit(@"头像入口·init");
    DDTryApplyCustomAvatar(ret, usrName, @"头像替换·initWithUsrName");
    return ret;
}

- (void)setHeadImageByName:(id)usrName {
    %orig(usrName);
    DDJokerHit(@"头像入口·setHeadImageByName");
    DDTryApplyCustomAvatar(self, usrName, @"头像替换·setHeadImageByName");
}

- (void)doUpdateHeadImg:(BOOL)force {
    %orig(force);
    DDJokerHit(@"头像入口·doUpdateHeadImg");
    DDTryApplyCustomAvatar(self, nil, @"头像替换·doUpdateHeadImg");
}

- (void)onHeadImageChange:(id)arg1 {
    %orig(arg1);
    DDJokerHit(@"头像入口·onHeadImageChange");
    DDTryApplyCustomAvatar(self, nil, @"头像替换·onHeadImageChange");
}

- (void)onModifyContact:(id)arg1 {
    %orig(arg1);
    DDJokerHit(@"头像入口·onModifyContact");
    DDTryApplyCustomAvatar(self, nil, @"头像替换·onModifyContact");
}

// 终极兜底：视图挂到 window 时再确认一次。覆盖所有上面没列出的入口，
// 以及「图在 hook 生效前就设好、之后不再刷新」的情况。有缓存，开销可忽略。
- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    DDSampleAvatarName(self.nsUsrName);
    DDTryApplyCustomAvatar(self, nil, @"头像替换·didMoveToWindow");
}

%end


#pragma mark - 头像修改入口（单聊「聊天信息」页）


static NSString *const kDDAvatarCellId = @"DDProfileAvatarCell";

%hook AddContactToChatRoomViewController

// 日志实证本版本只在 viewWillAppear 时构建完表格，reloadTableData 从未被微信主动调用，
// 故只保留这一个入口（不再留 reloadTableData 兜底）；入口名进日志便于定位实际走的是哪条路。
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self dd_injectAvatarCellFrom:@"viewWillAppear"];
}

%new
- (void)dd_injectAvatarCellFrom:(NSString *)entry {
    DDProfileConfig *cfg = [DDProfileConfig shared];
    NSString *vcDesc = [NSString stringWithFormat:@"%@(%p)", NSStringFromClass([self class]), self];

    // 全局总开关关闭时不注入聊天详情页入口。
    if (!cfg.avatarEnabled) {
        DDLOG(@"[头像·注入] 入口=%@ 跳过：总开关未开  VC=%@", entry, vcDesc);
        return;
    }

    CContact *contact = [self m_contact];
    if (!contact) {
        DDLOG(@"[头像·注入] 入口=%@ 跳过：m_contact 为空  VC=%@", entry, vcDesc);
        return;
    }
    // 群聊不支持，直接跳过。
    if ([contact isChatroom]) {
        DDLOG(@"[头像·注入] 入口=%@ 跳过：群聊  VC=%@", entry, vcDesc);
        return;
    }

    NSString *usrName = [contact m_nsUsrName];
    if (usrName.length == 0) {
        DDLOG(@"[头像·注入] 入口=%@ 跳过：usrName 为空  VC=%@", entry, vcDesc);
        return;
    }

    WCTableViewManager *info = nil;
    @try {
        info = (WCTableViewManager *)[self valueForKey:@"m_tableViewInfo"];
    } @catch (NSException *e) {
        info = nil;
    }
    if (!info) {
        DDLOG(@"[头像·注入] 入口=%@ 跳过：m_tableViewInfo 取不到  VC=%@", entry, vcDesc);
        return;
    }

    // 详情页第一个分组：把「自定义头像」开关作为它的首行插入。
    id firstSection = nil;
    @try {
        firstSection = [info getSectionAt:0];
    } @catch (NSException *e) {
        firstSection = nil;
    }
    if (!firstSection) {
        DDLOG(@"[头像·注入] 入口=%@ 跳过：首分组为空(sectionCount=%llu)  VC=%@",
              entry, [info getSectionCount], vcDesc);
        return;
    }

    // 已注入则跳过（每次 reloadTableData 都会走到，靠 cell 的 userInfo 去重）。
    NSArray *cells = [firstSection respondsToSelector:@selector(getAllCells)] ? [firstSection getAllCells] : nil;
    for (id c in cells) {
        if ([[c userInfo] isEqual:kDDAvatarCellId]) {
            DDLOG(@"[头像·注入] 入口=%@ 跳过：已注入过  user=%@", entry, usrName);
            return;
        }
    }

    // 自建 UISwitch：日志实证微信 switchCellForSel:target:title:on: 的 sel 在本版本不回调
    // （开关能显示、能滑动，但「头像开关点击」从未命中），故改用 normalCellForSel + 自定义
    // UISwitch，用 addTarget 直接绑定 action，确保点击一定触发。
    // 视觉上微信原生 switch cell 右侧也是 UISwitch，样式一致；sel 传 nil 避免整行出现箭头。
    Class cellCls = %c(WCTableViewCellManager);
    BOOL hasCustom = DDAvatarImageForUser(usrName) != nil;

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 51, 31)];
    sw.on = hasCustom;
    [sw addTarget:self action:@selector(ddAvatarSwitchChanged:) forControlEvents:UIControlEventValueChanged];

    id cell = [cellCls normalCellForSel:nil
                                 target:nil
                                  title:@"自定义头像"
                               rightView:sw];
    if (!cell) {
        DDLOG(@"[头像·注入] 入口=%@ 失败：cell 创建返回 nil  user=%@", entry, usrName);
        return;
    }
    [cell setUserInfo:kDDAvatarCellId];
    [firstSection insertCell:cell At:0];
    [info reloadTableView];

    DDLOG(@"[头像·注入] 入口=%@ 成功：已插入首分组第0行  user=%@  已有图=%d  首分组原行数=%lu",
          entry, usrName, hasCustom, (unsigned long)cells.count);
    DDJokerHit(@"头像开关创建");
}

// 开关 action：必须用 %new 显式添加，不能 %hook toggleCustomContactAvatar:。
//   该方法虽在 dump 头文件(AddContactToChatRoomViewController.h:66)里有声明，但未必真实存在于
//   当前微信——它可能是别的历史插件注入的。%hook 对不存在的方法不会兜底添加，
//   于是 addTarget 绑定后一点击就 unrecognized selector 崩溃（实测闪退）。
//   故改为 %new 自有方法，由 Logos 保证一定被添加进类。
// 参数由 UISwitch 的 ValueChanged 传入，但这里不依赖它判断状态，
//   改以「当前联系人是否已有本地头像」决定开/关。
%new
- (void)ddAvatarSwitchChanged:(UISwitch *)sender {
    CContact *contact = [self m_contact];
    NSString *usrName = [contact m_nsUsrName];
    if (usrName.length == 0) {
        DDLOG(@"[头像·开关] 跳过：usrName 为空");
        return;
    }
    DDJokerHit(@"头像开关点击");
    DDLOG(@"[头像·开关] 点击 user=%@  参数类型=%@  on=%d", usrName,
          sender ? NSStringFromClass([sender class]) : @"(nil)", sender ? (int)sender.isOn : -1);

    if (DDAvatarImageForUser(usrName)) {
        // 当前有图 -> 切换为关闭，删除本地图片。
        BOOL ok = DDAvatarRemoveForUser(usrName);
        DDLOG(@"[头像·开关] 关闭：删除本地图 user=%@  结果=%d", usrName, ok);
        DDShowDoneToast(@"已恢复默认头像");
    } else {
        // 当前无图 -> 切换为打开，调起相册选图并裁剪。
        DDLOG(@"[头像·开关] 打开：准备调起相册 user=%@", usrName);
        __weak typeof(self) weakSelf = self;
        __weak UISwitch *weakSw = sender;
        [DDAvatarPicker presentFromViewController:self completion:^(UIImage *image) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (!image) {
                DDLOG(@"[头像·开关] 选图取消或取图失败 user=%@", usrName);
                // 直接把开关弹回 off：不依赖表格重建（该 VC 的 reloadTableData 未必重建分组）。
                [weakSw setOn:NO animated:YES];
                return;
            }
            if (!DDAvatarSaveImage(image, usrName)) {
                DDLOG(@"[头像·开关] 保存失败 user=%@  图片尺寸=%@", usrName, NSStringFromCGSize(image.size));
                DDShowErrorToast(@"保存失败");
                [weakSw setOn:NO animated:YES];
            } else {
                DDLOG(@"[头像·开关] 保存成功 user=%@  图片尺寸=%@", usrName, NSStringFromCGSize(image.size));
                DDShowDoneToast(@"头像已替换");
                [strongSelf reloadTableData];
            }
        }];
    }
}

%end


#pragma mark - 设置页


@interface DDProfileSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
- (void)buildTable;
- (void)rebuild;
- (UIView *)inputRowWithField:(UITextField *)field
                       action:(SEL)action
                  placeholder:(NSString *)placeholder
                         text:(NSString *)text
                     keyboard:(UIKeyboardType)keyboard;
- (UIButton *)dd_actionButton:(NSString *)title action:(SEL)action x:(CGFloat)x;
- (void)wxidSwitchChanged:(id)sender;
- (void)wxidConfirm:(id)sender;
- (void)avatarSwitchChanged:(id)sender;
- (void)clearAllAvatarTapped:(id)sender;
- (void)diagSwitchChanged:(id)sender;
- (void)clearDiagLogTapped:(id)sender;
- (void)exportDiagLogTapped:(id)sender;
- (void)dd_showDoneToast:(NSString *)text;
- (void)dd_showErrorToast:(NSString *)text;
@end

@implementation DDProfileSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
    UITextField *_wxidField;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"小丑资料设置";

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;

    _tableViewManager = [(WCTableViewManager *)[%c(WCTableViewManager) alloc] initWithFrame:[[UIScreen mainScreen] bounds]
                                                                                     style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:_tableViewManager.tableView];

    // 接管 delegate 后再转发给微信原生 manager，用于处理子行缩进（与主插件同款写法）。
    _originalDelegate = _tableViewManager.delegate;
    _tableViewManager.delegate = self;

    [self buildTable];
}

// 表视图委托转发：保持微信原生行为，只额外处理带 SubCell 标记的子行缩进。
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    WCTableViewCellManager *cellInfo = [_tableViewManager cellInfoAtIndexPath:indexPath];
    if ([cellInfo.userInfo isEqual:@"SubCell"]) {
        cell.indentationLevel = 1;
        cell.indentationWidth = 16.0;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
        return [_originalDelegate tableView:tableView heightForRowAtIndexPath:indexPath];
    }
    return UITableViewAutomaticDimension;
}

- (UIView *)inputRowWithField:(UITextField *)field
                       action:(SEL)action
                  placeholder:(NSString *)placeholder
                         text:(NSString *)text
                     keyboard:(UIKeyboardType)keyboard {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 34)];
    container.backgroundColor = [UIColor clearColor];

    field.frame = CGRectMake(0, 0, 160, 34);
    field.borderStyle = UITextBorderStyleNone;
    field.placeholder = placeholder;
    field.text = text;
    field.textAlignment = NSTextAlignmentRight;
    field.keyboardType = keyboard;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.backgroundColor = [UIColor systemGray5Color];
    field.layer.cornerRadius = 6.0;
    field.layer.masksToBounds = YES;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
    field.leftViewMode = UITextFieldViewModeAlways;
    field.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
    field.rightViewMode = UITextFieldViewModeAlways;
    [container addSubview:field];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(168, 0, 52, 34);
    [btn setTitle:@"确认" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor systemGray5Color];
    btn.layer.cornerRadius = 6.0;
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:btn];

    return container;
}

// 带背景的小按钮（参考主插件风格）：放在 cell 右侧，不带箭头。
- (UIButton *)dd_actionButton:(NSString *)title action:(SEL)action x:(CGFloat)x {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(x, 0, 52, 34);
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor systemGray5Color];
    btn.layer.cornerRadius = 6.0;
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)buildTable {
    [_tableViewManager clearAllSection];

    DDProfileConfig *cfg = [DDProfileConfig shared];
    Class cellCls = %c(WCTableViewCellManager);

    WCTableViewSectionManager *wxidSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"微信号"];
    wxidSection.footerTitle = @"开启后只改变你自己的微信号显示，不修改服务器数据；关闭开关即恢复真实微信号";
    [wxidSection addCell:[cellCls switchCellForSel:@selector(wxidSwitchChanged:)
                                            target:self
                                             title:@"自定义微信号"
                                                on:cfg.wxidEnabled]];
    if (cfg.wxidEnabled) {
        _wxidField = [[UITextField alloc] init];
        UIView *right = [self inputRowWithField:_wxidField
                                        action:@selector(wxidConfirm:)
                                   placeholder:@"例如：wxid_abc123"
                                          text:cfg.wxidValue ?: @""
                                      keyboard:UIKeyboardTypeASCIICapable];
        // 打上 SubCell 标记，tableView:willDisplayCell: 里据此缩进，与主插件子行样式一致。
        WCTableViewCellManager *wxidSubCell = [cellCls normalCellForSel:nil
                                                               target:nil
                                                                title:@"↳目标微信号"
                                                            rightView:right];
        wxidSubCell.userInfo = @"SubCell";
        [wxidSection addCell:wxidSubCell];
    }
    [_tableViewManager addSection:wxidSection];

    WCTableViewSectionManager *avatarSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"自定义用户头像"];
    avatarSection.footerTitle = @"开启后可在单聊「聊天信息」页替换联系人头像；关闭后不再显示替换入口，也不替换头像";
    [avatarSection addCell:[cellCls switchCellForSel:@selector(avatarSwitchChanged:)
                                               target:self
                                                title:@"备注用户头像"
                                                   on:cfg.avatarEnabled]];
    // 清理按钮放进右侧容器：cell 的 sel 传 nil，避免整行出现微信原生的跳转箭头。
    UIButton *clearBtn = [self dd_actionButton:@"清理" action:@selector(clearAllAvatarTapped:) x:0];
    UIView *clearRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 52, 34)];
    [clearRight addSubview:clearBtn];
    [avatarSection addCell:[cellCls normalCellForSel:nil
                                              target:nil
                                               title:@"一键全部还原"
                                           rightView:clearRight]];
    [_tableViewManager addSection:avatarSection];

    WCTableViewSectionManager *diagSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"诊断日志"];
    diagSection.footerTitle = @"默认仅在插件启动时记录一条。排查问题时打开「记录运行日志」，复现后点下方「导出日志」即可";
    [diagSection addCell:[cellCls switchCellForSel:@selector(diagSwitchChanged:)
                                            target:self
                                             title:@"记录运行日志"
                                                on:cfg.diagEnabled]];
    UIButton *exportBtn = [self dd_actionButton:@"导出" action:@selector(exportDiagLogTapped:) x:0];
    UIButton *logClearBtn = [self dd_actionButton:@"清空" action:@selector(clearDiagLogTapped:) x:60];
    UIView *logRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 112, 34)];
    [logRight addSubview:exportBtn];
    [logRight addSubview:logClearBtn];
    [diagSection addCell:[cellCls normalCellForSel:nil target:nil title:@"导出日志" rightView:logRight]];
    [_tableViewManager addSection:diagSection];

    [_tableViewManager reloadTableView];
}

- (void)wxidSwitchChanged:(id)sender {
    UISwitch *sw = (UISwitch *)sender;
    [DDProfileConfig shared].wxidEnabled = sw.on;
    [self rebuild];
}

- (void)wxidConfirm:(id)sender {
    NSString *text = [_wxidField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [DDProfileConfig shared].wxidValue = text;
    [_wxidField resignFirstResponder];
    [self dd_showDoneToast:(text.length ? @"已保存" : @"已清空")];
    [self rebuild];
}

- (void)avatarSwitchChanged:(id)sender {
    UISwitch *sw = (UISwitch *)sender;
    [DDProfileConfig shared].avatarEnabled = sw.on;
    [self rebuild];
}

- (void)clearAllAvatarTapped:(id)sender {
    NSInteger n = DDAvatarRemoveAll();
    // 提示统一为「已清理」（与主插件一致）；清除了几个只在日志里记。
    DDLOG(@"[头像·清理] 一键全部还原：清除 %ld 个", (long)n);
    [self dd_showDoneToast:@"已清理"];
}

- (void)diagSwitchChanged:(id)sender {
    UISwitch *sw = (UISwitch *)sender;
    [DDProfileConfig shared].diagEnabled = sw.on;
    if (sw.on) DDLOG(@"[诊断] 日志开关已打开");
    [self rebuild];
}

- (void)clearDiagLogTapped:(id)sender {
    DDProfileClearDiagLog();
    [self dd_showDoneToast:@"日志已清空"];
}

- (void)exportDiagLogTapped:(id)sender {
    NSString *path = DDProfileExportDiagLog();
    if (!path.length) {
        [self dd_showErrorToast:@"导出失败"];
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:path];
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if (av.popoverPresentationController) {
        UIView *anchor = [sender isKindOfClass:[UIView class]] ? (UIView *)sender : self.view;
        av.popoverPresentationController.sourceView = anchor;
        av.popoverPresentationController.sourceRect = anchor.bounds;
    }
    __weak typeof(self) weakSelf = self;
    av.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *error) {
        [weakSelf dd_showDoneToast:(completed ? @"日志已导出" : @"已取消")];
    };
    [self presentViewController:av animated:YES completion:nil];
}

// toast 出口与主插件同名同形：内部转发到全局函数，hook 内部也用同一套提示。
- (void)dd_showDoneToast:(NSString *)text {
    DDShowDoneToast(text);
}

- (void)dd_showErrorToast:(NSString *)text {
    DDShowErrorToast(text);
}

// 与主插件一致：开关 / 输入变化后只重建表格内容（buildTable 内部 clearAllSection），
// 不重建 manager —— 既避免 tableView 被反复移除重建，也不会弄丢接管后的 delegate 转发。
- (void)rebuild {
    [self buildTable];
}

@end


#pragma mark - 配置实现


@implementation DDProfileConfig

+ (instancetype)shared {
    static DDProfileConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ config = [DDProfileConfig new]; });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        _wxidEnabled = [def boolForKey:kDDWxidEnabledKey];
        _wxidValue = [def stringForKey:kDDWxidValueKey] ?: @"";
        _avatarEnabled = [def boolForKey:kDDAvatarEnabledKey];
        // 日志默认关闭，与功能开关默认值保持一致的处理：没存过就是 NO。
        _diagEnabled = [def objectForKey:kDDDiagEnabledKey] ? [def boolForKey:kDDDiagEnabledKey] : NO;
    }
    return self;
}

- (void)setWxidEnabled:(BOOL)wxidEnabled {
    _wxidEnabled = wxidEnabled;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setBool:wxidEnabled forKey:kDDWxidEnabledKey];
    [def synchronize];
}

- (void)setWxidValue:(NSString *)wxidValue {
    _wxidValue = wxidValue ?: @"";
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setObject:_wxidValue forKey:kDDWxidValueKey];
    [def synchronize];
}

- (void)setAvatarEnabled:(BOOL)avatarEnabled {
    _avatarEnabled = avatarEnabled;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setBool:avatarEnabled forKey:kDDAvatarEnabledKey];
    [def synchronize];
}

- (void)setDiagEnabled:(BOOL)diagEnabled {
    _diagEnabled = diagEnabled;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setBool:diagEnabled forKey:kDDDiagEnabledKey];
    [def synchronize];
}

@end


#pragma mark - 插件注册


%ctor {
    @autoreleasepool {
        WCPluginsMgr *mgr = [%c(WCPluginsMgr) sharedInstance];
        [mgr registerControllerWithTitle:@"DD小丑资料"
                                 version:@"1.0.0"
                              controller:@"DDProfileSettingsViewController"];
        DDLOG(@"=== 插件加载 ===");
        DDJokerHit(@"插件加载");
    }
}
