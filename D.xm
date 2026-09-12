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
//    入口：单聊「聊天信息」页(AddContactToChatRoomViewController)底部注入一行操作区。
//      该 VC 的表格是 MMTableViewInfo，它继承 WCTableViewManager(MMTableViewInfo.h:1)，
//      所以直接复用 WCTableViewSectionManager / WCTableViewCellManager 建行。
//    存储：Documents/DDAvatar/<userName>.png，按用户名一一对应，不额外维护映射表。
//    显示：hook MMHeadImageView 的三个写图入口，命中本地图就替换
//      updateHeadImage:            (MMHeadImageView.h:66)
//      updateUsrName:withHeadImgUrl: (MMHeadImageView.h:54)
//      ImageDidLoad:Url:           (MMHeadImageView.h:68，异步下载完成后会覆盖，必须拦)
//    限制：不支持群聊，命中 [CBaseContact isChatroom] 直接跳过注入(CBaseContact.h:129)。
// ============================================================


#pragma mark - 微信类声明
// 本插件 hook 的微信原生类与方法签名，均锚定微信 .h 头文件 dump。


@interface WeToast : NSObject
+ (id)toast;
- (void)showDoneToastWithText:(id)a0;
- (void)showErrorToastWithText:(id)a0;
@end

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightValue:(id)rightValue;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightView:(id)rightView;
@property (nonatomic, retain) id userInfo;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(NSString *)header;
+ (id)sectionWithFooter:(NSString *)footer;
+ (id)sectionWithHeader:(NSString *)header Footer:(NSString *)footer;
@property (nonatomic, copy) NSString *footerTitle;
@property (nonatomic, retain) id userInfo;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(long long)style;
@property (retain, nonatomic) UITableView *tableView;
- (void)addSection:(id)arg1;
- (unsigned long long)getSectionCount;
- (id)getSectionAt:(unsigned long long)a0;
- (id)getAllSections;
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
@interface MMHeadImageView : UIView
@property (readonly, nonatomic) NSString *nsUsrName;
- (void)updateHeadImage:(id)image;
- (void)updateUsrName:(id)usrName withHeadImgUrl:(id)headImgUrl;
- (void)ImageDidLoad:(id)image Url:(id)url;
@end

// 单聊「聊天信息」页。m_contact 是当前联系人(AddContactToChatRoomViewController.h:24)。
// 下面三个 dd_ 前缀方法是本插件 %new 注入的，先声明以便 hook 内互相调用。
@interface AddContactToChatRoomViewController : UIViewController
@property (retain, nonatomic) CContact *m_contact;
- (void)reloadTableData;
- (void)dd_injectAvatarSectionIfNeeded;
- (void)dd_pickAvatarTapped:(id)sender;
- (void)dd_resetAvatarTapped:(id)sender;
@end


#pragma mark - 配置


static NSString *const kDDWxidEnabledKey = @"DDProfileWxidEnabled";
static NSString *const kDDWxidValueKey   = @"DDProfileWxidValue";

@interface DDProfileConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL wxidEnabled;
@property (nonatomic, copy) NSString *wxidValue;
@end


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

static UIImage *DDAvatarImageForUser(NSString *usrName) {
    NSString *path = DDAvatarPathForUser(usrName);
    if (!path) return nil;
    UIImage *img = [UIImage imageWithContentsOfFile:path];
    return (img && img.size.width > 0 && img.size.height > 0) ? img : nil;
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
    return [data writeToFile:path atomically:YES];
}

static BOOL DDAvatarRemoveForUser(NSString *usrName) {
    NSString *path = DDAvatarPathForUser(usrName);
    if (!path) return NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return NO;
    return [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

static NSInteger DDAvatarRemoveAll(void) {
    NSString *dir = DDAvatarDir();
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    NSInteger n = 0;
    for (NSString *f in files) {
        if (![f.pathExtension isEqualToString:@"png"]) continue;
        if ([[NSFileManager defaultManager] removeItemAtPath:[dir stringByAppendingPathComponent:f] error:nil]) n++;
    }
    return n;
}


#pragma mark - 相册选图
// 独立代理对象：不往微信 VC 上加 %new 的同名 delegate 方法，避免和微信自身或其它插件的
// imagePickerController:didFinishPickingMediaWithInfo: 撞车(AddContactToChatRoomViewController.h:76)。


typedef void (^DDAvatarPickCompletion)(UIImage *image);

@interface DDAvatarPicker : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) DDAvatarPickCompletion completion;
+ (void)presentFromViewController:(UIViewController *)vc completion:(DDAvatarPickCompletion)completion;
@end

@implementation DDAvatarPicker

// 强引用持有，否则 picker 弹出期间代理被释放、回调收不到。
static DDAvatarPicker *gDDAvatarPicker = nil;

+ (void)presentFromViewController:(UIViewController *)vc completion:(DDAvatarPickCompletion)completion {
    if (!vc) return;
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        if (completion) completion(nil);
        return;
    }
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = YES;

    DDAvatarPicker *proxy = [[DDAvatarPicker alloc] init];
    proxy.completion = completion;
    picker.delegate = proxy;
    gDDAvatarPicker = proxy;

    [vc presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *img = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    DDAvatarPickCompletion cb = self.completion;
    [picker dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(img);
        gDDAvatarPicker = nil;
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    DDAvatarPickCompletion cb = self.completion;
    [picker dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(nil);
        gDDAvatarPicker = nil;
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
    if (custom) return custom;
    return %orig;
}

%end

%hook CBaseContact

- (id)m_nsAliasName {
    NSString *custom = DDCustomWxid();
    if (custom && [self isSelf]) return custom;
    return %orig;
}

%end


#pragma mark - 头像替换（显示侧）


%hook MMHeadImageView

// 同步写图入口：命中本地图就直接换成本地图，不再显示网络头像。
- (void)updateHeadImage:(id)image {
    UIImage *custom = DDAvatarImageForUser([self nsUsrName]);
    %orig(custom ?: image);
}

// 设置用户名 + 头像地址时补一次，避免首屏没走到 updateHeadImage:。
- (void)updateUsrName:(id)usrName withHeadImgUrl:(id)headImgUrl {
    %orig(usrName, headImgUrl);
    UIImage *custom = DDAvatarImageForUser(usrName ?: [self nsUsrName]);
    if (custom) [self updateHeadImage:custom];
}

// 网络头像异步下载完成会走这里，不拦的话本地图会被真头像盖掉。
- (void)ImageDidLoad:(id)image Url:(id)url {
    %orig(image, url);
    UIImage *custom = DDAvatarImageForUser([self nsUsrName]);
    if (custom) [self updateHeadImage:custom];
}

%end


#pragma mark - 头像修改入口（单聊「聊天信息」页）


static NSString *const kDDAvatarSectionId = @"DDProfileAvatarSection";

%hook AddContactToChatRoomViewController

// 表格重建后注入，靠 userInfo 标记去重，避免 reload 多次重复插行。
- (void)reloadTableData {
    %orig;
    [self dd_injectAvatarSectionIfNeeded];
}

%new
- (void)dd_injectAvatarSectionIfNeeded {
    CContact *contact = [self m_contact];
    if (!contact) return;
    // 群聊不支持，直接跳过。
    if ([contact isChatroom]) return;

    NSString *usrName = [contact m_nsUsrName];
    if (usrName.length == 0) return;

    WCTableViewManager *info = nil;
    @try {
        info = (WCTableViewManager *)[self valueForKey:@"m_tableViewInfo"];
    } @catch (NSException *e) {
        info = nil;
    }
    if (!info) return;

    for (id sec in [info getAllSections]) {
        if ([[sec userInfo] isEqual:kDDAvatarSectionId]) return;
    }

    WCTableViewSectionManager *section = [%c(WCTableViewSectionManager) sectionWithHeader:@"小丑 · 头像"];
    section.userInfo = kDDAvatarSectionId;
    section.footerTitle = @"替换后仅本机可见，用于本地伪装；点恢复即删除本地图片、显示原头像";

    UIButton *pickBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    pickBtn.frame = CGRectMake(0, 0, 60, 34);
    [pickBtn setTitle:@"选择" forState:UIControlStateNormal];
    pickBtn.titleLabel.font = [UIFont systemFontOfSize:15];
    [pickBtn addTarget:self action:@selector(dd_pickAvatarTapped:) forControlEvents:UIControlEventTouchUpInside];

    UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    resetBtn.frame = CGRectMake(66, 0, 60, 34);
    [resetBtn setTitle:@"恢复" forState:UIControlStateNormal];
    resetBtn.titleLabel.font = [UIFont systemFontOfSize:15];
    [resetBtn addTarget:self action:@selector(dd_resetAvatarTapped:) forControlEvents:UIControlEventTouchUpInside];

    UIView *right = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 126, 34)];
    [right addSubview:pickBtn];
    [right addSubview:resetBtn];

    [section addCell:[%c(WCTableViewCellManager) normalCellForSel:nil
                                                           target:nil
                                                            title:@"联系人头像"
                                                        rightView:right]];
    [info addSection:section];
    [info reloadTableView];
}

%new
- (void)dd_pickAvatarTapped:(id)sender {
    CContact *contact = [self m_contact];
    NSString *usrName = [contact m_nsUsrName];
    if (usrName.length == 0) return;

    __weak typeof(self) weakSelf = self;
    [DDAvatarPicker presentFromViewController:self completion:^(UIImage *image) {
        if (!image) return;
        if (!DDAvatarSaveImage(image, usrName)) {
            [[%c(WeToast) toast] showErrorToastWithText:@"保存失败"];
            return;
        }
        [[%c(WeToast) toast] showDoneToastWithText:@"头像已替换"];
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) [strongSelf reloadTableData];
    }];
}

%new
- (void)dd_resetAvatarTapped:(id)sender {
    CContact *contact = [self m_contact];
    NSString *usrName = [contact m_nsUsrName];
    if (usrName.length == 0) return;

    if (!DDAvatarRemoveForUser(usrName)) {
        [[%c(WeToast) toast] showDoneToastWithText:@"当前未替换"];
        return;
    }
    [[%c(WeToast) toast] showDoneToastWithText:@"已恢复原头像"];
    [self reloadTableData];
}

%end


#pragma mark - 设置页


@interface DDProfileSettingsViewController : UIViewController
@end

@implementation DDProfileSettingsViewController {
    WCTableViewManager *_tableViewManager;
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

    [self buildTable];
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

- (void)buildTable {
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
        [wxidSection addCell:[cellCls normalCellForSel:nil
                                               target:nil
                                                title:@"↳目标微信号"
                                            rightView:right]];
    }
    [_tableViewManager addSection:wxidSection];

    WCTableViewSectionManager *avatarSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"联系人头像"];
    avatarSection.footerTitle = @"进入单聊的「聊天信息」页，在底部「小丑 · 头像」一栏可替换该联系人头像；群聊不支持";
    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(0, 0, 60, 34);
    [clearBtn setTitle:@"清空" forState:UIControlStateNormal];
    clearBtn.titleLabel.font = [UIFont systemFontOfSize:15];
    [clearBtn addTarget:self action:@selector(clearAllAvatarTapped:) forControlEvents:UIControlEventTouchUpInside];
    UIView *clearRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 60, 34)];
    [clearRight addSubview:clearBtn];
    [avatarSection addCell:[cellCls normalCellForSel:nil
                                             target:nil
                                              title:@"已替换的头像"
                                          rightView:clearRight]];
    [_tableViewManager addSection:avatarSection];
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
    [[%c(WeToast) toast] showDoneToastWithText:(text.length ? @"已保存" : @"已清空")];
    [self rebuild];
}

- (void)clearAllAvatarTapped:(id)sender {
    NSInteger n = DDAvatarRemoveAll();
    [[%c(WeToast) toast] showDoneToastWithText:(n > 0 ? [NSString stringWithFormat:@"已清除 %ld 个", (long)n] : @"暂无替换")];
}

- (void)rebuild {
    // 开关 / 输入变化后重建整表：移除旧 tableView，重建 manager 再灌数据。
    for (UIView *v in self.view.subviews) {
        if ([v isKindOfClass:[UITableView class]]) [v removeFromSuperview];
    }
    _tableViewManager = [(WCTableViewManager *)[%c(WCTableViewManager) alloc] initWithFrame:[[UIScreen mainScreen] bounds]
                                                                                     style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:_tableViewManager.tableView];
    [self buildTable];
    [_tableViewManager reloadTableView];
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

@end


#pragma mark - 插件注册


%ctor {
    @autoreleasepool {
        WCPluginsMgr *mgr = [%c(WCPluginsMgr) sharedInstance];
        [mgr registerControllerWithTitle:@"DD小丑资料"
                                 version:@"1.0.0"
                              controller:@"DDProfileSettingsViewController"];
    }
}
