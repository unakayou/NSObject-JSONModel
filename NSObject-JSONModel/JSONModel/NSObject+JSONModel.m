//
//  NSObject+JSONModel.m
//  XiaoWeiTreasure
//
//  Created by unakayou on 15/10/26.
//  Copyright © 2015年 unakayou. All rights reserved.
//

#import "NSObject+JSONModel.h"
#import <objc/runtime.h>

@implementation NSObject (JSONModel)

/**
 *  往模型里追加属性
 */
+ (void)model:(id)model appendProperties:(objc_property_t *)properties count:(unsigned int)outCount infoDict:(NSDictionary *)dict
{
    for (int i = 0; i < outCount; i++)
    {
        objc_property_t property = properties[i];
        //属性名称
        NSString *propertyName = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        //属性类型
        NSString *propertyType = [[NSString alloc] initWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];
        
        if ([[dict allKeys] containsObject:propertyName])
        {
            id value = [dict valueForKey:propertyName];
            if (![value isKindOfClass:[NSNull class]] && value != nil)
            {
                if ([value isKindOfClass:[NSDictionary class]])
                {
                    Class aClass = [[NSBundle mainBundle] classNamed:[self getClassName:propertyType]];
                    if (aClass)
                    {
                        id pro = [aClass modelFromJSONDictionary:value];
                        [model setValue:pro forKey:propertyName];
                    }
                    else
                    {
                        [model setValue:value forKey:propertyName];
                    }
                }
                else if ([value isKindOfClass:[NSArray class]])
                {
                    //如果是个数组 则遍历这个数组 碰到里面是字典的转化为对象 其他的不做操作
                    NSMutableArray * mutableArray = [value mutableCopy];
                    [mutableArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        if ([obj isKindOfClass:[NSDictionary class]])
                        {
                            Class propertyClass = NSClassFromString([self getProtocol:propertyType]);   //给属性加个协议 可以取到协议名
                            if (propertyClass)
                            {
                                [mutableArray replaceObjectAtIndex:idx withObject:[propertyClass modelFromJSONDictionary:obj]];
                            }
                        }
                    }];
                    [model setValue:mutableArray forKey:propertyName];
                }
                else    //乱七八糟圈往里塞就完了
                {
                    [model setValue:value forKey:propertyName];
                }
            }
        }
    }
}

+ (instancetype)modelFromJSONDictionary:(NSDictionary *)dict
{
    id model = [self new];

    NSString * selfClassStr = NSStringFromClass([self class]);
    Class selfClass = NSClassFromString(selfClassStr);
    if (selfClass != [NSObject class])
    {
        Class superClass = [selfClass superclass];
        if (superClass != [NSObject class])
        {
            unsigned int superOutCount;
            objc_property_t *superProperties = class_copyPropertyList(superClass, &superOutCount);
            [self model:model appendProperties:superProperties count:superOutCount infoDict:dict];
            free(superProperties);
        }
    }

    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    [self model:model appendProperties:properties count:outCount infoDict:dict];
    free(properties);
    return model;
}

- (NSDictionary *)dictionaryFromObject
{
    NSMutableDictionary * retDict = [[NSMutableDictionary alloc] initWithCapacity:0];
    
    //获取property数量
    unsigned int outCount;
    objc_property_t * properties = class_copyPropertyList([self class], &outCount);
    
    for (int i = 0; i < outCount; i++)
    {
        objc_property_t property = properties[i];
        NSString * propertyName = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        NSString * propertyType = [[NSString alloc] initWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];
        
        SEL function = NSSelectorFromString(propertyName);
        
        if ([self respondsToSelector:function])
        {
            IMP imp = [self methodForSelector:function];
            id (*func)(id, SEL) = (void *)imp;
            id value = func(self, function);
            
            if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]])
            {
                [retDict setObject:value forKey:propertyName];

            }
            else if ([value isKindOfClass:[NSArray class]])
            {
                //如果objc里面有另外一个dict,需要另外判断
                NSMutableArray * mutableArray = [value mutableCopy];
                [mutableArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    Class propertyClass = NSClassFromString([self getProtocol:propertyType]);
                    if (propertyClass)
                    {
                        [mutableArray replaceObjectAtIndex:idx withObject:[obj dictionaryFromObject]];
                    }
                }];
                [retDict setObject:mutableArray forKey:propertyName];
            }
            else
            {
                if (NSClassFromString([self getClassName:propertyType]))
                {
                    [retDict setObject:[value dictionaryFromObject] forKey:propertyName];
                }
            }
        }
    }
    return retDict;
}

- (BOOL)reflectDataFromOtherObject:(NSDictionary *)dic
{
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    
    for (i = 0; i < outCount; i++)
    {
        objc_property_t property = properties[i];
        NSString *propertyName = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        NSString *propertyType = [[NSString alloc] initWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];
        
        if ([[dic allKeys] containsObject:propertyName])
        {
            id value = [dic valueForKey:propertyName];
            if (![value isKindOfClass:[NSNull class]] && value != nil)
            {
                if ([value isKindOfClass:[NSDictionary class]])
                {
                    id pro = [self createInstanceByClassName:[self getClassName:propertyType]];
                    [pro reflectDataFromOtherObject:value];
                    [self setValue:pro forKey:propertyName];
                }
                else
                {
                    [self setValue:value forKey:propertyName];
                }
            }
        }
    }
    
    free(properties);
    return YES;
}

- (NSString *)getClassName:(NSString *)attributes
{
    NSInteger index = [attributes rangeOfString:@"\""].location + 1;
    if (index <= attributes.length)
    {
        NSString *type = [attributes substringFromIndex:index];
        type = [type substringToIndex:[type rangeOfString:@"\""].location];
        return type;
    }
    return attributes;
}

- (NSString *)getProtocol:(NSString *)attributes
{
    NSInteger index = [attributes rangeOfString:@"<"].location + 1;
    if (index <= attributes.length)
    {
        NSString *type = [attributes substringFromIndex:index];
        type = [type substringToIndex:[type rangeOfString:@">"].location];
        return type;
    }
    return attributes;
}

- (id)createInstanceByClassName: (NSString *)className
{
    Class aClass = [[NSBundle mainBundle] classNamed:className];
    id anInstance = [[aClass alloc] init];
    return anInstance;
}

- (instancetype)updateModelWithAnotherModel:(NSObject *)model
{
    unsigned int outCount, subCount;
    
    objc_property_t * properties = class_copyPropertyList([self class], &outCount);     //本身的属性
    objc_property_t * subProperties = class_copyPropertyList([model class], &subCount); //传进来的属性

    for (int i = 0; i < outCount; i++)
    {
        objc_property_t property = properties[i];
        NSString * propertyName = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        NSString * propertyType = [[NSString alloc] initWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];
        
        for (int j = 0; j < subCount; j++)
        {
            objc_property_t subProperty = subProperties[j];
            NSString * subPropertyName = [[NSString alloc] initWithCString:property_getName(subProperty) encoding:NSUTF8StringEncoding];
            NSString * subPropertyType = [[NSString alloc] initWithCString:property_getAttributes(subProperty) encoding:NSUTF8StringEncoding];
            
            if ([propertyName isEqualToString:subPropertyName] && [propertyType isEqualToString:subPropertyType])
            {
                NSValue * value = [model valueForKey:propertyName];
                if (value != nil)
                {
                    [self setValue:value forKey:propertyName];
                    break;
                }
            }
        }
    }
    free(properties);
    free(subProperties);
    return self;
}

@end
