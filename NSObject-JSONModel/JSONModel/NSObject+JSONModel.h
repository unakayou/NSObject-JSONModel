//
//  NSObject+JSONModel.h
//
//
//  Created by unakayou on 15/10/26.
//  Copyright © 2015年 unakayou. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (JSONModel)

/**
 *  字典生成模型
 */
+ (instancetype)modelFromJSONDictionary:(NSDictionary *)dict;

/**
 *  模型转化字典
 */
- (NSDictionary *)dictionaryFromObject;

/**
 *  通过另一个模型更新数据
 */
- (instancetype)updateModelWithAnotherModel:(NSObject *)model;

@end
