/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "ABI32_0_0RCTAssetsLibraryRequestHandler.h"

#import <stdatomic.h>
#import <dlfcn.h>
#import <objc/runtime.h>

#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import <ReactABI32_0_0/ABI32_0_0RCTBridge.h>
#import <ReactABI32_0_0/ABI32_0_0RCTUtils.h>

@implementation ABI32_0_0RCTAssetsLibraryRequestHandler
{
  ALAssetsLibrary *_assetsLibrary;
}

ABI32_0_0RCT_EXPORT_MODULE()

@synthesize bridge = _bridge;
static Class _ALAssetsLibrary = nil;
static void ensureAssetsLibLoaded(void)
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    void * handle = dlopen("/System/Library/Frameworks/AssetsLibrary.framework/AssetsLibrary", RTLD_LAZY);
#pragma unused(handle)
    _ALAssetsLibrary = objc_getClass("ALAssetsLibrary");
  });
}
- (ALAssetsLibrary *)assetsLibrary
{
  ensureAssetsLibLoaded();
  return _assetsLibrary ?: (_assetsLibrary = [_ALAssetsLibrary new]);
}

#pragma mark - ABI32_0_0RCTURLRequestHandler

- (BOOL)canHandleRequest:(NSURLRequest *)request
{
  return [request.URL.scheme caseInsensitiveCompare:@"assets-library"] == NSOrderedSame;
}

- (id)sendRequest:(NSURLRequest *)request
     withDelegate:(id<ABI32_0_0RCTURLRequestDelegate>)delegate
{
  __block atomic_bool cancelled = ATOMIC_VAR_INIT(NO);
  void (^cancellationBlock)(void) = ^{
    atomic_store(&cancelled, YES);
  };

  [[self assetsLibrary] assetForURL:request.URL resultBlock:^(ALAsset *asset) {
    if (atomic_load(&cancelled)) {
      return;
    }

    if (asset) {

      ALAssetRepresentation *representation = [asset defaultRepresentation];
      NSInteger length = (NSInteger)representation.size;
      CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef _Nonnull)(representation.UTI), kUTTagClassMIMEType);

      NSURLResponse *response =
      [[NSURLResponse alloc] initWithURL:request.URL
                                MIMEType:(__bridge NSString *)(MIMEType)
                   expectedContentLength:length
                        textEncodingName:nil];

      [delegate URLRequest:cancellationBlock didReceiveResponse:response];

      NSError *error = nil;
      uint8_t *buffer = (uint8_t *)malloc((size_t)length);
      if ([representation getBytes:buffer
                        fromOffset:0
                            length:length
                             error:&error]) {

        NSData *data = [[NSData alloc] initWithBytesNoCopy:buffer
                                                    length:length
                                              freeWhenDone:YES];

        [delegate URLRequest:cancellationBlock didReceiveData:data];
        [delegate URLRequest:cancellationBlock didCompleteWithError:nil];

      } else {
        free(buffer);
        [delegate URLRequest:cancellationBlock didCompleteWithError:error];
      }

    } else {
      NSString *errorMessage = [NSString stringWithFormat:@"Failed to load asset"
                                " at URL %@ with no error message.", request.URL];
      NSError *error = ABI32_0_0RCTErrorWithMessage(errorMessage);
      [delegate URLRequest:cancellationBlock didCompleteWithError:error];
    }
  } failureBlock:^(NSError *loadError) {
    if (atomic_load(&cancelled)) {
      return;
    }
    [delegate URLRequest:cancellationBlock didCompleteWithError:loadError];
  }];

  return cancellationBlock;
}

- (void)cancelRequest:(id)requestToken
{
  ((void (^)(void))requestToken)();
}

@end

@implementation ABI32_0_0RCTBridge (ABI32_0_0RCTAssetsLibraryImageLoader)

- (ALAssetsLibrary *)assetsLibrary
{
  return [[self moduleForClass:[ABI32_0_0RCTAssetsLibraryRequestHandler class]] assetsLibrary];
}

@end
