//
//  ASGraphicsContext.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASGraphicsContext.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASConfigurationInternal.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASAvailability.h>


#if AS_AT_LEAST_IOS13
#define ASPerformBlockWithTraitCollection(work, traitCollection) \
    if (@available(iOS 13.0, tvOS 13.0, *)) { \
      UITraitCollection *uiTraitCollection = ASPrimitiveTraitCollectionToUITraitCollection(traitCollection); \
      [uiTraitCollection performAsCurrentTraitCollection:^{ \
        work(); \
      }];\
    } else { \
      work(); \
    }
#else
#define ASPerformBlockWithTraitCollection(work, traitCollection) work();
#endif


NS_AVAILABLE_IOS(10)
NS_INLINE void ASConfigureExtendedRange(UIGraphicsImageRendererFormat *format)
{
  if (AS_AVAILABLE_IOS_TVOS(12, 12)) {
    // nop. We always use automatic range on iOS >= 12.
  } else {
    // Currently we never do wide color. One day we could pipe this information through from the ASImageNode if it was worth it.
    format.prefersExtendedRange = NO;
  }
}

UIImage *ASGraphicsCreateImageWithOptions(CGSize size, BOOL opaque, CGFloat scale, UIImage *sourceImage,
                                          asdisplaynode_iscancelled_block_t NS_NOESCAPE isCancelled,
                                          void (^NS_NOESCAPE work)())
{
  return ASGraphicsCreateImage(ASPrimitiveTraitCollectionMakeDefault(), size, opaque, scale, sourceImage, isCancelled, work);
}

UIImage *ASGraphicsCreateImage(ASPrimitiveTraitCollection traitCollection, CGSize size, BOOL opaque, CGFloat scale, UIImage * sourceImage, asdisplaynode_iscancelled_block_t NS_NOESCAPE isCancelled, void (NS_NOESCAPE ^work)()) {
  if (AS_AVAILABLE_IOS_TVOS(10, 10)) {
    if (ASActivateExperimentalFeature(ASExperimentalDrawingGlobal)) {
      static UIGraphicsImageRendererFormat *defaultFormat;
      static UIGraphicsImageRendererFormat *opaqueFormat;
      static dispatch_once_t onceToken;
      dispatch_once(&onceToken, ^{
        if (AS_AVAILABLE_IOS_TVOS(11, 11)) {
          defaultFormat = [UIGraphicsImageRendererFormat preferredFormat];
          opaqueFormat = [UIGraphicsImageRendererFormat preferredFormat];
        } else {
          defaultFormat = [UIGraphicsImageRendererFormat defaultFormat];
          opaqueFormat = [UIGraphicsImageRendererFormat defaultFormat];
        }
        opaqueFormat.opaque = YES;
        ASConfigureExtendedRange(defaultFormat);
        ASConfigureExtendedRange(opaqueFormat);
      });

      UIGraphicsImageRendererFormat *format;
      if (sourceImage) {
        if (sourceImage.renderingMode == UIImageRenderingModeAlwaysTemplate) {
          if (AS_AVAILABLE_IOS_TVOS(11, 11)) {
            format = [UIGraphicsImageRendererFormat preferredFormat];
          } else {
            format = [UIGraphicsImageRendererFormat defaultFormat];
          }
        } else {
          format = sourceImage.imageRendererFormat;
        }
        format.opaque = opaque;
        format.scale = scale;
      } else if (scale == 0 || scale == ASScreenScale()) {
        format = opaque ? opaqueFormat : defaultFormat;
      } else {
        if (AS_AVAILABLE_IOS_TVOS(11, 11)) {
          format = [UIGraphicsImageRendererFormat preferredFormat];
        } else {
          format = [UIGraphicsImageRendererFormat defaultFormat];
        }
        if (opaque) format.opaque = YES;
        format.scale = scale;
        ASConfigureExtendedRange(format);
      }

      __block UIImage *image;
      NSError *error;
      [[[UIGraphicsImageRenderer alloc] initWithSize:size format:format]
          runDrawingActions:^(UIGraphicsImageRendererContext *rendererContext) {
            ASDisplayNodeCAssert(rendererContext.CGContext, @"Should have a context!");
            ASPerformBlockWithTraitCollection(work, traitCollection);
          }
          completionActions:^(UIGraphicsImageRendererContext *rendererContext) {
            if (!isCancelled || !isCancelled()) {
              image = rendererContext.currentImage;
            }
          }
          error:&error];

      if (error) {
        NSCAssert(NO, @"Error drawing: %@", error);
      }
      return image;
    }
  }

  // Bad OS or experiment flag. Use UIGraphicsImageRenderer instead of UIGraphicsBeginImageContextWithOptions
  UIGraphicsImageRenderer *renderer;  // Khai báo renderer trước

  if (@available(iOS 11.0, *)) {
      UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
      format.opaque = opaque;
      format.scale = (scale == 0) ? [UIScreen mainScreen].scale : scale;

      renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];  // Gán giá trị trong if
  } else {
      // Fallback cho các phiên bản iOS cũ hơn nếu cần
  }

  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
      ASPerformBlockWithTraitCollection(work, traitCollection);
  }];
}


UIImage *ASGraphicsCreateImageWithTraitCollectionAndOptions(ASPrimitiveTraitCollection traitCollection, CGSize size, BOOL opaque, CGFloat scale, UIImage * sourceImage, void (NS_NOESCAPE ^work)()) {
  return ASGraphicsCreateImage(traitCollection, size, opaque, scale, sourceImage, nil, work);
}
