
# SVGImage

## 简介
[SVGImage](https://ohpm.openharmony.cn/#/cn/detail/@flat%2Fsvg_image)一个基于Shape的轻量级svg渲染库, 解析SVG图片并渲染到页面上。支持轻量级静态矢量图标的.svg资源文件。

## 下载安装
```
ohpm install @flat/svg_image
```
或在`oh-package.json5`配置如下：
```
{
  "dependencies": {
    "@flat/svg_image": "latest",
  }
}
```

## 与`@ohos/svg`比较

| 对比   | `@ohos/svg` | `@flat/svg_image`         |
|:-----|:------------|:--------------------------|
| 渲染机制 | 基于Canvas    | 基于Shape / Path            |
| 上手难度 | 中           | 简单                        |
| 适用场景 | 复杂矢量图渲染     | 静态矢量icon图标                |
| 内存占用 | 底           | 静态矢量icon-极低，复杂矢量图-随节点数量增长 |

使用更加简单，对于加载渲染复杂图层叠加的svg资源文件还是推荐使用`@ohos/svg`，
对于仅加载静态矢量icon图标，修改渲染颜色`@flat/svg_image`则是更轻量的选择。

## 效果

![效果](https://github.com/zhuzhuxingtianxia/HarmonyLibs/blob/main/packages/svg_image/screenshot.png?raw=true)

## 使用示例

```c
// 默认展示
SVGImage({source: $rawfile('visitor_icon.svg')}).backgroundColor(Color.Black)

// 设置颜色大小
SVGImage({source: $rawfile('visitor_icon.svg'), bounds: 60, stroke: '#f00000'})

// 颜色值替换
SVGImage({source: $rawfile('visitor_icon.svg'), bounds: 60, colorSwap: {'#FFFFFF': '#00FF00'}})

// 颜色填充设置
SVGImage({source: $rawfile('line.svg'), bounds: 100, fill: '#00583b'})

// 根据ID修改颜色
SVGImage({
  source: $rawfile('svg_clock.svg'), 
  bounds: 80,
  idStyles: {
    "Bg": { fill: '#F97316'}
  },
  colorSwap: {"#FFC50D": "#FF0000", '#333333': '#0000FF'}
})

```

## 接口说明

| 名称          | 描述                                      | 参数                               | 是否必需 |
|:------------|:----------------------------------------|:---------------------------------|:-----|
| source      | svg资源文件或字符串                             | ResourceStr                      | 是    |
| bounds      | 大小，不支持独立设置宽高                            | number类型                         | 否    |
| fill        | 填充颜色值                                   | ResourceColor                    | 否    |
| stroke      | stroke颜色值                               | ResourceColor                    | 否    |
| strokeWidth | stroke宽                                 | number类型                         | 否    |
| idStyles    | id字段设置样式，覆盖逻辑 (ID > Role > ColorSwap)   | Record<string, SvgStyleOverride> | 否    |
| roleStyles  | role字段设置样式，覆盖逻辑 (ID > Role > ColorSwap) | Record<string, SvgStyleOverride> | 否    |
| colorSwap   | 颜色值映射替换 ，覆盖逻辑 (ID > Role > ColorSwap)   | Record<string, ResourceColor>    | 否    |

## svg测试资源

https://www.svgviewer.dev/

## API限制

* SDK: API12 (5.0.0)

## License
This project is licensed under Apache License 2.0.
