//
//  NSObject+JSONModel.m
//  
//
//  Created by unakayou on 15/10/26.
//  Copyright © 2015年 unakayou. All rights reserved.
//

#import "NSObject+JSONModel.h"
#import <objc/runtime.h>

@implementation NSObject (JSONModel)

//数据生成模型入口
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
            [self model:model appendProperties:superProperties count:superOutCount jsonDict:dict];
            free(superProperties);
        }
    }

    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    [self model:model appendProperties:properties count:outCount jsonDict:dict];
    free(properties);
    return model;
}

//从数据生成模型
+ (void)model:(id)model appendProperties:(objc_property_t *)properties count:(unsigned int)outCount jsonDict:(NSDictionary *)jsonDict
{
    for (int i = 0; i < outCount; i++)
    {
        objc_property_t property = properties[i];
        NSString * propertyName = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];          //变量名
        NSString * propertyType = [[NSString alloc] initWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];    //变量类型
        
        if ([[jsonDict allKeys] containsObject:propertyName])
        {
            id jsonValue = [jsonDict valueForKey:propertyName];     //取出JSON对应property名字的值
            if (![jsonValue isKindOfClass:[NSNull class]] && jsonValue != nil)
            {
                if ([jsonValue isKindOfClass:[NSDictionary class]]) //如果是字典类型 则寻找对应的类 创建对象添加到模型中
                {
                    Class propertyClass = [[NSBundle mainBundle] classNamed:[self getClassName:propertyType]];
                    if (propertyClass)
                    {
                        id propertyObject = [propertyClass modelFromJSONDictionary:jsonValue];
                        [model setValue:propertyObject forKey:propertyName];
                    }
                    else    //如果没有找到这个类 则直接把字典加进去
                    {
                        [model setValue:jsonValue forKey:propertyName];
                    }
                }
                else if ([jsonValue isKindOfClass:[NSArray class]]) //如果是个数组 则遍历这个数组 碰到里面是字典的转化为对象(对象的类名必须声明为protocol!!!)
                {
                    NSMutableArray * mutableArray = [jsonValue mutableCopy];
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
                    [model setValue:jsonValue forKey:propertyName];
                }
            }
        }
    }
}

//模型解析数据入口
- (NSDictionary *)dictionaryFromObject
{
    //父类的属性(只取上一层父类,多层暂不考虑)
    NSString * selfClassStr = NSStringFromClass([self class]);
    Class selfClass = NSClassFromString(selfClassStr);
    NSMutableDictionary * superJSONDict = nil;
    if (selfClass != [NSObject class])
    {
        Class superClass = [selfClass superclass];
        if (superClass != [NSObject class])
        {
            unsigned int superOutCount;
            objc_property_t *superProperties = class_copyPropertyList(superClass, &superOutCount);
            superJSONDict = [[self model:self withProperties:superProperties count:superOutCount] mutableCopy];
            free(superProperties);
        }
    }

    unsigned int outCount;
    objc_property_t * properties = class_copyPropertyList([self class], &outCount);
    NSMutableDictionary * retDict = [[NSMutableDictionary alloc] initWithDictionary:superJSONDict];
    [retDict setDictionary:[self model:self withProperties:properties count:outCount]];
    free(properties);
    return retDict;
}

//从模型解析数据
- (NSDictionary *)model:(id)model withProperties:(objc_property_t *)properties count:(unsigned int)outCount
{
    NSMutableDictionary * retDict = [[NSMutableDictionary alloc] initWithCapacity:0];
    for (int i = 0; i < outCount; i++)
    {
        objc_property_t property = properties[i];
        NSString * propertyName = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        NSString * propertyType = [[NSString alloc] initWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];
        
        SEL function = NSSelectorFromString(propertyName);
        if ([self respondsToSelector:function])
        {
            //取出对象内的属性值
            IMP imp = [self methodForSelector:function];
            id (*func)(id, SEL) = (void *)imp;
            id propertyValue = func(self, function);
            
            if ([propertyValue isKindOfClass:[NSString class]] || [propertyValue isKindOfClass:[NSNumber class]] || [propertyValue isKindOfClass:[NSSet class]])
            {
                [retDict setObject:propertyValue forKey:propertyName];
            }
            else if ([propertyValue isKindOfClass:[NSArray class]]) //如果属性是一个数组 则遍历
            {
                NSMutableArray * mutableArray = [propertyValue mutableCopy];
                [mutableArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    Class propertyClass = NSClassFromString([self getProtocol:propertyType]);
                    if ([obj isKindOfClass:propertyClass])  //如果数组内部的对象和protocol声明的一样。则把对象递归解析,用解析后字典替换原对象。如果是其他类型 则不做操作
                    {
                        [mutableArray replaceObjectAtIndex:idx withObject:[obj dictionaryFromObject]];
                    }
                }];
                [retDict setObject:mutableArray forKey:propertyName];
            }
            else    //如果是其他对象 则解析后放入
            {
                if (NSClassFromString([self getClassName:propertyType]))
                {
                    [retDict setObject:[propertyValue dictionaryFromObject] forKey:propertyName];
                }
            }
        }
    }
    return retDict;
}

- (instancetype)updateModelWithAnotherModel:(NSObject *)model
{
    if (![model isMemberOfClass:[self class]]) return self;

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

- (id)getInstanceByClassName:(NSString *)className
{
    Class aClass = [[NSBundle mainBundle] classNamed:className];
    id anInstance = [[aClass alloc] init];
    return anInstance;
}

@end
