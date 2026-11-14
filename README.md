# HarmonyLibs
OpenHarmony鸿蒙制品库

## 添加库
新建->模块->选择 Static Library->下一步-> 输入模块名称

## 配置`oh-package.json5`
```
{
  "name": "模块名称",
  "version": "版本号",
  "description": "模块功能介绍",
  "main": "Index.ets",
  "author": {
    "name": "",
    "email": "",
  },
  "homepage": "https://github.com",
  "repository": "https://github.com",
  "keywords": [
    "关键词会出现在制品库列表下面，也用于关键词搜索",
  ],
  "tags": [
   "tag标签"
  ],
  "license": "Apache-2.0",
  "dependencies": {}
}
```

## 构建产物
构建产物为 字节码 HAR,需在模块的`build-profile.json5`中显式开启 `byteCodeHar`:
```
{
  "apiType": "stageMode",
  "buildOption": {
    "arkOptions": {
      "byteCodeHar": true
    }
  }
}
```
这样构建的产物是 `.har` 字节码HAR文件而非源码HAR文件

## 发布模块

```
ohpm run <脚本名称>
// 例如
ohpm run build_svg
```
