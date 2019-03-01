//
//  NSObject+JSONModel.h
//  XiaoWeiTreasure
//
//  Created by unakayou on 15/10/26.
//  Copyright © 2015年 unakayou. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (JSONModel)

/**
 *  类方法字典生成模型
 */
+ (instancetype)modelFromJSONDictionary:(NSDictionary *)dict;

/**
 *  对象通过字典初始化属性
 */
- (BOOL)reflectDataFromOtherObject:(NSDictionary *)dic;

/**
 *  对象转化成字典
 */
- (NSDictionary *)dictionaryFromObject;

/**
 *  通过另一个模型更新数据
 */
- (instancetype)updateModelWithAnotherModel:(NSObject *)model;

@end
