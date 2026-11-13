# HarmonyLibs
OpenHarmony鸿蒙制品库

## 添加库
新建->模块->选择 Static Library->下一步-> 输入模块模块名称

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
