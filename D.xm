#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

static NSString * const kDouyinParserEnabledKey = @"com.wechat.enhance.douyinParser.enabled";

static NSString * const kDouyinParserAPIURL = @"https://api.qsy.ink/api/douyin?key=DYYY&url=";

static NSString * const kDouyinParserMenuTitle = @"解析抖音";

static inline BOOL DYIsEnabled(void) {
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	if ([ud objectForKey:kDouyinParserEnabledKey] == nil) {
		return YES;
	}
	return [ud boolForKey:kDouyinParserEnabledKey];
}

@interface CContact : NSObject
@property (nonatomic, retain) NSString *m_nsUsrName;
@end

@interface CMessageWrap : NSObject
@property (nonatomic, retain) NSString *m_nsContent;
@property (nonatomic, retain) NSString *m_nsFromUsr;
@property (nonatomic, retain) NSString *m_nsToUsr;
@property (nonatomic, assign) unsigned int m_uiMesLocalID;
@property (nonatomic, assign) long long m_n64MesSvrID;
+ (BOOL)isSenderFromMsgWrap:(id)msgWrap;
@end

@interface CaptureVideoInfo : NSObject
+ (id)genVideoInfoWithVideoUrl:(id)videoUrl thumb:(id)thumb;
- (void)setVideo_path:(id)path;
- (void)setThumb_path:(id)path;
- (void)setVideo_size:(unsigned int)size;
- (void)setVideo_time:(unsigned int)time;
- (void)setVideo_width:(unsigned int)width;
- (void)setVideo_height:(unsigned int)height;
- (void)setThumb_size:(unsigned int)size;
- (void)setM_videoCreateTime:(unsigned int)createTime;
- (void)setM_uiIsSenderStatus:(unsigned int)senderStatus;
- (void)setM_nsSpecifiedChatName:(id)chatName;
@end

@interface CMessageMgr : NSObject
- (id)AddVideoMsg:(id)fromUser ToUsr:(id)toUsr VideoInfo:(id)videoInfo;
- (id)AddVideoMsg:(id)fromUser ToUsr:(id)toUsr VideoInfo:(id)videoInfo MsgType:(unsigned int)msgType;
@end

@interface SendMessageMgr : NSObject
- (unsigned long long)GetCountOfSendMessage;
@end

@interface MMContext : NSObject
+ (id)activeUserContext;
- (id)getService:(Class)cls;
@end

@interface CContactMgr : NSObject
- (id)getSelfContact;
@end

@interface MMMenuItem : NSObject
- (id)initWithTitle:(id)title target:(id)target action:(SEL)action;
- (id)initWithTitle:(id)title icon:(id)icon target:(id)target action:(SEL)action;
- (SEL)action;
- (void)setIconImage:(id)iconImage;
@end

@interface WeToast : NSObject
+ (id)toast;
- (void)showToastWithText:(id)text;
- (void)showErrorToastWithText:(id)text;
@end

@interface BaseMsgContentLogicController : NSObject
- (void)AddVideoMsg:(id)fromUser ToUsr:(id)toUsr VideoInfo:(id)videoInfo;
@end

@interface BaseMsgContentViewController : NSObject
- (id)GetContact;
- (id)getCurrentChatName;
- (id)m_logicController;
@end

@interface TextMessageCellView : NSObject
- (id)operationMenuItems;
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender;
- (id)getCurrentMessageWrap;
- (id)getMediaWrap;
- (id)getViewController;
@end

@interface TextMessageCellView (WCDouyinParserAction)
- (void)wcpl_handleDouyinParseMenuItem:(id)sender;
@end

static NSString *DYTrim(NSString *text) {
	if (![text isKindOfClass:[NSString class]]) {
		return @"";
	}
	return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *DYSanitizeCandidate(NSString *candidate) {
	NSString *value = DYTrim(candidate);
	if (value.length == 0) {
		return nil;
	}

	static NSCharacterSet *trailingSet = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSMutableCharacterSet *set = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
		[set addCharactersInString:@"，。！？；：、）】》」』”\"'`"];
		trailingSet = [set copy];
	});

	while (value.length > 0) {
		unichar lastChar = [value characterAtIndex:value.length - 1];
		if (![trailingSet characterIsMember:lastChar]) {
			break;
		}
		value = [value substringToIndex:value.length - 1];
	}
	return DYTrim(value);
}

static NSString *DYNormalizeDouyinURL(NSString *urlString) {
	NSString *candidate = DYSanitizeCandidate(urlString);
	if (candidate.length == 0) {
		return nil;
	}

	NSString *normalized = candidate;
	if ([normalized rangeOfString:@"://"].location == NSNotFound) {
		normalized = [@"https://" stringByAppendingString:normalized];
	}

	NSURLComponents *components = [NSURLComponents componentsWithString:normalized];
	NSString *host = [components.host lowercaseString];
	if (host.length == 0) {
		return nil;
	}

	BOOL isDouyinHost = [host isEqualToString:@"v.douyin.com"] ||
						[host isEqualToString:@"www.douyin.com"] ||
						[host isEqualToString:@"douyin.com"];
	if (!isDouyinHost) {
		return nil;
	}

	NSString *path = [components.path lowercaseString] ?: @"";
	BOOL supportsPath = NO;
	if ([host isEqualToString:@"v.douyin.com"]) {
		supportsPath = (path.length > 1);
	} else {
		supportsPath = [path hasPrefix:@"/video/"];
	}
	if (!supportsPath) {
		return nil;
	}

	return components.string ?: normalized;
}

static NSString *DYExtractDouyinLink(NSString *text) {
	if (![text isKindOfClass:[NSString class]] || text.length == 0) {
		return nil;
	}

	static NSDataDetector *linkDetector = nil;
	static dispatch_once_t detectorOnceToken;
	dispatch_once(&detectorOnceToken, ^{
		NSError *err = nil;
		linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&err];
		if (err) {
			linkDetector = nil;
		}
	});

	if (linkDetector) {
		NSArray<NSTextCheckingResult *> *matches = [linkDetector matchesInString:text options:0 range:NSMakeRange(0, text.length)];
		for (NSTextCheckingResult *match in matches) {
			NSURL *url = match.URL;
			if (![url isKindOfClass:[NSURL class]]) {
				continue;
			}
			NSString *normalized = DYNormalizeDouyinURL(url.absoluteString);
			if (normalized.length > 0) {
				return normalized;
			}
		}
	}

	static NSRegularExpression *regex = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSError *err = nil;
		regex = [NSRegularExpression regularExpressionWithPattern:
				 @"(?i)(?:https?://)?(?:v\\.douyin\\.com/[A-Za-z0-9]+(?:/[A-Za-z0-9]*)?(?:\\?[^\\s\\u3000<>\\\"']*)?|(?:www\\.)?douyin\\.com/video/[A-Za-z0-9]+(?:\\?[^\\s\\u3000<>\\\"']*)?)"
														 options:0
														   error:&err];
		if (err) {
			regex = nil;
		}
	});

	if (!regex) {
		return nil;
	}

	NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
	if (!match || match.range.location == NSNotFound || match.range.length == 0) {
		return nil;
	}

	NSString *candidate = [text substringWithRange:match.range];
	return DYNormalizeDouyinURL(candidate);
}

static NSString *DYNormalizeMediaURL(NSString *urlString) {
	NSString *candidate = DYTrim(urlString);
	if (candidate.length == 0) {
		return nil;
	}
	if ([candidate hasPrefix:@"//"]) {
		candidate = [@"https:" stringByAppendingString:candidate];
	}
	NSURLComponents *components = [NSURLComponents componentsWithString:candidate];
	NSString *scheme = [components.scheme lowercaseString];
	if (!([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) {
		return nil;
	}
	return components.string ?: candidate;
}

static void DYAppendUniqueURL(NSMutableArray<NSString *> *candidates, NSString *candidate) {
	NSString *normalized = DYNormalizeMediaURL(candidate);
	if (normalized.length == 0 || [candidates containsObject:normalized]) {
		return;
	}
	[candidates addObject:normalized];
}

static void DYCollectVideoURLs(id node, NSMutableArray<NSString *> *out, int depth) {
	if (!node || depth > 6 || ![out isKindOfClass:[NSMutableArray class]]) {
		return;
	}

	if ([node isKindOfClass:[NSArray class]]) {
		for (id item in (NSArray *)node) {
			DYCollectVideoURLs(item, out, depth + 1);
		}
		return;
	}

	if (![node isKindOfClass:[NSDictionary class]]) {
		return;
	}

	NSDictionary *dict = (NSDictionary *)node;

	for (NSString *addrKey in @[@"play_addr", @"play_addr_h264", @"download_addr"]) {
		id addr = dict[addrKey];
		if ([addr isKindOfClass:[NSDictionary class]]) {
			NSDictionary *addrDict = (NSDictionary *)addr;
			NSArray *urlList = [addrDict[@"url_list"] isKindOfClass:[NSArray class]] ? addrDict[@"url_list"] : nil;
			for (id item in urlList) {
				if ([item isKindOfClass:[NSString class]]) {
					DYAppendUniqueURL(out, (NSString *)item);
				}
			}
			for (NSString *k in @[@"url", @"play_url", @"download_url"]) {
				if ([addrDict[k] isKindOfClass:[NSString class]]) {
					DYAppendUniqueURL(out, (NSString *)addrDict[k]);
				}
			}
		}
	}

	for (NSString *k in @[@"video_url", @"url", @"play_url", @"download_url"]) {
		if ([dict[k] isKindOfClass:[NSString class]]) {
			DYAppendUniqueURL(out, (NSString *)dict[k]);
		}
	}

	for (NSString *k in @[@"data", @"video", @"bit_rate", @"video_list", @"videos"]) {
		id sub = dict[k];
		if ([sub isKindOfClass:[NSDictionary class]] || [sub isKindOfClass:[NSArray class]]) {
			DYCollectVideoURLs(sub, out, depth + 1);
		}
	}
}

static NSArray<NSString *> *DYExtractVideoURLsFromJSON(id jsonObject) {
	if (![jsonObject isKindOfClass:[NSDictionary class]]) {
		return @[];
	}
	NSMutableArray<NSString *> *candidates = [NSMutableArray array];
	DYCollectVideoURLs(jsonObject, candidates, 0);
	return [candidates copy];
}

static NSString *DYErrorMessageFromJSON(id jsonObject) {
	if (![jsonObject isKindOfClass:[NSDictionary class]]) {
		return nil;
	}
	NSDictionary *dict = (NSDictionary *)jsonObject;
	for (NSString *k in @[@"msg", @"message", @"error", @"detail"]) {
		if ([dict[k] isKindOfClass:[NSString class]]) {
			NSString *s = DYTrim((NSString *)dict[k]);
			if (s.length > 0) {
				return s;
			}
		}
	}
	return nil;
}

static void DYShowToast(NSString *text, BOOL isError) {
	dispatch_async(dispatch_get_main_queue(), ^{
		NSString *message = DYTrim(text);
		if (message.length == 0) {
			return;
		}

		Class toastClass = objc_getClass("WeToast");
		if (toastClass && [toastClass respondsToSelector:@selector(toast)]) {
			id toast = [toastClass toast];
			if (toast) {
				if (isError && [toast respondsToSelector:@selector(showErrorToastWithText:)]) {
					[toast showErrorToastWithText:message];
					return;
				}
				if ([toast respondsToSelector:@selector(showToastWithText:)]) {
					[toast showToastWithText:message];
					return;
				}
			}
		}
	});
}

static id DYGetService(Class cls) {
	if (!cls) {
		return nil;
	}
	Class ctxClass = objc_getClass("MMContext");
	if (!ctxClass || ![ctxClass respondsToSelector:@selector(activeUserContext)]) {
		return nil;
	}
	MMContext *context = [ctxClass activeUserContext];
	if (!context || ![context respondsToSelector:@selector(getService:)]) {
		return nil;
	}
	return [context getService:cls];
}

static NSString *DYCurrentSelfUserName(void) {
	id contactMgr = DYGetService(objc_getClass("CContactMgr"));
	if (!contactMgr || ![contactMgr respondsToSelector:@selector(getSelfContact)]) {
		return nil;
	}
	id selfContact = [contactMgr getSelfContact];
	Class contactClass = objc_getClass("CContact");
	if (!selfContact || !contactClass || ![selfContact isKindOfClass:contactClass]) {
		return nil;
	}
	CContact *c = (CContact *)selfContact;
	return c.m_nsUsrName;
}

static CMessageWrap *DYMessageWrapFromCell(id cell) {
	if (!cell) {
		return nil;
	}
	Class wrapClass = objc_getClass("CMessageWrap");
	if (!wrapClass) {
		return nil;
	}

	if ([cell respondsToSelector:@selector(getCurrentMessageWrap)]) {
		id wrap = [cell getCurrentMessageWrap];
		if ([wrap isKindOfClass:wrapClass]) {
			return (CMessageWrap *)wrap;
		}
	}
	if ([cell respondsToSelector:@selector(getMediaWrap)]) {
		id wrap = [cell getMediaWrap];
		if ([wrap isKindOfClass:wrapClass]) {
			return (CMessageWrap *)wrap;
		}
	}
	return nil;
}

static NSString *DYChatUserNameFromCell(id cell, CMessageWrap *msgWrap) {
	id chatVC = nil;
	if ([cell respondsToSelector:@selector(getViewController)]) {
		chatVC = [cell getViewController];
	}
	if (chatVC && [chatVC respondsToSelector:@selector(getCurrentChatName)]) {
		NSString *name = DYTrim([chatVC getCurrentChatName]);
		if (name.length > 0) {
			return name;
		}
	}
	if (chatVC && [chatVC respondsToSelector:@selector(GetContact)]) {
		id contact = [chatVC GetContact];
		Class contactClass = objc_getClass("CContact");
		if (contact && contactClass && [contact isKindOfClass:contactClass]) {
			NSString *name = DYTrim(((CContact *)contact).m_nsUsrName);
			if (name.length > 0) {
				return name;
			}
		}
	}

	if (msgWrap) {
		BOOL isSender = NO;
		Class wrapClass = objc_getClass("CMessageWrap");
		if (wrapClass && [wrapClass respondsToSelector:@selector(isSenderFromMsgWrap:)]) {
			isSender = (BOOL)[wrapClass isSenderFromMsgWrap:msgWrap];
		}
		NSString *name = DYTrim(isSender ? msgWrap.m_nsToUsr : msgWrap.m_nsFromUsr);
		if (name.length > 0) {
			return name;
		}
		name = DYTrim(msgWrap.m_nsToUsr);
		if (name.length > 0) {
			return name;
		}
		name = DYTrim(msgWrap.m_nsFromUsr);
		if (name.length > 0) {
			return name;
		}
	}
	return nil;
}

static dispatch_queue_t g_douyinSessionQueue = nil;
static NSMutableDictionary<NSString *, NSNumber *> *g_douyinSessionTokenByChat = nil;
static NSMutableDictionary<NSString *, NSMutableArray<NSURLSessionTask *> *> *g_douyinTasksByChat = nil;
static unsigned long long g_douyinSessionSeq = 0;

static void DYInitSessionState(void) {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		g_douyinSessionQueue = dispatch_queue_create("com.wechat.douyin.session", DISPATCH_QUEUE_SERIAL);
		g_douyinSessionTokenByChat = [NSMutableDictionary dictionary];
		g_douyinTasksByChat = [NSMutableDictionary dictionary];
	});
}

static NSString *DYSessionKey(NSString *chatUserName) {
	NSString *chat = DYTrim(chatUserName);
	return chat.length > 0 ? chat : @"__unknown__";
}

static unsigned long long DYBeginSession(NSString *chatUserName) {
	DYInitSessionState();
	NSString *key = DYSessionKey(chatUserName);
	__block unsigned long long token = 0;
	dispatch_sync(g_douyinSessionQueue, ^{
		NSArray<NSURLSessionTask *> *tasks = [g_douyinTasksByChat[key] copy];
		[g_douyinTasksByChat removeObjectForKey:key];
		for (NSURLSessionTask *task in tasks) {
			if ([task isKindOfClass:[NSURLSessionTask class]]) {
				[task cancel];
			}
		}
		g_douyinSessionSeq += 1;
		if (g_douyinSessionSeq == 0) {
			g_douyinSessionSeq = 1;
		}
		token = g_douyinSessionSeq;
		g_douyinSessionTokenByChat[key] = @(token);
	});
	return token;
}

static BOOL DYIsSessionActive(NSString *chatUserName, unsigned long long token) {
	if (token == 0) {
		return NO;
	}
	DYInitSessionState();
	NSString *key = DYSessionKey(chatUserName);
	__block BOOL active = NO;
	dispatch_sync(g_douyinSessionQueue, ^{
		active = ([g_douyinSessionTokenByChat[key] unsignedLongLongValue] == token);
	});
	return active;
}

static void DYRegisterTask(NSString *chatUserName, unsigned long long token, NSURLSessionTask *task) {
	if (!task || token == 0) {
		return;
	}
	DYInitSessionState();
	NSString *key = DYSessionKey(chatUserName);
	dispatch_sync(g_douyinSessionQueue, ^{
		if ([g_douyinSessionTokenByChat[key] unsignedLongLongValue] != token) {
			[task cancel];
			return;
		}
		NSMutableArray<NSURLSessionTask *> *tasks = g_douyinTasksByChat[key];
		if (![tasks isKindOfClass:[NSMutableArray class]]) {
			tasks = [NSMutableArray array];
			g_douyinTasksByChat[key] = tasks;
		}
		[tasks addObject:task];
	});
}

static void DYUnregisterTask(NSString *chatUserName, unsigned long long token, NSURLSessionTask *task) {
	if (!task || token == 0) {
		return;
	}
	DYInitSessionState();
	NSString *key = DYSessionKey(chatUserName);
	dispatch_sync(g_douyinSessionQueue, ^{
		NSMutableArray<NSURLSessionTask *> *tasks = g_douyinTasksByChat[key];
		if (![tasks isKindOfClass:[NSMutableArray class]] || tasks.count == 0) {
			[g_douyinTasksByChat removeObjectForKey:key];
			return;
		}
		[tasks removeObject:task];
		if (tasks.count == 0) {
			[g_douyinTasksByChat removeObjectForKey:key];
		}
	});
}

static void DYFinishSession(NSString *chatUserName, unsigned long long token) {
	if (token == 0) {
		return;
	}
	DYInitSessionState();
	NSString *key = DYSessionKey(chatUserName);
	dispatch_sync(g_douyinSessionQueue, ^{
		if ([g_douyinSessionTokenByChat[key] unsignedLongLongValue] != token) {
			return;
		}
		[g_douyinSessionTokenByChat removeObjectForKey:key];
		NSArray<NSURLSessionTask *> *tasks = [g_douyinTasksByChat[key] copy];
		[g_douyinTasksByChat removeObjectForKey:key];
		for (NSURLSessionTask *task in tasks) {
			if ([task isKindOfClass:[NSURLSessionTask class]]) {
				[task cancel];
			}
		}
	});
}

static NSString *DYTempRootDirectory(void) {
	NSString *tmp = NSTemporaryDirectory();
	if (![tmp isKindOfClass:[NSString class]] || tmp.length == 0) {
		tmp = @"/tmp";
	}
	return [tmp stringByAppendingPathComponent:@"wcpl_douyin_parser"];
}

static NSString *DYCreateWorkingDirectory(void) {
	NSString *root = DYTempRootDirectory();
	NSString *uuid = [[NSUUID UUID] UUIDString] ?: [NSString stringWithFormat:@"%u", arc4random()];
	NSString *workDir = [root stringByAppendingPathComponent:uuid];

	NSFileManager *fm = [NSFileManager defaultManager];
	NSError *err = nil;
	[fm createDirectoryAtPath:workDir withIntermediateDirectories:YES attributes:nil error:&err];
	if (err) {
		return nil;
	}
	return workDir;
}

static void DYCleanupPathsAfterDelay(NSArray<NSString *> *paths, NSTimeInterval delay) {
	NSArray<NSString *> *safePaths = [paths isKindOfClass:[NSArray class]] ? paths : @[];
	if (safePaths.count == 0) {
		return;
	}
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(0.0, delay) * NSEC_PER_SEC)),
				   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
				   ^{
		NSFileManager *fm = [NSFileManager defaultManager];
		for (NSString *path in safePaths) {
			NSString *trimmed = DYTrim(path);
			if (trimmed.length == 0 || ![fm fileExistsAtPath:trimmed]) {
				continue;
			}
			[fm removeItemAtPath:trimmed error:nil];
		}
	});
}

static BOOL DYWriteFallbackThumb(NSString *thumbPath) {
	if (thumbPath.length == 0) {
		return NO;
	}
	CGSize size = CGSizeMake(360, 640);
	UIGraphicsBeginImageContextWithOptions(size, YES, 1.0);
	[[UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0] setFill];
	UIRectFill(CGRectMake(0, 0, size.width, size.height));
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	NSData *jpeg = UIImageJPEGRepresentation(image, 0.75);
	return ([jpeg isKindOfClass:[NSData class]] && jpeg.length > 0 && [jpeg writeToFile:thumbPath atomically:YES]);
}

static NSString *DYGenerateThumbForVideo(NSString *videoPath, NSString *workDir) {
	if (videoPath.length == 0 || workDir.length == 0) {
		return nil;
	}
	NSString *thumbPath = [workDir stringByAppendingPathComponent:@"thumb.jpg"];

	AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:videoPath] options:nil];
	AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
	generator.appliesPreferredTrackTransform = YES;
	generator.maximumSize = CGSizeMake(720, 720);

	NSError *error = nil;
	CMTime time = CMTimeMakeWithSeconds(0.1, 600);
	CGImageRef frame = [generator copyCGImageAtTime:time actualTime:NULL error:&error];
	if (!frame) {
		frame = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:&error];
	}

	BOOL wrote = NO;
	if (frame) {
		UIImage *image = [UIImage imageWithCGImage:frame];
		CGImageRelease(frame);
		NSData *jpeg = UIImageJPEGRepresentation(image, 0.82);
		wrote = ([jpeg isKindOfClass:[NSData class]] && jpeg.length > 0 && [jpeg writeToFile:thumbPath atomically:YES]);
	}
	if (!wrote) {
		wrote = DYWriteFallbackThumb(thumbPath);
	}
	return wrote ? thumbPath : nil;
}

static NSDictionary *DYVideoMetaForPath(NSString *videoPath) {
	NSMutableDictionary *meta = [NSMutableDictionary dictionary];

	unsigned long long fileSize = 0;
	NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:videoPath error:nil];
	if ([attrs isKindOfClass:[NSDictionary class]] && [attrs[NSFileSize] isKindOfClass:[NSNumber class]]) {
		fileSize = [(NSNumber *)attrs[NSFileSize] unsignedLongLongValue];
	}
	meta[@"size"] = @(fileSize);

	Float64 seconds = 0;
	unsigned int width = 0;
	unsigned int height = 0;
	AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:videoPath] options:nil];
	seconds = CMTimeGetSeconds(asset.duration);
	if (!isfinite(seconds) || seconds <= 0) {
		seconds = 1;
	}
	NSArray<AVAssetTrack *> *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
	if (tracks.count > 0) {
		AVAssetTrack *track = tracks.firstObject;
		CGSize transformed = CGSizeApplyAffineTransform(track.naturalSize, track.preferredTransform);
		width = (unsigned int)llround(fabs(transformed.width));
		height = (unsigned int)llround(fabs(transformed.height));
	}

	meta[@"duration"] = @((unsigned int)MAX(1, (int)llround(seconds)));
	meta[@"width"] = @(width);
	meta[@"height"] = @(height);
	return meta;
}

static id DYBuildCaptureVideoInfo(NSString *videoPath, NSString *thumbPath, NSString *chatUserName) {
	Class captureClass = objc_getClass("CaptureVideoInfo");
	if (!captureClass) {
		return nil;
	}

	id info = [[captureClass alloc] init];
	if (!info) {
		return nil;
	}

	NSDictionary *meta = DYVideoMetaForPath(videoPath);
	unsigned int videoSize = [meta[@"size"] respondsToSelector:@selector(unsignedIntValue)] ? [meta[@"size"] unsignedIntValue] : 0;
	unsigned int duration = [meta[@"duration"] respondsToSelector:@selector(unsignedIntValue)] ? [meta[@"duration"] unsignedIntValue] : 1;
	unsigned int width = [meta[@"width"] respondsToSelector:@selector(unsignedIntValue)] ? [meta[@"width"] unsignedIntValue] : 0;
	unsigned int height = [meta[@"height"] respondsToSelector:@selector(unsignedIntValue)] ? [meta[@"height"] unsignedIntValue] : 0;

	unsigned int thumbSize = 0;
	NSDictionary *thumbAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:thumbPath error:nil];
	if ([thumbAttrs isKindOfClass:[NSDictionary class]] && [thumbAttrs[NSFileSize] isKindOfClass:[NSNumber class]]) {
		thumbSize = [(NSNumber *)thumbAttrs[NSFileSize] unsignedIntValue];
	}

	unsigned int now = (unsigned int)[[NSDate date] timeIntervalSince1970];

	if ([info respondsToSelector:@selector(setVideo_path:)]) { [info setVideo_path:videoPath]; }
	if ([info respondsToSelector:@selector(setThumb_path:)]) { [info setThumb_path:thumbPath]; }
	if ([info respondsToSelector:@selector(setVideo_size:)]) { [info setVideo_size:videoSize]; }
	if ([info respondsToSelector:@selector(setVideo_time:)]) { [info setVideo_time:duration]; }
	if ([info respondsToSelector:@selector(setVideo_width:)]) { [info setVideo_width:width]; }
	if ([info respondsToSelector:@selector(setVideo_height:)]) { [info setVideo_height:height]; }
	if ([info respondsToSelector:@selector(setThumb_size:)]) { [info setThumb_size:thumbSize]; }
	if ([info respondsToSelector:@selector(setM_videoCreateTime:)]) { [info setM_videoCreateTime:now]; }
	if ([info respondsToSelector:@selector(setM_uiIsSenderStatus:)]) { [info setM_uiIsSenderStatus:1]; }
	if ([info respondsToSelector:@selector(setM_nsSpecifiedChatName:)]) { [info setM_nsSpecifiedChatName:chatUserName]; }

	return info;
}

static BOOL DYSendVideoToSession(NSString *videoPath, NSString *thumbPath, NSString *chatUserName, id chatVC) {
	if (![NSThread isMainThread]) {
		__block BOOL sent = NO;
		dispatch_sync(dispatch_get_main_queue(), ^{
			sent = DYSendVideoToSession(videoPath, thumbPath, chatUserName, chatVC);
		});
		return sent;
	}

	NSString *video = DYTrim(videoPath);
	NSString *thumb = DYTrim(thumbPath);
	NSString *chat = DYTrim(chatUserName);
	if (video.length == 0 || thumb.length == 0 || chat.length == 0) {
		return NO;
	}

	NSFileManager *fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:video] || ![fm fileExistsAtPath:thumb]) {
		return NO;
	}

	NSString *selfUser = DYCurrentSelfUserName();
	if (selfUser.length == 0) {
		return NO;
	}

	id videoInfo = DYBuildCaptureVideoInfo(video, thumb, chat);
	if (!videoInfo) {
		return NO;
	}

	id logic = nil;
	if (chatVC && [chatVC respondsToSelector:@selector(m_logicController)]) {
		logic = [chatVC m_logicController];
	}
	if (logic && [logic respondsToSelector:@selector(AddVideoMsg:ToUsr:VideoInfo:)]) {
		[(BaseMsgContentLogicController *)logic AddVideoMsg:selfUser ToUsr:chat VideoInfo:videoInfo];
		return YES;
	}

	id msgMgr = DYGetService(objc_getClass("CMessageMgr"));
	if (!msgMgr) {
		return NO;
	}

	id sendMgr = DYGetService(objc_getClass("SendMessageMgr"));
	unsigned long long queueBefore = 0;
	BOOL queueAvailable = NO;
	if (sendMgr && [sendMgr respondsToSelector:@selector(GetCountOfSendMessage)]) {
		queueBefore = [sendMgr GetCountOfSendMessage];
		queueAvailable = YES;
	}

	Class wrapClass = objc_getClass("CMessageWrap");

	SEL selectors[] = {
		@selector(AddVideoMsg:ToUsr:VideoInfo:MsgType:),
		@selector(AddVideoMsg:ToUsr:VideoInfo:)
	};
	unsigned int msgType = 43;

	for (int i = 0; i < 2; i++) {
		SEL sel = selectors[i];
		if (![msgMgr respondsToSelector:sel]) {
			continue;
		}
		id result = nil;
		CMessageMgr *mgr = (CMessageMgr *)msgMgr;
		if (sel == @selector(AddVideoMsg:ToUsr:VideoInfo:MsgType:)) {
			result = [mgr AddVideoMsg:selfUser ToUsr:chat VideoInfo:videoInfo MsgType:msgType];
		} else {
			result = [mgr AddVideoMsg:selfUser ToUsr:chat VideoInfo:videoInfo];
		}

		unsigned long long queueAfter = queueBefore;
		if (queueAvailable && sendMgr && [sendMgr respondsToSelector:@selector(GetCountOfSendMessage)]) {
			queueAfter = [sendMgr GetCountOfSendMessage];
		}
		BOOL queueIncreased = (queueAvailable && queueAfter > queueBefore);

		BOOL ok = NO;
		if (wrapClass && [result isKindOfClass:wrapClass]) {
			CMessageWrap *wrap = (CMessageWrap *)result;
			if (wrap.m_uiMesLocalID > 0 || wrap.m_n64MesSvrID > 0 || queueIncreased) {
				ok = YES;
			}
		} else if (result || queueIncreased) {
			ok = YES;
		}

		if (ok) {
			return YES;
		}
	}

	return NO;
}

typedef void (^DYParseCompletion)(NSArray<NSString *> * _Nullable videoURLs, NSString * _Nullable errorMessage);
typedef void (^DYDownloadCompletion)(NSString * _Nullable videoPath,
									 NSString * _Nullable thumbPath,
									 NSString * _Nullable workDir,
									 NSString * _Nullable errorMessage);

static void DYRequestVideoURL(NSString *douyinLink,
							  NSString *chatUserName,
							  unsigned long long token,
							  DYParseCompletion completion) {
	NSString *link = DYTrim(douyinLink);
	if (link.length == 0) {
		if (completion) { completion(nil, @"抖音链接为空"); }
		return;
	}

	NSURLComponents *components = [NSURLComponents componentsWithString:kDouyinParserAPIURL];
	components.queryItems = @[
		[NSURLQueryItem queryItemWithName:@"url" value:link],
		[NSURLQueryItem queryItemWithName:@"minimal" value:@"false"]
	];
	NSURL *requestURL = components.URL;
	if (!requestURL) {
		if (completion) { completion(nil, @"API 地址无效"); }
		return;
	}

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
	request.HTTPMethod = @"GET";
	request.timeoutInterval = 15.0;

	__block NSURLSessionDataTask *task = nil;
	task = [[NSURLSession sharedSession] dataTaskWithRequest:request
										   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		DYUnregisterTask(chatUserName, token, task);
		if (!DYIsSessionActive(chatUserName, token)) {
			return;
		}
		if (error) {
			if (completion) { completion(nil, [NSString stringWithFormat:@"请求失败: %@", error.localizedDescription ?: @"未知错误"]); }
			return;
		}
		if (![data isKindOfClass:[NSData class]] || data.length == 0) {
			if (completion) { completion(nil, @"API 返回为空"); }
			return;
		}

		NSError *jsonError = nil;
		id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
		if (jsonError || !jsonObject) {
			if (completion) { completion(nil, @"响应解析失败"); }
			return;
		}

		NSArray<NSString *> *videoURLs = DYExtractVideoURLsFromJSON(jsonObject);
		if (videoURLs.count > 0) {
			if (completion) { completion(videoURLs, nil); }
			return;
		}

		NSString *errorMessage = DYErrorMessageFromJSON(jsonObject);
		if (errorMessage.length == 0) {
			errorMessage = @"未解析到视频链接";
		}
		if (completion) { completion(nil, errorMessage); }
	}];

	DYRegisterTask(chatUserName, token, task);
	[task resume];
}

static void DYDownloadVideo(NSArray<NSString *> *candidates,
							NSUInteger index,
							NSString *lastError,
							NSString *chatUserName,
							unsigned long long token,
							DYDownloadCompletion completion) {
	if (!DYIsSessionActive(chatUserName, token)) {
		return;
	}
	if (index >= candidates.count) {
		if (completion) { completion(nil, nil, nil, lastError.length > 0 ? lastError : @"视频下载失败"); }
		return;
	}

	NSString *urlText = DYTrim(candidates[index]);
	NSURL *url = [NSURL URLWithString:urlText];
	if (!url || !url.scheme.length) {
		DYDownloadVideo(candidates, index + 1, @"视频下载地址无效", chatUserName, token, completion);
		return;
	}

	__block NSURLSessionDownloadTask *task = nil;
	task = [[NSURLSession sharedSession] downloadTaskWithURL:url
										   completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
		DYUnregisterTask(chatUserName, token, task);
		if (!DYIsSessionActive(chatUserName, token)) {
			return;
		}
		if (error) {
			NSString *message = [NSString stringWithFormat:@"视频下载失败: %@", error.localizedDescription ?: @"未知错误"];
			DYDownloadVideo(candidates, index + 1, message, chatUserName, token, completion);
			return;
		}

		NSInteger statusCode = 0;
		if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
			statusCode = ((NSHTTPURLResponse *)response).statusCode;
			if (statusCode < 200 || statusCode >= 300) {
				NSString *message = [NSString stringWithFormat:@"视频下载失败: HTTP %ld", (long)statusCode];
				DYDownloadVideo(candidates, index + 1, message, chatUserName, token, completion);
				return;
			}
		}

		if (!location) {
			DYDownloadVideo(candidates, index + 1, @"视频下载失败: 无临时文件", chatUserName, token, completion);
			return;
		}

		NSString *workDir = DYCreateWorkingDirectory();
		if (workDir.length == 0) {
			if (completion) { completion(nil, nil, nil, @"创建临时目录失败"); }
			return;
		}

		NSString *extension = DYTrim(response.suggestedFilename.pathExtension);
		if (extension.length == 0) {
			extension = DYTrim(url.pathExtension);
		}
		if (extension.length == 0) {
			extension = @"mp4";
		}

		NSString *uuid = [[NSUUID UUID] UUIDString] ?: [NSString stringWithFormat:@"%u", arc4random()];
		NSString *fileName = [NSString stringWithFormat:@"douyin_%@.%@", uuid, extension];
		NSString *videoPath = [workDir stringByAppendingPathComponent:fileName];
		NSFileManager *fm = [NSFileManager defaultManager];
		[fm removeItemAtPath:videoPath error:nil];
		NSError *moveError = nil;
		[fm moveItemAtURL:location toURL:[NSURL fileURLWithPath:videoPath] error:&moveError];
		if (moveError || ![fm fileExistsAtPath:videoPath]) {
			if (completion) { completion(nil, nil, workDir, @"移动下载视频失败"); }
			return;
		}

		NSString *thumbPath = DYGenerateThumbForVideo(videoPath, workDir);
		if (thumbPath.length == 0) {
			if (completion) { completion(nil, nil, workDir, @"生成视频封面失败"); }
			return;
		}

		if (completion) { completion(videoPath, thumbPath, workDir, nil); }
	}];

	DYRegisterTask(chatUserName, token, task);
	[task resume];
}

static void DYProcessLink(NSString *douyinLink, NSString *chatUserName, id chatVC) {
	NSString *link = DYTrim(douyinLink);
	NSString *chat = DYTrim(chatUserName);
	if (link.length == 0 || chat.length == 0) {
		return;
	}

	unsigned long long token = DYBeginSession(chat);
	DYShowToast(@"正在解析抖音链接...", NO);

	DYRequestVideoURL(link, chat, token, ^(NSArray<NSString *> *videoURLs, NSString *errorMessage) {
		if (!DYIsSessionActive(chat, token)) {
			return;
		}
		if (videoURLs.count == 0) {
			NSString *errorText = errorMessage.length > 0 ? errorMessage : @"抖音解析失败";
			DYShowToast(errorText, YES);
			DYFinishSession(chat, token);
			return;
		}

		DYShowToast(@"正在下载视频...", NO);
		DYDownloadVideo(videoURLs, 0, nil, chat, token, ^(NSString *videoPath, NSString *thumbPath, NSString *workDir, NSString *downloadError) {
			if (!DYIsSessionActive(chat, token)) {
				DYCleanupPathsAfterDelay(@[videoPath ?: @"", thumbPath ?: @"", workDir ?: @""], 0);
				return;
			}
			if (videoPath.length == 0 || thumbPath.length == 0) {
				DYShowToast(downloadError.length > 0 ? downloadError : @"视频下载失败", YES);
				DYCleanupPathsAfterDelay(@[workDir ?: @""], 0);
				DYFinishSession(chat, token);
				return;
			}

			DYShowToast(@"正在发送视频...", NO);
			BOOL sent = DYSendVideoToSession(videoPath, thumbPath, chat, chatVC);
			if (sent) {
				DYShowToast(@"视频发送成功", NO);
				DYCleanupPathsAfterDelay(@[videoPath, thumbPath, workDir ?: @""], 180.0);
			} else {
				DYShowToast(@"视频发送失败", YES);
				DYCleanupPathsAfterDelay(@[videoPath, thumbPath, workDir ?: @""], 0);
			}
			DYFinishSession(chat, token);
		});
	});
}

static BOOL DYShouldShowActionForCell(id cell) {
	if (!DYIsEnabled()) {
		return NO;
	}
	CMessageWrap *msgWrap = DYMessageWrapFromCell(cell);
	if (!msgWrap) {
		return NO;
	}
	NSString *content = DYTrim(msgWrap.m_nsContent);
	if (content.length == 0) {
		return NO;
	}
	return (DYExtractDouyinLink(content).length > 0);
}

static NSArray *DYInjectMenuItemIfNeeded(id cell, NSArray *items) {
	if (!DYIsEnabled() || !DYShouldShowActionForCell(cell)) {
		return items;
	}

	Class menuItemClass = objc_getClass("MMMenuItem");
	if (!menuItemClass) {
		return items;
	}

	SEL action = @selector(wcpl_handleDouyinParseMenuItem:);
	NSMutableArray *mutableItems = [items isKindOfClass:[NSArray class]] ? [items mutableCopy] : [NSMutableArray array];

	for (id item in mutableItems) {
		if ([item isKindOfClass:menuItemClass] && [item respondsToSelector:@selector(action)]) {
			if ([item action] == action) {
				return [mutableItems copy];
			}
		}
	}

	UIImage *icon = nil;
	if (@available(iOS 13.0, *)) {
		icon = [UIImage systemImageNamed:@"arrow.down.circle"];
	}

	id menuItem = nil;
	if (icon && [menuItemClass instancesRespondToSelector:@selector(initWithTitle:icon:target:action:)]) {
		menuItem = [[menuItemClass alloc] initWithTitle:kDouyinParserMenuTitle icon:icon target:cell action:action];
	} else if ([menuItemClass instancesRespondToSelector:@selector(initWithTitle:target:action:)]) {
		menuItem = [[menuItemClass alloc] initWithTitle:kDouyinParserMenuTitle target:cell action:action];
	}

	if (menuItem) {
		[mutableItems addObject:menuItem];
	}
	return [mutableItems copy];
}

static void DYHandleParseAction(id cell) {
	if (!DYIsEnabled()) {
		DYShowToast(@"抖音解析功能已关闭", YES);
		return;
	}

	CMessageWrap *msgWrap = DYMessageWrapFromCell(cell);
	if (!msgWrap) {
		DYShowToast(@"未找到消息", YES);
		return;
	}

	NSString *content = DYTrim(msgWrap.m_nsContent);
	NSString *douyinLink = DYExtractDouyinLink(content);
	if (douyinLink.length == 0) {
		DYShowToast(@"未找到可解析的抖音链接", YES);
		return;
	}

	NSString *chatUserName = DYChatUserNameFromCell(cell, msgWrap);
	if (chatUserName.length == 0) {
		DYShowToast(@"无法识别当前会话", YES);
		return;
	}

	id chatVC = nil;
	if ([cell respondsToSelector:@selector(getViewController)]) {
		chatVC = [cell getViewController];
	}

	DYProcessLink(douyinLink, chatUserName, chatVC);
}

%group DYMenuGroup
%hook TextMessageCellView

- (id)operationMenuItems {
	NSArray *items = %orig;
	return DYInjectMenuItemIfNeeded(self, items);
}

- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2 {
	if (arg1 == @selector(wcpl_handleDouyinParseMenuItem:)) {
		return DYShouldShowActionForCell(self);
	}
	return %orig;
}

%new
- (void)wcpl_handleDouyinParseMenuItem:(id)sender {
	(void)sender;
	DYHandleParseAction(self);
}

%end
%end

%ctor {
	@autoreleasepool {
		Class cellClass = objc_getClass("TextMessageCellView");
		if (cellClass && [cellClass instancesRespondToSelector:@selector(operationMenuItems)]) {
			%init(DYMenuGroup);
		}
	}
}