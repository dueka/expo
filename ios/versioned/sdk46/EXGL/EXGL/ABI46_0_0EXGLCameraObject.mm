// Copyright 2016-present 650 Industries. All rights reserved.

#import <AVKit/AVKit.h>

#include <OpenGLES/ES3/gl.h>
#include <OpenGLES/ES3/glext.h>

#import <ABI46_0_0ExpoModulesCore/ABI46_0_0EXCameraInterface.h>

#import <ABI46_0_0EXGL/ABI46_0_0EXGLCameraObject.h>
#import <ABI46_0_0EXGL/ABI46_0_0EXGLContext.h>

@interface ABI46_0_0EXGLCameraObject () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) id<ABI46_0_0EXCameraInterface> camera;
@property (nonatomic, strong) EAGLContext *eaglCtx;
@property (nonatomic, strong) AVCaptureVideoDataOutput *cameraOutput;
@property (nonatomic, assign) CVOpenGLESTextureCacheRef cameraTextureCache;

@end

@implementation ABI46_0_0EXGLCameraObject

- (instancetype)initWithContext:(ABI46_0_0EXGLContext *)glContext andCamera:(id<ABI46_0_0EXCameraInterface>)camera
{
  EXGLContextId exglCtxId = [glContext contextId];

  if (self = [super initWithConfig:@{ @"exglCtxId": @(exglCtxId) }]) {
    _eaglCtx = [glContext createSharedEAGLContext];
    _camera = camera;

    dispatch_async(camera.sessionQueue, ^{
      AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];

      if ([camera.session canAddOutput:videoOutput]) {
        videoOutput.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA) };
        [videoOutput setSampleBufferDelegate:self queue:camera.sessionQueue];
        [videoOutput setAlwaysDiscardsLateVideoFrames:YES];
        [camera.session addOutput:videoOutput];
        self->_cameraOutput = videoOutput;
      }
    });
  }
  return self;
}

- (void)dealloc
{
  if (_cameraOutput) {
    [_camera.session removeOutput:_cameraOutput];
    [_cameraOutput setSampleBufferDelegate:nil queue:nil];
  }
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
  [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
  [connection setVideoMirrored:YES];

  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  GLsizei bufferWidth = (GLsizei)CVPixelBufferGetWidth(pixelBuffer);
  GLsizei bufferHeight = (GLsizei)CVPixelBufferGetHeight(pixelBuffer);
  
  CVPixelBufferRetain(pixelBuffer);
  CVPixelBufferLockBaseAddress(pixelBuffer, 0);

  [EAGLContext setCurrentContext:_eaglCtx];

  if (!_cameraTextureCache) {
    CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _eaglCtx, NULL, &_cameraTextureCache);
  }
  
  CVOpenGLESTextureRef textureRef = NULL;
  
  CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                               _cameraTextureCache,
                                               pixelBuffer,
                                               NULL,
                                               GL_TEXTURE_2D,
                                               GL_RGBA,
                                               bufferWidth,
                                               bufferHeight,
                                               GL_BGRA,
                                               GL_UNSIGNED_BYTE,
                                               0,
                                               &textureRef);
  
  if (textureRef) {
    GLuint textureName = CVOpenGLESTextureGetName(textureRef);
    EXGLContextMapObject([self exglCtxId], [self exglObjId], textureName);
  }

  CVOpenGLESTextureCacheFlush(_cameraTextureCache, 0);
  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
  CVPixelBufferRelease(pixelBuffer);
  CFRelease(textureRef);

  [EAGLContext setCurrentContext:nil];
}

@end
