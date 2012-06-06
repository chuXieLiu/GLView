//
//  GLImageMap.m
//
//  GLView Project
//  Version 1.3.1
//
//  Created by Nick Lockwood on 04/06/2012.
//  Copyright 2011 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from either of these locations:
//
//  http://charcoaldesign.co.uk/source/cocoa#glview
//  https://github.com/nicklockwood/GLView
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "GLImageMap.h"


@interface GLImage (Private)

@property (nonatomic, getter = isRotated) BOOL rotated;

@end


@interface GLImageMap ()

@property (nonatomic, strong) NSMutableDictionary *imagesByName;

- (void)addImage:(GLImage *)image withName:(NSString *)name;
- (GLImageMap *)initWithImage:(GLImage *)image path:(NSString *)path data:(NSData *)data;

@end


@implementation GLImageMap

@synthesize imagesByName = _imagesByName;

+ (GLImageMap *)imageMapWithContentsOfFile:(NSString *)nameOrPath
{
    return AH_AUTORELEASE([[self alloc] initWithContentsOfFile:nameOrPath]);
}

+ (GLImageMap *)imageMapWithImage:(GLImage *)image data:(NSData *)data
{
    return AH_AUTORELEASE([[self alloc] initWithImage:image data:data]);
}

- (GLImageMap *)init
{
    if ((self = [super init]))
    {
        _imagesByName = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (GLImageMap *)initWithContentsOfFile:(NSString *)nameOrPath
{
    //load image map
    NSString *dataPath = [nameOrPath absolutePathWithDefaultExtensions:@"plist", nil];
    return [self initWithImage:nil path:nameOrPath data:[NSData dataWithContentsOfFile:dataPath]];
}

- (GLImageMap *)initWithImage:(GLImage *)image path:(NSString *)path data:(NSData *)data
{
    //parse data
    NSPropertyListFormat format = 0;
    NSDictionary *dict = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:&format error:NULL];
    if (dict && [dict isKindOfClass:[NSDictionary class]])
    {
        if (!image)
        {
            //generate default image path
            path = [path stringByDeletingPathExtension];
            
            //get metadata
            NSDictionary *metadata = [dict objectForKey:@"metadata"];
            if (metadata)
            {
                //get image path from metadata
                NSString *imageFile = [metadata valueForKeyPath:@"target.textureFileName"];
                NSString *extension = [metadata valueForKeyPath:@"target.textureFileExtension"];
                if ([extension hasPrefix:@"."]) extension = [extension substringFromIndex:1];
                path = [[[path ?: @"" stringByDeletingLastPathComponent] stringByAppendingPathComponent:imageFile] stringByAppendingPathExtension:extension];
                image = [GLImage imageWithContentsOfFile:path];
                
                //set premultiplied property
                BOOL premultiplied = [[metadata valueForKeyPath:@"target.premultipliedAlpha"] boolValue];
                image = [image imageWithPremultipliedAlpha:premultiplied];
            }
            else
            {
                image = [GLImage imageWithContentsOfFile:path];
            }
        }
        
        if (image)
        {
            //get frames
            NSDictionary *frames = [dict objectForKey:@"frames"];
            if (frames)
            {
                if ((self = [self init]))
                {
                    for (NSString *name in frames)
                    {
                        NSDictionary *spriteDict = [frames objectForKey:name];
                        
                        //get clip rect
                        CGRect clipRect = CGRectFromString([spriteDict objectForKey:@"textureRect"]);
                        clipRect.origin.x *= image.scale;
                        clipRect.origin.y *= image.scale;
                        clipRect.size.width *= image.scale;
                        clipRect.size.height *= image.scale;
                        
                        //get image size
                        CGSize size = CGSizeFromString([spriteDict objectForKey:@"spriteSize"]);
                        
                        //get content rect
                        CGRect contentRect = CGRectMake(0.0f, 0.0f, size.width, size.height);
                        BOOL spriteTrimmed = [[spriteDict objectForKey:@"spriteTrimmed"] boolValue];
                        if (spriteTrimmed)
                        {
                            contentRect = CGRectFromString([spriteDict objectForKey:@"spriteColorRect"]);
                            size = CGSizeFromString([spriteDict objectForKey:@"spriteSourceSize"]);
                        }
                        
                        //get rotation
                        BOOL rotated = [[spriteDict objectForKey:@"textureRotated"] boolValue];
                        
                        //add subimage
                        GLImage *subimage = [[[image imageWithClipRect:clipRect] imageWithSize:size] imageWithContentRect:contentRect];
                        subimage.rotated = rotated; //TODO: replace with more robust orientation mechanism
                        [self addImage:subimage withName:name];
                        
                        //aliases
                        for (NSString *alias in [spriteDict objectForKey:@"aliases"])
                        {
                            [self addImage:subimage withName:alias];
                        }
                    }
                }
                return self;
            }
            else
            {
                NSLog(@"ImageMap data contains no image frames");
            }
        }
        else
        {
            NSLog(@"Could not locate ImageMap texture file");
        }
    }
    else
    {
        NSLog(@"Unrecognised ImageMap data format");
    }
              
    //not a recognised data format
    AH_RELEASE(self);
    return nil;
}

- (GLImageMap *)initWithImage:(GLImage *)image data:(NSData *)data
{
    return [self initWithImage:image path:nil data:data];
}

- (void)addImage:(GLImage *)image withName:(NSString *)name
{
    [self.imagesByName setObject:image forKey:name];
}

- (void)dealloc
{
    AH_RELEASE(_imagesByName);
    AH_SUPER_DEALLOC;
}

- (NSInteger)imageCount
{
    return [self.imagesByName count];
}

- (NSString *)imageNameAtIndex:(NSInteger)index
{
    return [[self.imagesByName allKeys] objectAtIndex:index];
}

- (GLImage *)imageAtIndex:(NSInteger)index
{
    return [self imageNamed:[self imageNameAtIndex:index]];
}

- (GLImage *)imageNamed:(NSString *)name
{
    GLImage *image = [self.imagesByName objectForKey:name];
    if (!image)
    {
        return [self.imagesByName objectForKey:[name stringByAppendingPathExtension:@"png"]];
    }
    return image;
}

@end
