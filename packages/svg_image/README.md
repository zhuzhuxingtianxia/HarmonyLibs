
# SVGImage

## 简介
SVGImage一个基于Shape的轻量级svg渲染库, 解析SVG图片并渲染到页面上。支持标准的.svg资源文件。

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

使用更加简单，对于加载渲染复杂的svg资源文件还是推荐使用`@ohos/svg`，
对于仅加载显示icon图标，修改渲染颜色`@flat/svg_image`则是更轻量的选择。

## svg测试资源

https://www.svgviewer.dev/